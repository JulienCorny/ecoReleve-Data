/****** Script de la commande SelectTopNRows à partir de SSMS  ******/


-- doublons ??
  --select *   FROM [NARC_eReleveData].[dbo].[TMonitoredStations] M
  --WHERE Name is  null
  --or  exists (select * from [NARC_eReleveData].[dbo].[TMonitoredStations] M2 where M2.TGeo_pk_id <> M.TGeo_pk_id and m2.Name = M.name)

SET IDENTITY_INSERT  [MonitoredSite] ON

INSERT INTO [MonitoredSite] (
	ID,
      [Name]
      ,[Category]
      ,[Creator]
      ,[Active]
      ,[creationDate]
      ,[FK_MonitoredSiteType]
	  ,Original_ID
)
SELECT 
		m.TGeo_pk_id
		,[Name]
	  ,[name_Type]
      ,isnull([Creator],'')
      ,[Active]
      ,isnull([Creation_date],convert(datetime,'01/01/1900',103))
	  ,1
	  ,[TGeo_pk_id]
  FROM [NARC_eReleveData].[dbo].[TMonitoredStations] M
  WHERE Name is not null
  and not exists (select * from [NARC_eReleveData].[dbo].[TMonitoredStations] M2 where M2.TGeo_pk_id <> M.TGeo_pk_id and m2.Name = M.name)

  

  SET IDENTITY_INSERT  [MonitoredSite] OFF

--INSERT INTO NewModelERD.[dbo].[MonitoredSiteDynPropValue] (
--Startdate,ValueDate,ValueInt,ValueFloat,ValueString,FK_MonitoredSiteDynProp,FK_MonitoredSite)

--SELECT
--Case WHEN [TGeoPos_Date] IS NOT NULL THEN [TGeoPos_Date] ELSE [TGeoPos_Begin_Date] END as StartDate,
--Case WHEN dyn.Name = 'StationDate' then p.[TGeoPos_Begin_Date] ELSE NULL END as ValueDate,
--Case 
--	WHEN dyn.Name = 'Elevation' and dyn.TypeProp = 'Integer' and p.[TGeoPos_ELE] IS NOT NULL THEN p.[TGeoPos_ELE]
--	WHEN dyn.Name = 'Creator' and dyn.TypeProp = 'Integer'  THEN 1
--	WHEN dyn.Name = 'Precision' and p.[TGeoPos_Precision] IS NOT NULL THEN p.[TGeoPos_Precision]
--	ELSE NULL
--	END as ValueInt,
--Case 
--	WHEN dyn.Name = 'LAT'  and p.[TGeoPos_LAT] IS NOT NULL THEN p.[TGeoPos_LAT]
--	WHEN dyn.Name = 'LON'   and p.[TGeoPos_LON] IS NOT NULL THEN p.[TGeoPos_LON]
--	ELSE NULL
--	END as ValueFloat,
--Case 
--	WHEN dyn.Name = 'Comments' and [TGeoPos_Comments] IS NOT NULL THEN p.[TGeoPos_Comments]
--	ELSE NULL
--	END as ValueString,
--dyn.ID,
--m.ID
--  FROM [NewModelERD].[dbo].[MonitoredSite] m
--  JOIN [ECWP_ecoReleveData].[dbo].[TMonitoredStations_Positions] p  ON m.OldID = p.TGeoPos_FK_TGeo_ID
--  JOIN [NewModelERD].[dbo].[MonitoredSiteType] t ON m.[FK_MonitoredSiteType] = t.ID
--  JOIN [NewModelERD].[dbo].[MonitoredSiteType_MonitoredSiteDynProp] dT ON dT.[FK_MonitoredSiteType] = t.ID
--  JOIN [NewModelERD].[dbo].[MonitoredSiteDynProp] dyn ON dyn.ID = dT.[FK_MonitoredSiteDynProp]




INSERT INTO [MonitoredSitePosition] (
Startdate,LAT,LON,ELE,Precision,Comments,FK_MonitoredSite)

SELECT distinct  p.TGeoPos_Begin_Date, p.TGeoPos_LAT,p.TGeoPos_LON,p.TGeoPos_ELE,p.TGeoPos_Precision,substring(p.TGeoPos_Comments,1,250) ,m.ID
  FROM [MonitoredSite] m
  JOIN [NARC_eReleveData].[dbo].[TMonitoredStations_Positions] p  ON m.ID = p.TGeoPos_FK_TGeo_ID

