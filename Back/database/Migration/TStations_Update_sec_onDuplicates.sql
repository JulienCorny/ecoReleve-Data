

update s set s.DATE = s.DATE+(0.00001*TSta_PK_ID)
select * 
from [ECWP-eReleveData].dbo.TStations S
     --LEFT JOIN fieldActivity FA on FA.Name = S.FieldActivity_Name 
     --jOIN StationType st ON  st.name = 'standard'
     -- LEFT JOIN Region R on r.Region = S.Region
    WHERe --NOT EXISTS (
				--select * from Station S2 
				--where S2.LAT = S.LAT AND S2.LON = S.LON AND s2.LAT = S.LAT 
				--and S.[DATE] = S2.StationDate) and 
     S.DATE IS NOT NULL AND S.FieldActivity_ID != 27
     AND  EXISTS (SELECT * FROM [ECWP-eReleveData].dbo.TStations S2 
			where S.TSta_PK_ID <> s2.TSta_PK_ID and isnull(S2.LAT,-1) =isnull(S.LAT,-1) 
			and isnull(S2.LON,-1) =isnull(S.LON,-1) and S.[DATE] = S2.[DATE] 
			AND S2.FieldActivity_ID != 27)

