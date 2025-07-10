USE [uli_loyalty]
GO
/****** Object:  StoredProcedure [dbo].[activity_inv_summary]    Script Date: 10/07/2025 10:26:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[activity_inv_summary]
AS
BEGIN

DROP TABLE IF EXISTS [uli_loyalty].[dbo].activity_summary_achievement

SELECT 
	   A.activity_id,
	   E.[quarter] [Periode],
	   D.[year],
	   B.category_name,
	   A.Region,
	   A.Area,
	   A.Dist_Code,
	   A.Dist_Name,
	   A.Outlet_id,
	   A.Outlet_Name,
	   A.Target_Toko [Target_Sales_Q1],
	   CASE WHEN C.rpp_capai is NULL THEN '0' ELSE C.rpp_capai END [Ach_Sales],
	   CASE WHEN A.Target_Toko - C.rpp_capai <= '0' THEN 'A' ELSE 'NA' END [Remark],
	   CAST(CEILING(A.VRR) AS NVARCHAR(10)) + '%' AS [VRR],
	   CASE WHEN A.Target_Toko - C.rpp_capai <= '0' THEN A.Simulasi_Point ELSE '0' END [Incentive_Target_Sales],

	   E.target_1 [One_Target_ECO],
	   E.achievement_1 [One_Actual_ECO],
	   CASE WHEN E.Remark_1 = '0' THEN 'NA' ELSE 'A' END [One_Remark_ECO],

	   E.target_2 [Two_Target_ECO],
	   E.achievement_2 [Two_Actual_ECO],
	   CASE WHEN E.Remark_2 = '0' THEN 'NA' ELSE 'A' END [Two_Remark_ECO],

	   E.target_3 [Tri_Target_ECO],
	   E.achievement_3 [Tri_Actual_ECO],
	   CASE WHEN E.Remark_3 = '0' THEN 'NA' ELSE 'A' END [Tri_Remark_ECO],

	   CASE WHEN E.Remark_ECO = '3' THEN 'A' ELSE 'NA' END [Remark_Q1_ECO],
	   CAST(A.VRR_Addt as varchar) +'%' [VRR_ECO],
	   CASE WHEN E.Remark_ECO = '3' THEN ROUND((A.Target_Toko * 0.02) / 4000, 0) ELSE '0' END [Incentive_Q1_ECO],

	   CASE WHEN A.Target_Toko - C.rpp_capai <= '0' AND E.Remark_1 = '1' AND E.Remark_2 = '1' AND E.Remark_3 = '1' THEN
	   A.Simulasi_Point + ROUND((A.Target_Toko * 0.02) / 4000, 0) ELSE 0 END [Total_Incentive]

INTO [uli_loyalty].[dbo].activity_summary_achievement

FROM [uli_loyalty].[dbo].temp_act_outlet_list A
LEFT JOIN (SELECT AA.activity_id, AA.category_id, BB.category_name, AA.periode_start, AA.periode_end, AA.mechanism_id, AA.status_activities
		   FROM [uli_loyalty].[dbo].activities AA
		   LEFT JOIN [uli_loyalty].[dbo].[ref_categories] BB ON AA.category_id=BB.category_id) B
		   ON A.activity_id=B.activity_id
LEFT JOIN [uli_loyalty].[dbo].live_mechanism_list C ON A.Outlet_id=C.outlet_code AND A.activity_id=C.activity_id
LEFT JOIN [uli_loyalty].[dbo].[temp_act_outlet_list_eco] D ON A.activity_id=D.activity_id AND A.Outlet_id=D.outlet_id 
LEFT JOIN [uli_loyalty].[dbo].activity_detail_inv_summary E ON A.Outlet_id=E.outlet_id AND A.activity_id=E.activity_id

WHERE B.mechanism_id = '2'
AND B.status_activities in ('14','15','16','31','30')
AND D.[quarter] = 'Q3'
AND D.[year] = '2025'


GROUP BY 
	   A.activity_id,
	   E.[quarter],
	   D.[year],
	   B.category_name,
	   A.Region,
	   A.Area,
	   A.Dist_Code,
	   A.Dist_Name,
	   A.Outlet_id,
	   A.Outlet_Name,
	   A.Target_Toko,
	   C.rpp_capai,
	   A.VRR,
	   A.Simulasi_Point,
	   E.target_1,
	   E.achievement_1,
	   E.Remark_1,
	   E.target_2,
	   E.achievement_2,
	   E.Remark_2,
	   E.target_3,
	   E.achievement_3,
	   E.Remark_3,
	   E.Remark_ECO,
	   D.vrr,
	   A.VRR_Addt 


END


