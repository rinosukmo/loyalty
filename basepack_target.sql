USE [uli_loyalty]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[create_outlet_basepack_target] 
AS
BEGIN


DROP TABLE IF EXISTS #DISTI1
SELECT A.outlet_id, 
	   A.invoice_no,
	   YEAR(A.invoice_date) invoice_year,  
	   MONTH(A.invoice_date) invoice_month, 
	   A.invoice_date,
	   B.basepack,
	   A.quantity,
	   A.total
INTO	#DISTI1
FROM [uli_loyalty].[dbo].invoice_detail_activity A
INNER JOIN [uli_loyalty].[dbo].master_products_basepack_new  B  --mulai oktober 2023
ON A.item_code = B.sku_code
WHERE A.invoice_date >= '2025-01-01'



DROP TABLE IF EXISTS #DISTI2
SELECT  AA.activity_id
	   ,AA.outlet_id
	   ,AA.cluster
	   ,SUM(CAST(BB.amount_c as numeric)) as total_sales_temp
	   ,ISNULL( CASE WHEN AA.cluster = '1' THEN FLOOR(CAST(SUM(CAST(BB.amount_c as numeric))*(0.004)/4000 as numeric(18,4))) ELSE
		CASE WHEN AA.cluster = '2' THEN FLOOR(CAST(SUM(CAST(BB.amount_c as numeric))*(0.004)/4000 as numeric(18,4))) ELSE
		CASE WHEN AA.cluster = '3' THEN FLOOR(CAST(SUM(CAST(BB.amount_c as numeric))*(0.004)/4000 as numeric(18,4))) ELSE 0
		END END END,0) [Aktual_Point_temp]
INTO	#DISTI2
FROM [uli_loyalty].[dbo].outlet_basepack_target_master AA
LEFT OUTER JOIN (	SELECT	im.outlet_id, invoice_date,
					SUM(im.invoice_amount) as amount_c
					FROM	[uli_loyalty].dbo.invoice_master as im
					GROUP BY im.outlet_id, im.invoice_date ) as BB
					ON AA.outlet_id=BB.outlet_id
					AND AA.periode_start <= BB.invoice_date
					AND AA.periode_end >= BB.invoice_date
					WHERE BB.invoice_date >= '2025-01-01'
					GROUP BY AA.activity_id, AA.outlet_id, AA.cluster


---- Basepack Detail ----
		

DROP TABLE IF EXISTS [uli_loyalty].[dbo].[Basepack_Outlet_Detail]
SELECT	X.activity_id, C.REGION, 
		C.AREA, X.dist_code [KODE DISTI], 
		X.outlet_id [KODE TOKO], 
		X.BASEPACK_TITLE,
		X.TARGET, 
		SUM(ISNULL(Y.QUANTITY, 0)) QUANTITY, 
		ISNULL(SUM(CAST(Y.TOTAL as numeric(18,0))),0) [VALUE],
		CASE WHEN ISNULL(X.TARGET, 0) - SUM(ISNULL(Y.QUANTITY, 0)) <= 0 THEN 1 ELSE 0 END [PENCAPAIAN],
		CASE WHEN ISNULL(X.TARGET, 0) - SUM(ISNULL(Y.QUANTITY, 0)) <= 0 THEN 0 
			 ELSE ISNULL(X.TARGET, 0) - SUM(ISNULL(Y.QUANTITY, 0))
		END [SISA_TARGET]
		,YEAR(X.periode_start) as [YEAR]
		,MONTH(X.periode_start) as [MONTH]
		,D.status_id
		,D.status_approval

INTO	[uli_loyalty].[dbo].[Basepack_Outlet_Detail] -- result1
FROM	[uli_loyalty].[dbo].outlet_basepack_target_detail X -- Subject1
		LEFT OUTER JOIN #DISTI1  Y
		ON
				X.outlet_id = Y.outlet_id
				AND X.basepack_title = Y.basepack
				AND X.periode_start <= Y.invoice_date
				AND X.periode_end >= Y.invoice_date
				AND X.[status] = 'Y'
		LEFT OUTER JOIN (SELECT REGION, AREA, [KODE TOKO] 
					FROM [uli_loyalty].dbo.temp_master_data_uli
					GROUP BY REGION, AREA, [KODE TOKO]) C
			ON X.outlet_id = C.[KODE TOKO]
		LEFT JOIN [uli_loyalty].[dbo].activities_regular D ON X.activity_id=D.activity_id

WHERE	X.[status] = 'Y'
		AND X.status_id != '3'
		AND X.periode_start >= '2035-01-01'
GROUP BY  X.activity_id, REGION, AREA, X.outlet_id , X.basepack_title, X.[target], D.status_id, X.periode_start, X.dist_code, 
		  D.status_id, D.status_approval

---- Basepack Summary ----


DROP TABLE IF EXISTS [uli_loyalty].[dbo].[Basepack_Outlet_Summary] 
SELECT A.activity_id,
	   DD.REGION,
	   DD.AREA,
	   DD.[KODE DISTI],
	   A.outlet_id [KODE TOKO],
	   A.total_basepack [TOTAL_BASEPACK],
	   A.[target] [TARGET],
	   SUM(DD.PENCAPAIAN) [PENCAPAIAN],
	   CASE	WHEN ISNULL(A.TARGET, 0) - SUM(ISNULL(DD.PENCAPAIAN, 0)) <= 0 
					THEN 0 
					ELSE ISNULL(A.TARGET, 0) - SUM(ISNULL(DD.PENCAPAIAN, 0)) 
		END SISA_TARGET,
		'Rp.' as [isValue],
		CAST(ISNULL(EE.total_sales_temp,0) as numeric(18,0)) as Total_Sales,

		A.point_min,
		A.point_max,
		grw.status_achievment [Status_Target_Growth],

		CASE WHEN grw.status_achievment = 'NA' THEN '0'
			 WHEN SUM(DD.PENCAPAIAN) < A.[target] THEN '0'
			 WHEN SUM(DD.PENCAPAIAN) >= A.[target] AND EE.Aktual_Point_temp < A.point_min THEN '0'
			 WHEN SUM(DD.PENCAPAIAN) >= A.[target] AND EE.Aktual_Point_temp >= A.point_max THEN A.point_max		 
			 ELSE EE.Aktual_Point_temp END [Aktual_Point],  -- mulai juli 2024

		-- -- new condition -- --

		 CASE WHEN MAX(inm.invoice_no) is NULL THEN '-' ELSE MAX(inm.invoice_no) END [Injection Code]
		,CASE WHEN inm.upload_date is NULL THEN '-' ELSE CAST(FORMAT(inm.upload_date , 'dd MMM yyyy') as VARCHAR) END [Injection Date]
		,ISNULL(CAST(inm.expected_invoice_addt_reward as numeric),0) [Point Injected]
		,ISNULL(CAST(inm.expected_invoice_addt_reward as numeric)*4000,0) [Budget Utilized Initital]
		,ISNULL(CAST(fbinv.expected_invoice_addt_reward as numeric),0) [Gap Point Injected]
 		,ISNULL(CAST(inm.expected_invoice_addt_reward as numeric),0) + ISNULL(CAST(fbinv.expected_invoice_addt_reward as numeric),0) [Final Point Injected]
		,(ISNULL(CAST(inm.expected_invoice_addt_reward as numeric),0) + ISNULL(CAST(fbinv.expected_invoice_addt_reward as numeric),0))*4000 [Budget Utilized Final]
		,CASE WHEN fbinv.payment_amount is NULL THEN '0' ELSE CAST(fbinv.payment_amount as numeric) END [Feedback Ach sales]
		,CASE WHEN MAX(fbinv.invoice_no) is NULL THEN '-' ELSE MAX(fbinv.invoice_no) END [Feedback Injection Code]
		,CASE WHEN MAX(fbinv.invoice_no) is NULL THEN '-' ELSE 'Approved' END [Feedback Remark]
		,ISNULL(CAST(fbinv.expected_invoice_addt_reward as numeric),0) [Feedback Point]
		,ISNULL(CAST(fbinv.expected_invoice_addt_reward as numeric),0)  [Gap]
		,ISNULL(CAST(inm.expected_invoice_addt_reward as numeric),0) + ISNULL(CAST(fbinv.expected_invoice_addt_reward as numeric),0) [Final Point],

		YEAR(A.periode_start) as [YEAR],
		MONTH(A.periode_start) as [MONTH],
		FF.status_id,
		FF.status_approval

INTO	[uli_loyalty].[dbo].[Basepack_Outlet_Summary] 	   	
FROM	[uli_loyalty].[dbo].outlet_basepack_target_master A
LEFT OUTER JOIN [uli_loyalty].[dbo].[Basepack_Outlet_Detail] DD
		ON A.activity_id=DD.activity_id and A.outlet_id=DD.[KODE TOKO]

		LEFT OUTER JOIN #DISTI2 EE ON A.activity_id=EE.activity_id and A.outlet_id=EE.outlet_id
		LEFT JOIN [uli_loyalty].[dbo].activities_regular FF ON A.activity_id=FF.activity_id

			-- ini baru-- 
			LEFT JOIN (SELECT invoice_no , invoice_date, outlet_id, document_ID, expected_invoice_addt_reward, sales_id, upload_date
				FROM [uli_loyalty].[dbo].invoice_master
				WHERE sales_id = '0')
				inm ON A.outlet_id=inm.outlet_id and A.activity_id=inm.document_ID

			LEFT JOIN (SELECT invoice_no , invoice_date, outlet_id, document_ID, expected_invoice_addt_reward, sales_id, payment_amount
				FROM [uli_loyalty].[dbo].invoice_master
				WHERE sales_id = '1')
				fbinv ON A.outlet_id=fbinv.outlet_id and A.activity_id=fbinv.document_ID

LEFT JOIN [uli_loyalty].[dbo].[achievement_growth_new] grw ON A.periode_start=grw.periode_start AND A.periode_end=grw.periode_end AND A.outlet_id=grw.outlet_code

		WHERE A.periode_start >= '2025-01-01'

GROUP BY A.activity_id, A.outlet_id, A.total_basepack, A.[target], EE.total_sales_temp, EE.Aktual_Point_temp, A.periode_start, A.status_id,
		DD.REGION, DD.AREA, DD.[KODE DISTI], FF.status_id, FF.status_approval, inm.invoice_no, inm.upload_date, inm.invoice_date, inm.expected_invoice_addt_reward,
		fbinv.payment_amount, fbinv.expected_invoice_addt_reward, fbinv.invoice_no, A.point_min, A.point_max, grw.status_achievment


 -- -- On Apps Click Detail -- -- 

DROP TABLE IF EXISTS [uli_loyalty].[dbo].[invoice_detail_distribution_2023]
SELECT AU.activity_id, AD.[outlet_id], AD.invoice_no, AD.item_code, CAST(AD.[price] as numeric) as Harga, AD.quantity, 'Rp.' as [isValue], CAST(AD.[total] as numeric) as Total, AD.invoice_date
INTO [uli_loyalty].[dbo].[invoice_detail_distribution_2023]
FROM [uli_loyalty].[dbo].invoice_detail_activity AD
LEFT OUTER JOIN [uli_loyalty].[dbo].outlet_basepack_target_detail  AU
ON AD.outlet_id=AU.outlet_id
WHERE AU.periode_start <= AD.invoice_date
	  AND AU.periode_end >= AD.invoice_date
GROUP BY AU.activity_id, AD.[outlet_id], AD.invoice_no, AD.item_code, AD.[price], AD.quantity, AD.[total], AD.invoice_date


END


/*

Basepack Target Achievement

*/