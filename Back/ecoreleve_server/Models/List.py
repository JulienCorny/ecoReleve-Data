from sqlalchemy import (and_,
 func,
 insert,
 select,
 exists,
 join,
 cast,
 not_,
 or_,
 DATE,
 case,
 literal_column,
 outerjoin)
from sqlalchemy.orm import aliased
from ..GenericObjets.ListObjectWithDynProp import ListObjectWithDynProp
from ..Models import (
    DBSession,
    Observation,
    ProtocoleType,
    Station,
    Station_FieldWorker,
    User,
    Individual,
    Base,
    Equipment,
    Sensor,
    SensorType,
    SensorDynPropValue,
    Individual_Location,
    MonitoredSite
    )
from ..utils import Eval
import pandas as pd 
from collections import OrderedDict
from datetime import datetime
from ..utils.datetime import parse
from ..utils.generator import Generator
from sqlalchemy.sql.expression import literal_column,literal


eval_ = Eval()

#--------------------------------------------------------------------------
class StationList(ListObjectWithDynProp):
    ''' this class extend ListObjectWithDynProp, it's used to filter stations '''
    def __init__(self,frontModule, startDate = None) :
        super().__init__(Station,frontModule, startDate)

    def WhereInJoinTable (self,query,criteriaObj) :
        ''' Override parent function to include management of Observation/Protocols and fieldWorkers '''
        query = super().WhereInJoinTable(query,criteriaObj)
        curProp = criteriaObj['Column']
        if curProp == 'FK_ProtocoleType':
            subSelect = select([Observation]
                ).where(
                and_(Station.ID== Observation.FK_Station
                    ,eval_.eval_binary_expr(Observation.__table__.c[curProp],criteriaObj['Operator'],criteriaObj['Value'])))
            query = query.where(exists(subSelect))

        if curProp == 'FK_Individual':

            if criteriaObj['Operator'].lower() in ['is null','is not null']:
                subSelect = select([Observation]).where(
                    and_(Station.ID== Observation.FK_Station
                        ,Observation.__table__.c[curProp] != None)
                    )
                if criteriaObj['Operator'].lower() == 'is':
                    query = query.where(~exists(subSelect))
                else:
                    query = query.where(exists(subSelect))

            else:
                subSelect = select([Observation]
                    ).where(
                    and_(Station.ID== Observation.FK_Station
                        ,eval_.eval_binary_expr(Observation.__table__.c[curProp],criteriaObj['Operator'],criteriaObj['Value'])))
                query = query.where(exists(subSelect))

        if curProp == 'FK_FieldWorker':
            subSelect = select([Station_FieldWorker]
                ).where(
                and_(Station.ID== Station_FieldWorker.FK_Station
                    ,eval_.eval_binary_expr(Station_FieldWorker.__table__.c[curProp],criteriaObj['Operator'],criteriaObj['Value'])))
            query = query.where(exists(subSelect))

        if curProp == 'LastImported':
            st = aliased(Station)
            subSelect = select([Observation]).where(Observation.FK_Station == Station.ID)
            subSelect2 = select([st]).where(cast(st.creationDate,DATE) > cast(Station.creationDate,DATE))
            query = query.where(and_(~exists(subSelect),~exists(subSelect2)))

        return query

    def GetFlatDataList(self,searchInfo=None,getFieldWorkers=True) :
        ''' Override parent function to include management of Observation/Protocols and fieldWorkers '''
        fullQueryJoinOrdered = self.GetFullQuery(searchInfo)
        result = self.ObjContext.execute(fullQueryJoinOrdered).fetchall()
        data = []

        if getFieldWorkers:
            # listID = list(map(lambda x: x['ID'],result))
            queryCTE = fullQueryJoinOrdered.cte()
            joinFW = join(Station_FieldWorker,User,Station_FieldWorker.FK_FieldWorker==User.id)
            joinTable = join(queryCTE,joinFW,queryCTE.c['ID']== Station_FieldWorker.FK_Station)

            query = select([Station_FieldWorker.FK_Station,User.Login]).select_from(joinTable)
            FieldWorkers = self.ObjContext.execute(query).fetchall()
        
            list_ = {}
            for x,y in FieldWorkers :
                list_.setdefault(x,[]).append(y)
            for row in result :
                row = OrderedDict(row)
                try :
                    row['FK_FieldWorker_FieldWorkers'] = list_[row['ID']]
                except:
                    pass
                data.append(row)
        else:
            for row in result :
                row = OrderedDict(row)
                data.append(row)
        return data

    def countQuery(self,criteria = None):
        query = super().countQuery(criteria)
        for obj in criteria :
            if obj['Column'] in ['FK_ProtocoleType','FK_FieldWorker','LastImported','FK_Individual']:
                query = self.WhereInJoinTable(query,obj)
        return query


#--------------------------------------------------------------------------
class IndividualList(ListObjectWithDynProp):

    def __init__(self,frontModule, typeObj = None, startDate = None,history = None,historyView = None) :
        super().__init__(Individual,frontModule, typeObj = typeObj,startDate = startDate,history=history)

    def GetJoinTable (self,searchInfo) :
        startDate = datetime.now()
        if self.startDate :
            startDate = self.startDate

        StatusTable = Base.metadata.tables['IndividualStatus']
        EquipmentTable = Base.metadata.tables['IndividualEquipment']

        joinTable = super().GetJoinTable(searchInfo)
        
        joinTable = outerjoin(joinTable,StatusTable,StatusTable.c['FK_Individual'] == Individual.ID)

        self.selectable.append(StatusTable.c['Status_'].label('Status_'))

        joinTable = outerjoin(joinTable,EquipmentTable
            ,and_(Individual.ID == EquipmentTable.c['FK_Individual']
                ,or_(EquipmentTable.c['EndDate'] >= startDate,EquipmentTable.c['EndDate'] == None )))
                #EquipmentTable.c['EndDate'] >= func.isnull(EquipmentTable.c['EndDate'],datetime.now()))))
        joinTable = outerjoin(joinTable,Sensor,Sensor.ID == EquipmentTable.c['FK_Sensor'])
        joinTable = outerjoin(joinTable,SensorType,Sensor.FK_SensorType == SensorType.ID)

        self.selectable.append(Sensor.UnicIdentifier.label('FK_Sensor'))
        self.selectable.append(SensorType.Name.label('FK_SensorType'))
        self.selectable.append(Sensor.Model.label('FK_SensorModel'))

        return joinTable

    def WhereInJoinTable (self,query,criteriaObj) :
        query = super().WhereInJoinTable(query,criteriaObj)
        curProp = criteriaObj['Column']
        if curProp == 'LastImported':
            st = aliased(Individual)
            subSelect = select([Observation]).where(Observation.FK_Individual == Individual.ID)
            query = query.where(and_(~exists(subSelect),Individual.Original_ID.like('TRACK_%')))

        if curProp == 'FK_Sensor':
            query = query.where(eval_.eval_binary_expr(Sensor.UnicIdentifier,criteriaObj['Operator'],criteriaObj['Value']))

        if curProp == 'Status_':
            StatusTable = Base.metadata.tables['IndividualStatus']
            query = query.where(eval_.eval_binary_expr(StatusTable.c['Status_'],criteriaObj['Operator'],criteriaObj['Value']))

        return query

    def countQuery(self,criteria = None):
        query = super().countQuery(criteria)
        # if len(list(filter(lambda x:'frequency'==x['Column'], criteria)))>0:
        #     query = self.whereInEquipementVHF(query,criteria)
        for obj in criteria :
            if obj['Column'] in ['LastImported']:
                query = self.WhereInJoinTable(query,obj)

            if obj['Column'] == 'Status_':
                StatusTable = Base.metadata.tables['IndividualStatus']
                existsQueryStatus = select([StatusTable.c['FK_Individual']]
                    ).where(and_(Individual.ID == StatusTable.c['FK_Individual']
                    ,eval_.eval_binary_expr(StatusTable.c['Status_'],obj['Operator'],obj['Value'])))
                query = query.where(exists(existsQueryStatus))

            if obj['Column'] == 'frequency':
                query = self.whereInEquipementVHF(query,criteria)

            if obj['Column'] == 'FK_Sensor':
                query = self.whereInEquipement(query,criteria)

        return query

    def GetFullQuery(self,searchInfo=None) :
        ''' return the full query to execute '''
        if searchInfo is None or 'criteria' not in searchInfo:
            searchInfo['criteria'] = []

        joinTable = self.GetJoinTable(searchInfo)
        fullQueryJoin = select(self.selectable).select_from(joinTable)

        if len(list(filter(lambda x:'frequency'==x['Column'], searchInfo['criteria'])))>0:
            fullQueryJoin = self.whereInEquipementVHF(fullQueryJoin,searchInfo['criteria'])

        for obj in searchInfo['criteria'] :
            fullQueryJoin = self.WhereInJoinTable(fullQueryJoin,obj)

        print(fullQueryJoin)
        fullQueryJoinOrdered = self.OderByAndLimit(fullQueryJoin,searchInfo)
        return fullQueryJoinOrdered

    def GetFullQueryHistory(self,searchInfo=None) :
        if searchInfo is None or 'criteria' not in searchInfo:
            searchInfo['criteria'] = []

        joinTable = self.GetJoinTable(searchInfo)
        fullQueryJoin = select(self.selectable).select_from(joinTable)

        queryHistory = select(self.historyValuetable.c).where(self.historyValuetable.c[self.ObjWithDynProp().GetSelfFKNameInValueTable()] == self.ObjWithDynProp.ID)
        self.excHist = False

        for obj in searchInfo['criteria'] :
            curProp = obj['Column']
            curDynProp = self.GetDynProp(curProp)

            if curProp in self.fk_list and curProp in self.searchInFK and not self.history:
                fullQueryJoin = fullQueryJoin.where(
                    eval_.eval_binary_expr(self.searchInFK[curProp]['table'].c[self.searchInFK[curProp]['nameProp']]
                        ,obj['Operator'],obj['Value'])
                    )

            elif hasattr(self.ObjWithDynProp,curProp):
                fullQueryJoin = self.filterOnStaticProp(fullQueryJoin,obj)

            elif curDynProp is not None :
                queryHistory = queryHistory.where(and_(eval_.eval_binary_expr(self.historyValuetable.c['Value'+curDynProp['TypeProp']]
                    ,obj['Operator'],obj['Value'] ),self.historyValuetable.c['Name']==curProp))
                self.excHist = True

            if obj['Column'] == 'FK_Sensor':
                print('WHEREin EQuipment !!!!!! ')
                fullQueryJoin = self.whereInEquipement(fullQueryJoin,searchInfo['criteria'])

        if self.excHist :
            print('add exists histo ')
            fullQueryJoin = fullQueryJoin.where(exists(queryHistory))
            print(fullQueryJoin)
        fullQueryJoinOrdered = self.OderByAndLimit(fullQueryJoin,searchInfo)

        return fullQueryJoinOrdered

    def whereInEquipementVHF(self,fullQueryJoin,criteria):
        startDate = datetime.now()

        if self.startDate :
            startDate = self.startDate

        freqObj = list(filter(lambda x:'frequency'==x['Column'], criteria))[0]
        freq = freqObj['Value']
        e2 = aliased(Equipment)
        vs = Base.metadata.tables['SensorDynPropValuesNow']
        joinTableExist = join(Equipment,Sensor,Equipment.FK_Sensor==Sensor.ID)
        joinTableExist = join(joinTableExist,vs,vs.c['FK_Sensor']==Sensor.ID)
        
        queryExist = select([e2]).where(
            and_(Equipment.FK_Individual==e2.FK_Individual
                ,and_(e2.StartDate>Equipment.StartDate,e2.StartDate<startDate)))

        fullQueryExist = select([Equipment.FK_Individual]).select_from(joinTableExist)
        fullQueryExist = fullQueryExist.where(and_(~exists(queryExist)
            ,and_(vs.c['FK_SensorDynProp']==9,and_(Sensor.FK_SensorType==4,and_(Equipment.Deploy==1,
                and_(Equipment.StartDate<startDate,Equipment.FK_Individual==Individual.ID))))))

        if freqObj['Operator'].lower() in ['is'] and freqObj['Value'].lower() == 'null':
            fullQueryJoin = fullQueryJoin.where(~exists(fullQueryExist))
        else :
            fullQueryExist = fullQueryExist.where(eval_.eval_binary_expr(vs.c['ValueInt'],freqObj['Operator'],freq))
            fullQueryJoin = fullQueryJoin.where(exists(fullQueryExist))

        return fullQueryJoin

    def whereInEquipement(self,fullQueryJoin,criteria):
        sensorObj = list(filter(lambda x:'FK_Sensor'==x['Column'], criteria))[0]
        sensor = sensorObj['Value']

        table = Base.metadata.tables['IndividualEquipment']
        joinTable = outerjoin(table,Sensor, table.c['FK_Sensor'] == Sensor.ID)
        startDate = datetime.now()

        if self.startDate :
            startDate = self.startDate

        if self.history:
             self.excHist = True

        subSelect= select([table.c['FK_Individual']]
            ).select_from(joinTable).where(Individual.ID== table.c['FK_Individual'])

# <<<<<<< HEAD
        if sensorObj['Operator'].lower() in ['is null','is not null'] :
            # subSelect = select([table.c['FK_Individual']]
            #     ).select_from(joinTable).where(
            #     and_(Individual.ID== table.c['FK_Individual']
            #         ,or_(table.c['EndDate'] >= startDate,table.c['EndDate'] == None)
            #             ))

            if not self.history : 
                subSelect = subSelect.where(or_(table.c['EndDate'] >= startDate,table.c['EndDate'] == None))
        else:
            # subSelect = select([table.c['FK_Individual']]
            #     ).select_from(joinTable).where(
            #     and_(Individual.ID== table.c['FK_Individual']
            #         ,and_(eval_.eval_binary_expr(Sensor.UnicIdentifier,sensorObj['Operator'],sensor)
            #             ,or_(table.c['EndDate'] >= startDate,table.c['EndDate'] == None))
            #             ))
            subSelect = subSelect.where(eval_.eval_binary_expr(Sensor.UnicIdentifier,sensorObj['Operator'],sensor))

            if not self.history : 
                subSelect = subSelect.where(or_(table.c['EndDate'] >= startDate,table.c['EndDate'] == None))

        if sensorObj['Operator'].lower() == 'is null':
            fullQueryJoin = fullQueryJoin.where(~exists(subSelect))
# =======
#         if sensorObj['Operator'].lower() in ['is null','is not null']:
#             subSelect = select([table.c['FK_Individual']]
#                 ).select_from(joinTable).where(
#                 and_(Individual.ID== table.c['FK_Individual']
#                     ,or_(table.c['EndDate'] >= func.now(),table.c['EndDate'] == None)
#                         ))
#             if sensorObj['Operator'].lower() == 'is':
#                 fullQueryJoin = fullQueryJoin.where(~exists(subSelect))
#             else :
#                 fullQueryJoin = fullQueryJoin.where(exists(subSelect))
# >>>>>>> 82bfdc640c04d9a237d184fac499262d3f070470
        else :
            fullQueryJoin = fullQueryJoin.where(exists(subSelect))


        return fullQueryJoin

#--------------------------------------------------------------------------
class IndivLocationList(Generator):

    def __init__(self,table,SessionMaker,id_=None):
        allLocIndiv = Base.metadata.tables['allIndivLocationWithStations']
        IndivLoc = select(allLocIndiv.c).where(allLocIndiv.c['FK_Individual'] == id_
            ).cte()
        super().__init__(IndivLoc,SessionMaker)

#--------------------------------------------------------------------------
class SensorList(ListObjectWithDynProp):

    def __init__(self,frontModule, startDate = None) :
        super().__init__(Sensor,frontModule, startDate)

    def GetJoinTable (self,searchInfo) :
        curEquipmentTable = Base.metadata.tables['CurrentlySensorEquiped']
        MonitoredSiteTable = Base.metadata.tables['MonitoredSite']
        joinTable = super().GetJoinTable(searchInfo)

        joinTable = outerjoin(joinTable,curEquipmentTable,curEquipmentTable.c['FK_Sensor'] == Sensor.ID)

        joinTable = outerjoin(joinTable,MonitoredSite,MonitoredSiteTable.c['ID'] == curEquipmentTable.c['FK_MonitoredSite'])

        self.selectable.append(MonitoredSiteTable.c['Name'].label('FK_MonitoredSiteName'))
        self.selectable.append(curEquipmentTable.c['FK_Individual'].label('FK_Individual'))

        return joinTable

    def WhereInJoinTable (self,query,criteriaObj) :
        query = super().WhereInJoinTable(query,criteriaObj)
        curProp = criteriaObj['Column']
        if 'available' in curProp.lower():
            date = criteriaObj['Value']
            try:
                date = parse(date.replace(' ',''))
            except:
                pass
            s2 = aliased(Sensor)
            e = aliased(Equipment)
            e2 = aliased(Equipment)

            subQueryEquip = select([e2]).where(
                and_(e.FK_Sensor==e2.FK_Sensor,
                    and_(e.StartDate<e2.StartDate,e2.StartDate<=date)))

            querySensor = select([e]).where(
                and_(e.StartDate<=date,
                    and_(e.Deploy==0,
                        and_(Sensor.ID==e.FK_Sensor,not_(exists(subQueryEquip)))
                        )
                    ))
            if criteriaObj['Operator'].lower() != 'is not':
                query = query.where(exists(querySensor))
            else:
                query = query.where(not_(exists(querySensor)))

        if 'FK_MonitoredSiteName' == curProp :
            MonitoredSiteTable = Base.metadata.tables['MonitoredSite']
            val = criteriaObj['Value']
            query = query.where(eval_.eval_binary_expr(MonitoredSiteTable.c['Name'],criteriaObj['Operator'],val))

        if 'FK_Individual'== curProp :
            curEquipmentTable = Base.metadata.tables['CurrentlySensorEquiped']
            val = criteriaObj['Value']
            query = query.where(eval_.eval_binary_expr(curEquipmentTable.c['FK_Individual'],criteriaObj['Operator'],val))

        return query

    def countQuery(self,criteria = None):
        query = super().countQuery(criteria)

        curEquipmentTable = Base.metadata.tables['CurrentlySensorEquiped']
        MonitoredSiteTable = Base.metadata.tables['MonitoredSite']
        # joinTable = outerjoin(Sensor,curEquipmentTable,curEquipmentTable.c['FK_Sensor'] == Sensor.ID)
        joinTable = outerjoin(curEquipmentTable,MonitoredSite,MonitoredSiteTable.c['ID'] == curEquipmentTable.c['FK_MonitoredSite'])

        for obj in criteria :
            if 'available' in obj['Column']:
                query = self.WhereInJoinTable(query,obj)

            if obj['Column'] in ['FK_MonitoredSiteName','FK_Individual'] and obj['Operator'] not in ['is null','is not null']:
                queryExist = select(curEquipmentTable.c).select_from(joinTable
                    ).where(Sensor.ID == curEquipmentTable.c['FK_Sensor'])

                if obj['Column'] == 'FK_MonitoredSiteName' :
                    queryExist = queryExist.where(eval_.eval_binary_expr(MonitoredSiteTable.c['Name'],obj['Operator'],obj['Value']))
                if obj['Column'] == 'FK_Individual' :
                    queryExist = queryExist.where(eval_.eval_binary_expr(curEquipmentTable.c['FK_Individual'],obj['Operator'],obj['Value']))
                query = query.where(exists(queryExist))


            if obj['Column'] in ['FK_MonitoredSiteName','FK_Individual'] and obj['Operator'] in ['is null','is not null']:
                queryExist = select(curEquipmentTable.c).select_from(joinTable
                    ).where(Sensor.ID == curEquipmentTable.c['FK_Sensor'])

                if obj['Column'] == 'FK_Individual' :
                    queryExist = queryExist.where(and_(Sensor.ID == curEquipmentTable.c['FK_Sensor']
                        ,curEquipmentTable.c['FK_Individual'] != None))

                if obj['Column'] == 'FK_MonitoredSiteName' :
                    queryExist = queryExist.where(and_(Sensor.ID == curEquipmentTable.c['FK_Sensor']
                        ,curEquipmentTable.c['FK_MonitoredSite'] != None))
                if 'not' in obj['Operator']:
                    query = query.where(exists(queryExist))
                else :
                    query = query.where(not_(exists(queryExist)))


        return query




class MonitoredSiteList(ListObjectWithDynProp):

    def __init__(self,frontModule, typeObj = None, View = None) :
        super().__init__(MonitoredSite,frontModule, typeObj = typeObj, View = View)

    def GetJoinTable (self,searchInfo) :
        EquipmentTable = Base.metadata.tables['MonitoredSiteEquipment']

        joinTable = super().GetJoinTable(searchInfo)

        joinTable = outerjoin(joinTable,EquipmentTable
            ,and_(MonitoredSite.ID == EquipmentTable.c['FK_MonitoredSite']
                ,or_(EquipmentTable.c['EndDate'] == None,EquipmentTable.c['EndDate'] >= func.now())))
        joinTable = outerjoin(joinTable,Sensor,Sensor.ID == EquipmentTable.c['FK_Sensor'])
        joinTable = outerjoin(joinTable,SensorType,Sensor.FK_SensorType == SensorType.ID)

        self.selectable.append(Sensor.UnicIdentifier.label('FK_Sensor'))
        self.selectable.append(SensorType.Name.label('FK_SensorType'))
        self.selectable.append(Sensor.Model.label('FK_SensorModel'))

        return joinTable

    def WhereInJoinTable (self,query,criteriaObj) :
        query = super().WhereInJoinTable(query,criteriaObj)
        curProp = criteriaObj['Column']

        if curProp == 'FK_Sensor':
            query = query.where(eval_.eval_binary_expr(Sensor.UnicIdentifier,criteriaObj['Operator'],criteriaObj['Value']))

        return query

    def countQuery(self,criteria = None):
        query = super().countQuery(criteria)
        for obj in criteria :
            if obj['Column'] == 'FK_Sensor':
                query = self.whereInEquipement(query,criteria)

        return query

    def whereInEquipement(self,fullQueryJoin,criteria):
        sensorObj = list(filter(lambda x:'FK_Sensor'==x['Column'], criteria))[0]
        sensor = sensorObj['Value']

        table = Base.metadata.tables['MonitoredSiteEquipment']
        joinTable = outerjoin(table,Sensor, table.c['FK_Sensor'] == Sensor.ID)

        if sensorObj['Operator'].lower() in ['is','is not'] and sensorObj['Value'].lower() == 'null':
            subSelect = select([table.c['FK_MonitoredSite']]
                ).select_from(joinTable).where(
                and_(MonitoredSite.ID== table.c['FK_MonitoredSite']
                    ,or_(table.c['EndDate'] >= func.now(),table.c['EndDate'] == None)
                        ))
            if sensorObj['Operator'].lower() == 'is':
                fullQueryJoin = fullQueryJoin.where(~exists(subSelect))
            else :
                fullQueryJoin = fullQueryJoin.where(exists(subSelect))
        else :
            subSelect = select([table.c['FK_MonitoredSite']]
                ).select_from(joinTable).where(
                and_(MonitoredSite.ID== table.c['FK_MonitoredSite']
                    ,and_(eval_.eval_binary_expr(Sensor.UnicIdentifier,sensorObj['Operator'],sensor)
                        ,or_(table.c['EndDate'] >= func.now(),table.c['EndDate'] == None))
                        ))
            fullQueryJoin = fullQueryJoin.where(exists(subSelect))
        return fullQueryJoin
