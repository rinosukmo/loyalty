USE [uli_loyalty]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[achievement_growth_sp] 
AS
BEGIN


DROP TABLE IF EXISTS #GROWTH1
SELECT A.activity_id
	   ,A.Outlet_id
       ,A.Cluster
	   ,SUM(CAST(B.amount_c as numeric)) as pencapaian
	   ,ISNULL( CASE WHEN A.Cluster = '1' THEN CAST(SUM(CAST(B.amount_c as numeric))*0.005/4000 as numeric(18,0)) ELSE
		CASE WHEN A.Cluster = '2' THEN CAST(SUM(CAST(B.amount_c as numeric))*0.005/4000 as numeric(18,0)) ELSE
		CASE WHEN A.Cluster = '3' THEN CAST(SUM(CAST(B.amount_c as numeric))*0.005/4000 as numeric(18,0)) ELSE '-'
		END END END,0) point_temp
INTO	#GROWTH1
FROM    [uli_loyalty].dbo.[target_growth] A
LEFT OUTER JOIN (	SELECT	im.outlet_id, invoice_date,
					SUM(im.invoice_amount) as amount_c
					FROM	[uli_loyalty].dbo.invoice_master as im
					GROUP BY im.outlet_id, im.invoice_date ) as B
					ON A.Outlet_id=B.outlet_id 
					   AND A.periode_start <= CAST(B.invoice_date as date)
					   AND A.periode_end >= CAST(B.invoice_date as date)

WHERE A.periode_start >= '2025-01-01'
GROUP BY A.activity_id, A.Outlet_id, A.Cluster


DROP TABLE IF EXISTS [uli_loyalty].[dbo].[achievement_growth_new]
SELECT	0 Bar_seq
					,tc.activity_id
					, tc.Dist_Code
					, tc.Outlet_id as outlet_code
					, tc.outlet_name as nama_toko
					, tc.Bar_Title_Target --> #1 Title 
					,'Target Growth' Bar_Target 
					,'Rp.' as [isValue]
					,CAST(tc.Target_toko as numeric(18,0)) as rpp_target --Line Target 
					,'Total Sales' Bar_Title_Capai
					,CAST(ISNULL(A.pencapaian,0) as numeric(18,0)) as rpp_capai -- Line Pencapaian 
					,'Sisa Target' Bar_Title_Sisa

					,CASE WHEN CAST(tc.Target_toko as numeric(18,0))-CAST(ISNULL(A.pencapaian,0) as numeric(18,0)) <= '0' THEN '0' ELSE
					 CASE WHEN CAST(ISNULL(A.pencapaian,0) as numeric(18,0)) <= '0' THEN CAST(tc.Target_toko as numeric(18,0)) ELSE
					 CAST(tc.Target_toko as numeric(18,0))-CAST(ISNULL(A.pencapaian,0) as numeric(18,0)) END END as rpp_sisa

					,'Point Minimal' Bar_Title_Simulasi
					,ISNULL(tc.[POINT_didapat],0) as rpp_simulasi --Line Point minmal
					
					,'Point Maksimal' Bar_Title_Simulasi_max
					,ISNULL(tc.[POINT_max],0) as rpp_simulasi_max --Line Point maksimal

					,'Simulasi Aktual Point' Bar_Title_Aktual_Point

					  ,CASE WHEN A.pencapaian < tc.Target_Toko THEN 0
							WHEN A.point_temp < tc.POINT_didapat THEN 0 
					        WHEN A.point_temp >= tc.[POINT_max] THEN ISNULL(tc.[POINT_max],0) -- -- point max 
							ELSE  A.point_temp
					   END rpp_aktual_point
	
					,0 as flag

					,CASE WHEN tc.Cluster = '1' THEN 'Small' ELSE
					 CASE WHEN tc.Cluster = '2' THEN 'Medium' ELSE
					 CASE WHEN tc.Cluster = '3' THEN 'Big' ELSE '-' END END END [cluster]

					,tc.periode_start
					,tc.periode_end
					,YEAR(tc.periode_start) as [Year]
					,MONTH(tc.periode_start)  as [Month]

				    ,CASE WHEN MAX(inm.invoice_no) is NULL THEN '-' ELSE MAX(inm.invoice_no) END [Injection Code]
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
				    ,ISNULL(CAST(inm.expected_invoice_addt_reward as numeric),0) + ISNULL(CAST(fbinv.expected_invoice_addt_reward as numeric),0) [Final Point]

					,B.status_id
					,B.status_approval
					,CASE WHEN A.pencapaian >= tc.Target_Toko THEN 'A' ELSE 'NA' END [status_achievment]
					,CONVERT(datetime, GETDATE()) as update_date
			INTO [uli_loyalty].[dbo].[achievement_growth_new]
			FROM	[uli_loyalty].dbo.[target_growth] tc --> #2 master outlet 

			LEFT JOIN #GROWTH1 A ON tc.activity_id=A.activity_id and tc.Outlet_id=A.Outlet_id
			LEFT JOIN [uli_loyalty].[dbo].activities_regular B ON tc.activity_id=B.activity_id

			LEFT JOIN (SELECT invoice_no , invoice_date, outlet_id, document_ID, expected_invoice_addt_reward, sales_id, upload_date
				FROM [uli_loyalty].[dbo].invoice_master
				WHERE sales_id = '0')
				inm ON tc.Outlet_id=inm.outlet_id and A.activity_id=inm.document_ID

			LEFT JOIN (SELECT invoice_no , invoice_date, outlet_id, document_ID, expected_invoice_addt_reward, sales_id, payment_amount
				FROM [uli_loyalty].[dbo].invoice_master
				WHERE sales_id = '1')
				fbinv ON tc.Outlet_id=fbinv.outlet_id and A.activity_id=fbinv.document_ID
			
			WHERE tc.periode_start >= '2025-01-01'

			GROUP BY tc.activity_id
					 ,tc.Dist_Code
					 ,tc.Outlet_id 
					 ,tc.outlet_name 
					 ,tc.Bar_Title_Target
					 ,tc.Target_toko 
					 ,A.pencapaian
					 ,tc.[POINT_didapat]
					 ,tc.[POINT_max]
					 ,A.point_temp 
					 ,tc.Cluster
					 ,tc.periode_start
					 ,tc.periode_end
					 ,inm.invoice_date
					 ,inm.upload_date
					 ,inm.expected_invoice_addt_reward
					 ,fbinv.expected_invoice_addt_reward
					 ,fbinv.payment_amount
					 ,fbinv.invoice_no
					 ,fbinv.expected_invoice_addt_reward
					 ,B.status_id
					 ,B.status_approval

		
END

/*

Growth Target

*/

