USE [EcoReleve_Export_ECWP]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportOneProtocole]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportOneProtocole]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportObservationDynPropValueNow]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportObservationDynPropValueNow]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportIndividualLastLocationSensor]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportIndividualLastLocationSensor]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportIndividualLastLocationAllSource]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportIndividualLastLocationAllSource]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportFirstStation]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportFirstStation]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAllStation]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportAllStation]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAllSensor]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportAllSensor]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAllProtocole]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportAllProtocole]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAllMonitoredSite]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportAllMonitoredSite]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAllIndividu]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportAllIndividu]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAll]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportAll]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAfterCreateIndex]    Script Date: 24/03/2016 09:53:25 ******/
DROP PROCEDURE [dbo].[pr_ExportAfterCreateIndex]
GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAfterCreateIndex]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[pr_ExportAfterCreateIndex]
AS
BEGIN


	CREATE UNIQUE CLUSTERED INDEX pk_TStation on TStation(ID)

	CREATE INDEX IX_Station_StationDate ON Tstation(StationDate)

	CREATE INDEX IX_TProtocol_Release_Individual_fk_individu ON [TProtocol_Release_Individual](fk_individual)

	CREATE INDEX IX_TProtocol_Release_Individual_fk_Station ON [TProtocol_Release_Individual](fk_Station)


	CREATE INDEX IX_TProtocol_Capture_Individual_fk_individu ON [TProtocol_Capture_Individual](fk_individual)

	CREATE INDEX IX_TProtocol_Capture_Individual_fk_Station ON [TProtocol_Capture_Individual](fk_Station)

	CREATE INDEX IX_TProtocol_Release_Individual_Parent_Observation ON [TProtocol_Release_Individual]([Parent_Observation])

	CREATE INDEX [IX_TIndividual] ON [dbo].[TIndividu] ([ID])

	CREATE INDEX [IX_Sensor_ID_UnicIdentifier] ON [dbo].[TSensor]
	(
	[ID] ASC
	)
	INCLUDE (UnicIdentifier)

END


GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAll]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[pr_ExportAll]
AS
BEGIN
SET NOCOUNT on
SET ANSI_WARNINGS OFF
	delete from [dbo].[TImportInfo] where ImportInfoName='ExportObservationDynPropValueNow'

	print 'export individus'
	exec pr_ExportAllIndividu
	print ' export Stations '
	exec pr_ExportAllStation
	print ' export MonitoredSites '
	exec pr_ExportAllMonitoredSite
	print ' export Sensors '
	exec pr_ExportAllSensor

	print ' export Observations '
	exec pr_ExportAllProtocole

	print ' export AfterCreateIndex '
	exec pr_ExportAfterCreateIndex

	print ' export FirstStation '
	exec pr_ExportFirstStation

	print 'export LastLocationSensor'
	exec pr_ExportIndividualLastLocationSensor

	print ' export Last LocationAllSource '
	exec pr_ExportIndividualLastLocationAllSource
END


GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAllIndividu]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[pr_ExportAllIndividu] 
AS
BEGIN


	IF object_id('TmpIndivExport') IS NOT NULL
			DROP TABLE TmpIndivExport


	select * into TmpIndivExport 
	from [EcoReleve_ECWP].dbo.individual
	where FK_IndividualType = 1 

	--select * from TmpIndivExport
	DECLARE @Req NVARCHAR(MAX)
	DECLARE @ReqFrom NVARCHAR(MAX)
	DECLARE @ReqSet NVARCHAR(MAX)

	SET @Req = ' ALTER TABLE TmpIndivExport ADD@'

	select @Req = @Req + ',    ' +  replace(D.Name,' ','_') + ' ' + replace(replace(d.typeProp,'Integer','INT'),'string','varchar(255)')  
	from [EcoReleve_ECWP].dbo.IndividualDynProp D
	JOIN [EcoReleve_ECWP].dbo.IndividualType_IndividualDynProp l ON l.FK_IndividualDynProp = D.ID
	JOIN [EcoReleve_ECWP].dbo.IndividualType t ON t.ID = l.FK_IndividualType 
	where t.ID = 1 

	SET @Req = replace(@Req,'ADD@,','ADD ')

	--print @req

	exec ( @req)

	--select * from TmpIndivExport

	SET @ReqSet = 'SET@'
	SET @ReqFrom =''

	SELECT @ReqSet = @ReqSet + ',' + replace(P.Name,' ','_') + '=V.' + replace(P.Name,' ','_'), @ReqFrom = @ReqFrom + ',MAX(CASE WHEN Name=''' +  replace(P.Name,' ','_') + ''' THEN Value' + replace(P.TypeProp,'Integer','Int') + ' ELSE NULL END) ' + replace(P.Name,' ','_')																						
	from [EcoReleve_ECWP].dbo.IndividualDynProp P
	JOIN [EcoReleve_ECWP].dbo.IndividualType_IndividualDynProp l ON l.FK_IndividualDynProp = P.ID
	JOIN [EcoReleve_ECWP].dbo.IndividualType t ON t.ID = l.FK_IndividualType 
	where t.ID = 1 

	SET @ReqSet = replace(@ReqSet,'SET@,','SET ')

	SET @Req = 'UPDATE EI ' + @ReqSet +  ' FROM TmpIndivExport EI JOIN (SELECT VN.FK_Individual ' + @ReqFrom + ' FROM   [EcoReleve_ECWP].dbo.IndividualDynPropValuesNow VN GROUP BY VN.FK_Individual) V ON EI.ID = V.FK_Individual '
	print @req
	exec ( @req)

	ALTER TABLE TmpIndivExport ADD Status_ varchar(250)

	Update e SET Status_=s.Status_
	FROM TmpIndivExport e
	JOIN [EcoReleve_ECWP].dbo.IndividualStatus s ON e.ID = s.FK_Individual


	IF object_id('TIndividu') IS NOT NULL DROP TABLE  TIndividu
	
	exec sp_rename 'TmpIndivExport','TIndividu'


	---------------------------- NON ID Indiv

		IF object_id('TmpIndivNON_ID_Export') IS NOT NULL
			DROP TABLE TmpIndivNON_ID_Export

	select * into TmpIndivNON_ID_Export 
	from [EcoReleve_ECWP].dbo.individual
	where FK_IndividualType = 2


	SET @Req = ' ALTER TABLE TmpIndivNON_ID_Export ADD@'

	select @Req = @Req + ',    ' +  replace(D.Name,' ','_') + ' ' + replace(replace(d.typeProp,'Integer','INT'),'string','varchar(255)')  
	from [EcoReleve_ECWP].dbo.IndividualDynProp D
	JOIN [EcoReleve_ECWP].dbo.IndividualType_IndividualDynProp l ON l.FK_IndividualDynProp = D.ID
	JOIN [EcoReleve_ECWP].dbo.IndividualType t ON t.ID = l.FK_IndividualType 
	where t.ID = 2

	SET @Req = replace(@Req,'ADD@,','ADD ')

	--print @req

	exec ( @req)

	--select * from TmpIndivExport

	SET @ReqSet = 'SET@'
	SET @ReqFrom =''

	SELECT @ReqSet = @ReqSet + ',' + replace(P.Name,' ','_') + '=V.' + replace(P.Name,' ','_'), @ReqFrom = @ReqFrom 
	+ ',MAX(CASE WHEN Name=''' +  replace(P.Name,' ','_') + ''' THEN Value' + replace(P.TypeProp,'Integer','Int') + ' ELSE NULL END) ' + replace(P.Name,' ','_')																						
	from [EcoReleve_ECWP].dbo.IndividualDynProp P
	JOIN [EcoReleve_ECWP].dbo.IndividualType_IndividualDynProp l ON l.FK_IndividualDynProp = P.ID
	JOIN [EcoReleve_ECWP].dbo.IndividualType t ON t.ID = l.FK_IndividualType 
	where t.ID = 2


	SET @ReqSet = replace(@ReqSet,'SET@,','SET ')

	SET @Req = 'UPDATE EI ' + @ReqSet +  ' FROM TmpIndivNON_ID_Export EI JOIN (SELECT VN.FK_Individual ' 
	+ @ReqFrom + ' FROM   [EcoReleve_ECWP].dbo.IndividualDynPropValuesNow VN GROUP BY VN.FK_Individual) V ON EI.ID = V.FK_Individual '
	print @req
	exec ( @req)

	ALTER TABLE TmpIndivNON_ID_Export ADD Status_ varchar(250)


	IF object_id('TIndividu_Non_Identified') IS NOT NULL DROP TABLE  TIndividu_Non_Identified
	
	exec sp_rename 'TmpIndivNON_ID_Export','TIndividu_Non_Identified'

END










GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAllMonitoredSite]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[pr_ExportAllMonitoredSite] 
AS
BEGIN


	IF object_id('TmpMonitoredSiteExport') IS NOT NULL
			DROP TABLE TmpMonitoredSiteExport



	select * into TmpMonitoredSiteExport 
	from [EcoReleve_ECWP].dbo.MonitoredSite

	--select * from TmpIndivExport
	DECLARE @Req NVARCHAR(MAX)
	DECLARE @ReqFrom NVARCHAR(MAX)
	DECLARE @ReqSet NVARCHAR(MAX)
	IF EXISTS (SELECT * from [EcoReleve_ECWP].dbo.MonitoredSiteDynProp)
	BEGIN
		SET @Req = ' ALTER TABLE TmpMonitoredSiteExport ADD@'

		select @Req = @Req + ',    ' +  replace(D.Name,' ','_') + ' ' + replace(replace(d.typeProp,'Integer','INT'),'string','varchar(255)')  from [EcoReleve_ECWP].dbo.MonitoredSiteDynProp D

		SET @Req = replace(@Req,'ADD@,','ADD ')

		--print @req

		exec ( @req)

		--select * from TmpIndivExport

		SET @ReqSet = 'SET@'
		SET @ReqFrom =''

		SELECT @ReqSet = @ReqSet + ',' + replace(P.Name,' ','_') + '=V.' + replace(P.Name,' ','_'), @ReqFrom = @ReqFrom + ',MAX(CASE WHEN Name=''' +  replace(P.Name,' ','_') + ''' THEN Value' + replace(P.TypeProp,'Integer','Int') + ' ELSE NULL END) ' + replace(P.Name,' ','_')																						
		from [EcoReleve_ECWP].dbo.MonitoredSiteDynProp P

		SET @ReqSet = replace(@ReqSet,'SET@,','SET ')

		SET @Req = 'UPDATE EI ' + @ReqSet +  ' FROM TmpMonitoredSiteExport EI JOIN (SELECT VN.FK_MonitoredSite ' + @ReqFrom + ' FROM   [EcoReleve_ECWP].dbo.MonitoredSiteDynPropValuesNow VN GROUP BY VN.FK_MonitoredSite) V ON EI.ID = V.FK_MonitoredSite '
		exec ( @req)
	END

	IF object_id('TMonitoredSite') IS NOT NULL DROP TABLE  TMonitoredSite
	
	exec sp_rename 'TmpMonitoredSiteExport','TMonitoredSite'
END








GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAllProtocole]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[pr_ExportAllProtocole] 
AS
BEGIN

	DECLARE @ProtocoleType INT
	Select ID into #ProtList from [EcoReleve_ECWP].dbo.ProtocoleType
	--where ID not in (208)

	WHILE EXISTS (select * from #ProtList) 
	BEGIN
		SELECT TOP 1 @ProtocoleType=ID FROM #ProtList
		--print @ProtocoleType
		execute pr_ExportOneProtocole @ProtocoleType
		DELETE FROM #ProtList WHERE ID=@ProtocoleType
	END

END




GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAllSensor]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[pr_ExportAllSensor] 
AS
BEGIN


	IF object_id('TmpSensorExport') IS NOT NULL
			DROP TABLE TmpSensorExport



	select * into TmpSensorExport 
	from [EcoReleve_ECWP].dbo.Sensor

	--select * from TmpIndivExport
	DECLARE @Req NVARCHAR(MAX)
	DECLARE @ReqFrom NVARCHAR(MAX)
	DECLARE @ReqSet NVARCHAR(MAX)
	IF EXISTS (SELECT * from [EcoReleve_ECWP].dbo.SensorDynProp)
	BEGIN
		SET @Req = ' ALTER TABLE TmpSensorExport ADD@'

		select @Req = @Req + ',    ' +  replace(D.Name,' ','_') + ' ' + replace(replace(d.typeProp,'Integer','INT'),'string','varchar(255)')  from [EcoReleve_ECWP].dbo.SensorDynProp D

		SET @Req = replace(@Req,'ADD@,','ADD ')

		--print @req

		exec ( @req)

		--select * from TmpIndivExport

		SET @ReqSet = 'SET@'
		SET @ReqFrom =''

		SELECT @ReqSet = @ReqSet + ',' + replace(P.Name,' ','_') + '=V.' + replace(P.Name,' ','_'), @ReqFrom = @ReqFrom + ',MAX(CASE WHEN Name=''' +  replace(P.Name,' ','_') + ''' THEN Value' + replace(P.TypeProp,'Integer','Int') + ' ELSE NULL END) ' + replace(P.Name,' ','_')																						
		from [EcoReleve_ECWP].dbo.SensorDynProp P

		SET @ReqSet = replace(@ReqSet,'SET@,','SET ')

		SET @Req = 'UPDATE EI ' + @ReqSet +  ' FROM TmpSensorExport EI JOIN (SELECT VN.FK_Sensor ' + @ReqFrom + ' FROM   [EcoReleve_ECWP].dbo.SensorDynPropValuesNow VN GROUP BY VN.FK_Sensor) V ON EI.ID = V.FK_Sensor '
		exec ( @req)
	END

	IF object_id('TSensor') IS NOT NULL DROP TABLE  TSensor
	
	exec sp_rename 'TmpSensorExport','TSensor'
END








GO
/****** Object:  StoredProcedure [dbo].[pr_ExportAllStation]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[pr_ExportAllStation] 
AS
BEGIN


	IF object_id('TmpStationExport') IS NOT NULL
			DROP TABLE TmpStationExport



	select * into TmpStationExport 
	from [EcoReleve_ECWP].dbo.Station

	--select * from TmpIndivExport
	DECLARE @Req NVARCHAR(MAX)
	DECLARE @ReqFrom NVARCHAR(MAX)
	DECLARE @ReqSet NVARCHAR(MAX)
	IF EXISTS (SELECT * from [EcoReleve_ECWP].dbo.StationDynProp)
	BEGIN
		SET @Req = ' ALTER TABLE TmpStationExport ADD@'

		select @Req = @Req + ',    ' +  replace(D.Name,' ','_') + ' ' + replace(replace(d.typeProp,'Integer','INT'),'string','varchar(255)')  from [EcoReleve_ECWP].dbo.StationDynProp D

		SET @Req = replace(@Req,'ADD@,','ADD ')

		--print @req

		exec ( @req)

		--select * from TmpIndivExport

		SET @ReqSet = 'SET@'
		SET @ReqFrom =''

		SELECT @ReqSet = @ReqSet + ',' + replace(P.Name,' ','_') + '=V.' + replace(P.Name,' ','_'), @ReqFrom = @ReqFrom + ',MAX(CASE WHEN Name=''' +  replace(P.Name,' ','_') + ''' THEN Value' + replace(P.TypeProp,'Integer','Int') + ' ELSE NULL END) ' + replace(P.Name,' ','_')																						
		from [EcoReleve_ECWP].dbo.StationDynProp P

		SET @ReqSet = replace(@ReqSet,'SET@,','SET ')

		SET @Req = 'UPDATE EI ' + @ReqSet +  ' FROM TmpStationExport EI JOIN (SELECT VN.FK_Station ' + @ReqFrom + ' FROM   [EcoReleve_ECWP].dbo.StationDynPropValuesNow VN GROUP BY VN.FK_Station) V ON EI.ID = V.FK_Station '
		exec ( @req)
	END

	IF object_id('TStation') IS NOT NULL DROP TABLE  TStation
	
	exec sp_rename 'TmpStationExport','TStation'
END








GO
/****** Object:  StoredProcedure [dbo].[pr_ExportFirstStation]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[pr_ExportFirstStation] 
AS
BEGIN

	IF OBJECT_ID('TmpTIndividualFirstStation') IS NOT NULL
		DROP TABLE TmpTIndividualFirstStation

	
select FK_Individual,FirstStation_ID,FK_Sensor_FirstStation,Protocol_Release_Individual_ID,Release_Individual_Station_ID,Protocol_Capture_Individual_ID,Capture_Individual_Station_ID
INTO TmpTIndividualFirstStation
FROM
	(
	SELECT	i.ID FK_Individual
				, CASE WHEN isnull(s.StationDate,getdate()) <= isnull(sc.StationDate,getdate()) THEN s.ID 
					ELSE isnull(sc.id,s.id) END FirstStation_ID
				, e.FK_Sensor FK_Sensor_FirstStation
				, R.ID Protocol_Release_Individual_ID, S.ID Release_Individual_Station_ID
				, c.ID Protocol_Capture_Individual_ID, sc.ID Capture_Individual_Station_ID
		, row_number() over ( PARTITION BY i.id order by s.stationdate,sc.stationdate ,e.startdate , e.id  ) nb
		FROM TIndividu I 
		LEFT JOIN [dbo].[TProtocol_Release_Individual] R 
			ON r.FK_Individual = i.ID 
		LEFT JOIN TStation S 
			ON r.FK_Station = S.ID
		LEFT JOIN [dbo].[TProtocol_Capture_individual] C 
			ON C.FK_Individual = i.ID 
		LEFT JOIN TStation SC 
			ON C.FK_Station = Sc.ID
		LEFT JOIN VIndividuEquipementHisto e
			ON  e.StartDate <= ISNULL(s.stationdate,sc.stationdate)  AND E.fk_individual = i.id and e.deploy=1
			) F where F.nb =1

END


GO
/****** Object:  StoredProcedure [dbo].[pr_ExportIndividualLastLocationAllSource]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[pr_ExportIndividualLastLocationAllSource]
AS
BEGIN

IF OBJECT_ID('tmpIndividualLastLocationAllSource') IS NOT NULL
		DROP TABLE tmpIndividualLastLocationAllSource
SELECT S.*,E.FK_Sensor INTO tmpIndividualLastLocationAllSource
FROM
	(
	SELECT L.FK_Individual
	,CASE WHEN L.Date > S.StationDate THEN L.DATE ELSE S.StationDate END  LocalisationDate
	,CASE WHEN L.Date > S.StationDate THEN L.LAT ELSE S.LAT END  LAT
	,CASE WHEN L.Date > S.StationDate THEN L.LON ELSE S.LON END  LON
	,CASE WHEN L.Date > S.StationDate THEN L.ELE ELSE S.ELE END  ELE
	,CASE WHEN L.Date > S.StationDate THEN NULL ELSE L.fk_station END  fk_station 
	,CASE WHEN L.Date > S.StationDate THEN L.ID ELSE NULL END  fk_individualLocation
	,CASE WHEN L.Date > S.StationDate THEN L.type_ ELSE PT.Name END  SOURCE
	FROM (
		SELECT DISTINCT LS.*, Os.ID fk_station, Os.FK_ProtocoleType 
		FROM TIndividualLastLocationSensor LS
		JOIN (SELECT S.ID,O.FK_Individual,O.FK_ProtocoleType 
			 , ROW_NUMBER() OVER (PARTITION by FK_Individual ORDER BY FK_Individual,S.stationdate DESC) nb 
			 FROM [EcoReleve_ECWP].dbo.Observation O 
			 JOIN [EcoReleve_ECWP].dbo.Station S 
				ON O.FK_Station = S.ID 
			 WHERE O.FK_ProtocoleType NOT IN 
					(SELECT id 
					 FROM [EcoReleve_ECWP].dbo.ProtocoleType 
					 WHERE name  IN ('Nest description', 'Bird Biometry'))	
			 ) Os 
			ON Os.fk_individual=LS.fk_individual AND Os.nb=1
		UNION ALL
		SELECT LS.*, NULL fk_station, NULL FK_ProtocoleType 
		FROM TIndividualLastLocationSensor LS
		WHERE NOT EXISTS (	SELECT * 
							FROM [EcoReleve_ECWP].dbo.Observation o 
							WHERE O.FK_Individual = LS.FK_Individual  
							AND O.FK_ProtocoleType NOT IN (	SELECT id 
															FROM [EcoReleve_ECWP].dbo.ProtocoleType 
															WHERE name IN ('Nest description'))	 )
	) L 
	LEFT JOIN TStation S 
		ON S.ID = L.fk_station 
	LEFT JOIN [EcoReleve_ECWP].dbo.ProtocoleType PT 
		ON l.FK_ProtocoleType = PT.ID
) S 
LEFT JOIN VIndividuEquipementHisto E 
	ON  E.StartDate <= S.LocalisationDate  AND E.fk_individual = S.FK_Individual AND E.Deploy =1 
	AND NOT EXISTS (SELECT * 
					FROM VIndividuEquipementHisto E2 
					WHERE E2.FK_Individual = E.FK_Individual AND E2.StartDate > E.StartDate)

	IF object_id('TIndividualLastLocationAllSource') IS NOT NULL 
		DROP TABLE  TIndividualLastLocationAllSource
	EXEC sp_rename 'tmpIndividualLastLocationAllSource','TIndividualLastLocationAllSource'

END






GO
/****** Object:  StoredProcedure [dbo].[pr_ExportIndividualLastLocationSensor]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[pr_ExportIndividualLastLocationSensor]
AS
BEGIN

IF OBJECT_ID('tmpIndividualLastLocationSensor') IS NOT NULL
		DROP TABLE tmpIndividualLastLocationSensor
select * into tmpIndividualLastLocationSensor
FROM
	(
	select IL.[ID]
		  ,IL.[LAT]
		  ,IL.[LON]
		  ,IL.[ELE]
		  ,IL.[Date]
		  ,IL.[Precision]
		  ,IL.[FK_Sensor]
		  ,I.ID [FK_Individual]
		  ,IL.[creator]
		  ,IL.[creationDate]
		  ,IL.[type_]
		  ,IL.[OriginalData_ID]
	from TIndividu I 
	JOIN (select Il.*,ROW_NUMBER() OVER (PARTITION by FK_Individual,[date] order by FK_Individual,[date] DESC) Nb from [EcoReleve_ECWP].dbo.Individual_Location IL) IL ON IL.FK_Individual = I.ID and Il.Nb =1 
	and not exists (select * from [EcoReleve_ECWP].dbo.Individual_Location IL2 where IL2.FK_Individual = IL.FK_Individual and il2.Date > il.Date)
	union all 
	select NULL [ID]
		  ,NULL [LAT]
		  ,NULL [LON]
		  ,NULL [ELE]
		  ,NULL [Date]
		  ,NULL [Precision]
		  ,NULL [FK_Sensor]
		  ,I.ID [FK_Individual]
		  ,NULL [creator]
		  ,NULL [creationDate]
		  ,NULL [type_]
		  ,NULL [OriginalData_ID]
	from TIndividu I 
	Where not exists (select * from [EcoReleve_ECWP].dbo.Individual_Location IL where IL.FK_Individual = I.ID )
	) S

	IF object_id('TIndividualLastLocationSensor') IS NOT NULL 
		DROP TABLE  TIndividualLastLocationSensor
	exec sp_rename 'tmpIndividualLastLocationSensor','TIndividualLastLocationSensor'

END




GO
/****** Object:  StoredProcedure [dbo].[pr_ExportObservationDynPropValueNow]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[pr_ExportObservationDynPropValueNow] 
	
AS
BEGIN
	IF NOT EXISTS (SELECT * FROM TImportInfo I WHERE I.ImportInfoName = 'ExportObservationDynPropValueNow' and convert(datetime,I.ImportInfoValue,121) > getdate()-0.1)
	BEGIN
		IF EXISTS (select * from sysobjects where name='TObservationDynPropValueNow' and type='U')
			DROP TABLE TObservationDynPropValueNow

		CREATE TABLE [dbo].[TObservationDynPropValueNow](
			[ID] [int] NOT NULL,
			[StartDate] [datetime] NOT NULL,
			[ValueInt] [int] NULL,
			[ValueString] [varchar](max) NULL,
			[ValueDate] [datetime] NULL,
			[ValueFloat] [float] NULL,
			[FK_ObservationDynProp] [int] NULL,
			[FK_Observation] [int] NULL,
			[Name] [nvarchar](250) NOT NULL,
			[TypeProp] [nvarchar](250) NOT NULL
		) 


		
		
		INSERT INTO [dbo].[TObservationDynPropValueNow]
           ([ID]
           ,[StartDate]
           ,[ValueInt]
           ,[ValueString]
           ,[ValueDate]
           ,[ValueFloat]
           ,[FK_ObservationDynProp]
           ,[FK_Observation]
           ,[Name]
           ,[TypeProp])
		SELECT * FROM [EcoReleve_ECWP].dbo.ObservationDynPropValuesNow WITH(NOLOCK)
		
		CREATE CLUSTERED INDEX [IX_TObservationDynPropValue_Fk_Observation_autres] ON [dbo].TObservationDynPropValueNow
				(
					[FK_Observation] ,
					[FK_ObservationDynProp] 
				)

		INSERT INTO [dbo].[TImportInfo]
           ([ImportInfoName]
           ,[ImportInfoValue])
		   VALUES ('ExportObservationDynPropValueNow',convert(varchar,getdate(),121)) 
	END
END





GO
/****** Object:  StoredProcedure [dbo].[pr_ExportOneProtocole]    Script Date: 24/03/2016 09:53:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[pr_ExportOneProtocole] 
	(
	@ProtocoleType INT
	)
AS
BEGIN

	IF object_id('TmpObsExport') IS NOT NULL
			DROP TABLE TmpObsExport


	DECLARE @ProtocoleName VARCHAR(255)


	SELECT @ProtocoleName = Name from [EcoReleve_ECWP].dbo.ProtocoleType where id=@ProtocoleType
	print 'Export ' + @ProtocoleName

	---------------------- CREATION DE LA TABLE CIBLE

	-- Ges Static Prop
	select O.* into TmpObsExport 
	from [EcoReleve_ECWP].dbo.Observation O
	where O.FK_ProtocoleType = @ProtocoleType
	
	exec pr_ExportObservationDynPropValueNow
	
	
	DECLARE @Req NVARCHAR(MAX)
	DECLARE @ReqFrom NVARCHAR(MAX)
	DECLARE @ReqSet NVARCHAR(MAX)
	SET @Req = ' CREATE UNIQUE CLUSTERED INDEX PK_TProtocol'  +  replace(@ProtocoleName,' ','_') + ' ON TmpObsExport (ID)' 
	exec ( @req)
	IF EXISTS (select * from [EcoReleve_ECWP].dbo.ObservationDynProp D JOIN [EcoReleve_ECWP].dbo.ProtocoleType_ObservationDynProp C ON C.FK_ProtocoleType = @ProtocoleType and c.FK_ObservationDynProp =D.ID )
	BEGIN
		-- ALTER WITH DYN PROPS
		SET @Req = ' ALTER TABLE TmpObsExport ADD@'

		select @Req = @Req + ',    ' +  replace(D.Name,' ','_') + ' ' 
		+  (select CASE WHEN d.typeProp = 'Integer' THEN 'INT'
			WHEN d.typeProp = 'string' THEN 'varchar(255)'
			WHEN d.typeProp = 'date' THEN 'datetime'
			WHEN d.typeProp = 'Date Only' THEN 'date'
			WHEN d.typeProp = 'Float' THEN 'decimal (12,5)'
			WHEN d.typeProp = 'Time' THEN 'time'
			ELSE d.typeProp END)--replace(replace(replace(replace(d.typeProp,'Integer','INT'),'string','varchar(255)'),'date','datetime'),'Date Only','date')  
		from [EcoReleve_ECWP].dbo.ObservationDynProp D JOIN [EcoReleve_ECWP].dbo.ProtocoleType_ObservationDynProp C ON C.FK_ProtocoleType = @ProtocoleType and c.FK_ObservationDynProp =D.ID

		SET @Req = replace(@Req,'ADD@,','ADD ')
		print @Req
		exec ( @req)
	

		IF EXISTS(SELECT * from TmpObsExport)
		BEGIN
			-- UPDATE DATA FROM DYN PROP

			SET @ReqSet = 'SET@'
			SET @ReqFrom =''


			SELECT @ReqSet = @ReqSet + ',' + replace(P.Name,' ','_') + '=(select Value' +  
			(select CASE WHEN P.typeProp = 'Integer' THEN 'int'
			WHEN P.typeProp = 'Date Only' THEN 'Date'
			WHEN P.typeProp = 'Time' THEN 'Date'
			ELSE P.typeProp END)
			
			+ ' FROM   TObservationDynPropValueNow  where fk_observationdynprop=' + convert(varchar(10),P.ID) + ' and fk_observation = EI.ID)'
			--SELECT @ReqSet = @ReqSet + ',' + replace(P.Name,' ','_') + '=V.' + replace(P.Name,' ','_'), @ReqFrom = @ReqFrom + ',MAX(CASE WHEN Name=''' +  replace(P.Name,' ','_') + ''' THEN Value' + replace(P.TypeProp,'Integer','Int') + ' ELSE NULL END) ' + replace(P.Name,' ','_')
			from [EcoReleve_ECWP].dbo.ObservationDynProp P JOIN [EcoReleve_ECWP].dbo.ProtocoleType_ObservationDynProp C ON C.FK_ProtocoleType = @ProtocoleType and c.FK_ObservationDynProp =P.ID 


			SET @ReqSet = replace(@ReqSet,'SET@,','SET ')
			SET @Req = 'UPDATE EI ' + @ReqSet +  ' FROM TmpObsExport EI '



			--SELECT @ReqSet = @ReqSet + ',' + replace(P.Name,' ','_') + '=V.' + replace(P.Name,' ','_'), @ReqFrom = @ReqFrom + ',MAX(CASE WHEN Name=''' +  replace(P.Name,' ','_') + ''' THEN Value' + replace(P.TypeProp,'Integer','Int') + ' ELSE NULL END) ' + replace(P.Name,' ','_')																						
			--from [EcoReleve_ECWP].dbo.ObservationDynProp P JOIN [EcoReleve_ECWP].dbo.ProtocoleType_ObservationDynProp C ON C.FK_ProtocoleType = @ProtocoleType and c.FK_ObservationDynProp =P.ID 


			--SET @ReqSet = replace(@ReqSet,'SET@,','SET ')
			--print @ReqFrom

			--SET @Req = 'UPDATE EI ' + @ReqSet +  ' FROM TmpObsExport EI JOIN (SELECT VN.FK_Observation ' + @ReqFrom + ' FROM   [EcoReleve_ECWP].dbo.ObservationDynPropValuesNow VN GROUP BY VN.FK_Observation) V ON EI.ID = V.FK_Observation '

			--SET @Req = 'SELECT * FROM TmpIndivExport EI JOIN (SELECT VN.FK_Individual ' + @ReqFrom + ' FROM   [EcoReleve_ECWP].dbo.IndividualDynPropValuesNow VN GROUP BY VN.FK_Individual) V ON EI.ID = V.FK_Individual '

			print @req

			exec ( @req)
		END	
	END
	SET @Req = ' IF object_id(''TProtocol_'  +  replace(@ProtocoleName,' ','_') + ''') IS NOT NULL DROP TABLE  TProtocol_'  +  replace(@ProtocoleName,' ','_')
	exec ( @req)
	SET @Req = ' sp_rename ''TmpObsExport'' ,TProtocol_'  +  replace(@ProtocoleName,' ','_')

	exec ( @req)

END











GO
