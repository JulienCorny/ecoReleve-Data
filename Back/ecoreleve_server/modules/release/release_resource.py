# from ..Models import (
#     Individual,
#     Station,
#     Observation,
#     # ProtocoleType,
#     invertedThesaurusDict,
#     thesaurusDictTraduction
# )
import json
from datetime import datetime
import pandas as pd
from sqlalchemy import select, text
import operator
from traceback import print_exc
from collections import Counter


from ecoreleve_server.core.base_resource import CustomResource
from ecoreleve_server.utils.parseValue import isNumeric, formatThesaurus
from ecoreleve_server.core import RootCore
from ..permissions import context_permissions
from ..observations import Observation
from ..individuals import Individual
from ..stations import Station
from ..observations.equipment_model import checkEquip, set_equipment
from ..individuals.individual_resource import IndividualsResource

ProtocoleType = Observation.TypeClass


class ReleaseIndividualsResource(IndividualsResource):

    moduleGridName = 'IndivReleaseGrid'
    __acl__ = context_permissions['release']

    def getFilter(self, type_=None, moduleName=None):
        return []

    def handleCriteria(self, params):
        criteria = [{
            'Column': 'LastImported',
            'Operator': '=',
            'Value': True
        }]
        params['criteria'].extend(criteria)
        return params

    def handleResult(self, data):
        for row in data[1]:
            if 'Date_Sortie' in row and row['Date_Sortie'] is not None:
                row['Date_Sortie'] = row['Date_Sortie'].strftime(
                    '%Y-%m-%d %H:%M:%S')
        return data

    def retrieve(self):
        return self.search(paging=False)

    def updateAllStartDate(self, indiv, date, properties):
        for prop in properties:
            existingDynPropValues = list(filter(lambda p: p.fk_property == prop['ID'],
                                                indiv._dynamicValues))
            if existingDynPropValues:
                curValueProperty = max(
                    existingDynPropValues, key=operator.attrgetter('StartDate'))
                curValueProperty.StartDate = date

    def create(self):
        session = self.session
        request = self.request
        data = request.params.mixed()

        if 'StationID' not in data and 'IndividualList' not in data:
            if data == {}:
                data = request.json_body
            if 'FK_Sensor' in data and data['FK_Sensor'] not in (None, ''):
                return isavailableSensor(request, data)
            return

        sta_id = int(data['StationID'])
        indivListFromData = json.loads(data['IndividualList'])
        releaseMethod = data['releaseMethod']
        curStation = session.query(Station).get(sta_id)
        taxon = False

        userLang = request.authenticated_userid['userlanguage']
        indivList = []
        for row in indivListFromData:
            row = dict(map(lambda k: getFullpath(k, userLang), row.items()))
            indivList.append(row)

        def getnewObs(typeID):
            newObs = Observation()
            newObs.type_id = typeID
            newObs.FK_Station = sta_id
            return newObs

        protoTypes = pd.DataFrame(session.execute(select([ProtocoleType])).fetchall(
        ), columns=ProtocoleType.__table__.columns.keys())
        vertebrateGrpID = int(
            protoTypes.loc[protoTypes['Name'] == 'Vertebrate_group', 'ID'].values[0])
        vertebrateIndID = int(
            protoTypes.loc[protoTypes['Name'] == 'Vertebrate_individual', 'ID'].values[0])
        biometryID = int(
            protoTypes.loc[protoTypes['Name'] == 'Bird_Biometry', 'ID'].values[0])
        releaseGrpID = int(
            protoTypes.loc[protoTypes['Name'] == 'Release_Group', 'ID'].values[0])
        releaseIndID = int(
            protoTypes.loc[protoTypes['Name'] == 'Release_Individual', 'ID'].values[0])
        equipmentIndID = int(
            protoTypes.loc[protoTypes['Name'] == 'Individual_equipment', 'ID'].values[0])

        vertebrateIndList = []
        biometryList = []
        releaseIndList = []
        equipmentIndList = []

        binaryDict = {
            9: 'nb_adult_indeterminate',
            10: 'nb_adult_male',
            12: 'nb_adult_female',
            17: 'nb_juvenile_indeterminate',
            18: 'nb_juvenile_male',
            20: 'nb_juvenile_female',
            33: 'nb_indeterminate',
            36: 'nb_indeterminate',
            34: 'nb_indeterminate'
        }

        """ Return sex, age repartition of released individuals

            binary ponderation female : 4, male :2 , indeterminateSex : 1,
            adult:8, juvenile : 16, indeterminateAge : 32
        """
        def MoF_AoJ(obj):
            curSex = None
            curAge = None
            binP = 0
            if obj['Sex'] is not None and obj['Sex'].lower() == 'male':
                curSex = 'male'
                binP += 2
            elif obj['Sex'] is not None and obj['Sex'].lower() == 'female':
                curSex = 'female'
                binP += 4
            else:
                curSex == 'Indeterminate'
                binP += 1

            if obj['Age'] is not None and obj['Age'].lower() == 'Adult':
                curAge = 'Adult'
                binP += 8
            elif obj['Age'] is not None and obj['Age'].lower() == 'juvenile':
                curAge = 'Juvenile'
                binP += 16
            else:
                curAge == 'Indeterminate'
                binP += 32
            return binaryDict[binP]

        try:
            errorEquipment = None
            binList = []
            for indiv in indivList:
                curIndiv = session.query(Individual).get(indiv['ID'])
                if not taxon:
                    taxon = curIndiv.Species
                try:
                    indiv['taxon'] = curIndiv.Species
                    del indiv['species']
                except:
                    indiv['taxon'] = curIndiv.Species
                    del indiv['Species']
                    pass

                indiv['__useDate__'] = curStation.StationDate
                self.updateAllStartDate(
                    curIndiv, curStation.StationDate, curIndiv.properties)
                curIndiv.values = indiv

                curIndiv.enable_business_ruler = False
                binList.append(MoF_AoJ(indiv))  
                for k in indiv.keys():
                    v = indiv.pop(k)
                    k = k.lower()
                    indiv[k] = v

                indiv['FK_Individual'] = curIndiv.ID
                indiv['FK_Station'] = sta_id
                try:
                    indiv['weight'] = indiv['poids']
                except:
                    indiv['weight'] = indiv['Poids']
                    pass
                try:
                    indiv['Comments'] = indiv['release_comments']
                except:
                    print_exc()
                    pass

                curVertebrateInd = getnewObs(vertebrateIndID)
                curVertebrateInd.values = indiv
                curVertebrateInd.Comments = None
                vertebrateIndList.append(curVertebrateInd)

                curBiometry = getnewObs(biometryID)
                curBiometry.values = indiv
                curBiometry.Comments = None
                biometryList.append(curBiometry)

                curReleaseInd = getnewObs(releaseIndID)
                curReleaseInd.values = indiv
                releaseIndList.append(curReleaseInd)

                sensor_id = indiv.get(
                    'FK_Sensor', None) or indiv.get('fk_sensor', None)

                if sensor_id:
                    try:
                        curEquipmentInd = getnewObs(equipmentIndID)
                        equipInfo = {
                            'FK_Individual': indiv['FK_Individual'],
                            'FK_Sensor': sensor_id,
                            'Survey_type': 'post-relâcher',
                            'Monitoring_Status': 'suivi',
                            'Sensor_Status': 'sortie de stock>mise en service',
                            'FK_Station': curStation.ID,
                            '__useDate__': curStation.StationDate
                        }
                        curEquipmentInd.values = equipInfo
                        set_equipment(curEquipmentInd, curStation)
                        equipmentIndList.append(curEquipmentInd)
                    except Exception as e:
                        if e.__class__.__name__ == 'ErrorAvailable':
                            sensor_available = 'is' if e.value[
                                'sensor_available'] else 'is not'
                            tpl = 'SensorID {0} {1} available for equipment'.format(
                                equipInfo['FK_Sensor'], sensor_available)
                            if errorEquipment is None:
                                errorEquipment = tpl
                            else:
                                errorEquipment += ',   ' + tpl
                        else:
                            print_exc()
                            errorEquipment = e.__class__.__name__

            dictVertGrp = dict(Counter(binList))
            dictVertGrp['nb_total'] = len(releaseIndList)
            dictVertGrp['taxon'] = taxon

            obsVertGrpFiltered = list(filter(
                lambda o: o.type_id == vertebrateGrpID, curStation.Observations))
            obsReleaseGrpFiltered = list(
                filter(lambda o: o.type_id == releaseGrpID, curStation.Observations))

            if len(obsVertGrpFiltered) > 0:
                for obs in obsVertGrpFiltered:
                    if obs.values.get('taxon') == taxon:
                        vertebrateGrp = obs
                    else:
                        vertebrateGrp = None
            else:
                vertebrateGrp = None

            if len(obsReleaseGrpFiltered) > 0:
                for obs in obsReleaseGrpFiltered:
                    if obs.values.get('taxon') == taxon and obs.values.get('release_method') == releaseMethod:
                        releaseGrp = obs
                    else:
                        releaseGrp = None
            else:
                releaseGrp = None

            if vertebrateGrp:
                for prop, val in dictVertGrp.items():
                    if isNumeric(val):
                        vertebrateGrp.setValue(
                            prop, int(val) + int(vertebrateGrp.values.get(prop, 0)))
            else:
                vertebrateGrp = Observation()
                vertebrateGrp.session = session
                dictVertGrp.update({'FK_Station':sta_id, 'type_id': vertebrateGrpID})
                vertebrateGrp.values = dictVertGrp

            if releaseGrp:
                releaseGrp.setValue('nb_individuals', int(
                    obs.values.get('nb_individuals')) + len(releaseIndList))
            else:
                releaseGrp = Observation()
                releaseGrp.session = session
                releaseGrp.values = {'type_id':releaseGrpID,
                                    'FK_Station':sta_id,
                                    'taxon': taxon,
                                    'release_method': releaseMethod,
                                    'nb_individuals': len(releaseIndList)}

            releaseGrp.Observation_children.extend(releaseIndList)
            vertebrateGrp.Observation_children.extend(vertebrateIndList)

            if errorEquipment is not None:
                session.rollback()
                request.response.status_code = 510
                message = errorEquipment

            else:
                session.add(vertebrateGrp)
                session.add(releaseGrp)
                session.add_all(biometryList)
                session.add_all(equipmentIndList)
                message = {'release': len(releaseIndList)}

        except Exception as e:
            print_exc()
            self.request.response.status_code = 500
            session.rollback()
            message = str(type(e))
        finally:
            Individual.enable_business_ruler = True
            
        return message


class ReleaseResource(CustomResource):

    model = None
    __acl__ = context_permissions['release']
    children = [('individuals',ReleaseIndividualsResource)]

    def getReleaseMethod(self):
        userLng = self.request.authenticated_userid['userlanguage'].lower()
        if not userLng:
            userLng = 'fr'
        query = text("""SELECT TTop_FullPath as val, TTop_Name as label"""
                     + """ FROM THESAURUS.dbo.TTopic th
            JOIN [ModuleForms] f on th.TTop_ParentID = f.Options
            where Name = 'release_method' """)
        result = self.session.execute(query).fetchall()
        result = [dict(row) for row in result]
        if userLng != 'fr':
            for row in result:
                row['label'] = formatThesaurus(row['val'])['displayValue']
        return result


RootCore.children.append(('release', ReleaseResource))


def isavailableSensor(request, data):
    availability = checkEquip(data['FK_Sensor'], datetime.strptime(
        data['sta_date'], '%d/%m/%Y %H:%M:%S'))
    if availability is True:
        return
    else:
        request.response.status_code = 510
        return 'sensor not available'


def getFullpath(item, lng):
    name, val = item
    try:
        newVal = invertedThesaurusDict[lng][val]
    except:
        newVal = val
    return (name, newVal)
