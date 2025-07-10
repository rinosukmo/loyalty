USE [uli_loyalty]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[activity_inv_detail]
AS
BEGIN

-- -- STEP I : Cari detail invoice

DROP TABLE IF EXISTS [uli_loyalty].[dbo].activity_detail_inv
	SELECT
		B.activity_id,
		E.[quarter],
		A.outlet_id, 
		C.sku_code,
		C.ispcs [target],
		SUM(A.quantity) AS total_qty,
		C.ispcs - SUM(A.quantity) [sisa_target],
		CASE WHEN C.ispcs - SUM(A.quantity) <= '0' THEN 'A' ELSE 'NA' END [status],
		CAST(SUM(A.total) as numeric) AS total_value,
		YEAR(A.invoice_date) AS invoice_year,  
		MONTH(A.invoice_date) AS invoice_month
INTO	[uli_loyalty].[dbo].activity_detail_inv
	FROM [uli_loyalty].[dbo].invoice_detail_activity A
	LEFT JOIN [uli_loyalty].[dbo].temp_act_outlet_list B ON A.outlet_id=B.Outlet_id
	RIGHT JOIN [uli_loyalty].[dbo].act_sku_eco C ON A.item_code=C.sku_code AND B.activity_id=C.activity_id
	LEFT JOIN [uli_loyalty].[dbo].activities D ON B.activity_id=D.activity_id 
	LEFT JOIN [uli_loyalty].[dbo].temp_act_outlet_list_eco E ON D.activity_id=E.activity_id

	WHERE D.mechanism_id = '2'
	AND D.status_activities in ('14','15','16','31','30')
	AND E.[quarter] = 'Q3'
	AND E.[year] = '2025'
	AND A.invoice_date >= D.periode_start
	AND A.invoice_date <= D.periode_end

GROUP BY B.activity_id, A.outlet_id, C.sku_code, YEAR(A.invoice_date), MONTH(A.invoice_date), C.ispcs, E.[quarter], E.[year]
ORDER by A.outlet_id

-- -- STEP II : Hitung Jumlah Achieve per outlet

DROP TABLE IF EXISTS #activity
SELECT 
    E1.activity_id,
	E1.[quarter],
    E1.outlet_id,
    E1.Achievement,
    E1.invoice_year,
    E1.invoice_month
INTO #activity
FROM (
    SELECT 
	    activity_id,
		[quarter],
        outlet_id,
        COUNT([status]) AS Achievement,
        invoice_year,
        invoice_month
    FROM [uli_loyalty].[dbo].activity_detail_inv
    WHERE [status] = 'A'
    GROUP BY activity_id, outlet_id, invoice_year, invoice_month, [quarter]
) E1

-- SELECT * FROM #activity



-- STEP III : detail

DROP TABLE IF EXISTS [uli_loyalty].[dbo].activity_detail_inv_achievement
SELECT
    activity_id,
	[quarter],
    outlet_id,

    CASE WHEN MAX(CASE WHEN invoice_month = 7 THEN Achievement END) is NULL THEN '0' ELSE MAX(CASE WHEN invoice_month = 7 THEN Achievement END) END AS achievement_1,
    CASE WHEN MAX(CASE WHEN invoice_month = 8 THEN Achievement END) is NULL THEN '0' ELSE MAX(CASE WHEN invoice_month = 8 THEN Achievement END) END AS achievement_2,
    CASE WHEN MAX(CASE WHEN invoice_month = 9 THEN Achievement END) is NULL THEN '0' ELSE MAX(CASE WHEN invoice_month = 9 THEN Achievement END) END AS achievement_3,
	MAX(invoice_year) AS invoice_year

INTO [uli_loyalty].[dbo].activity_detail_inv_achievement
FROM  #activity
GROUP BY activity_id, outlet_id, [quarter];

-- SELECT * FROM [uli_loyalty].[dbo].activity_detail_inv_achievement


-- -- STEP IV : Mapping

DROP TABLE IF EXISTS [uli_loyalty].[dbo].activity_detail_inv_summary
SELECT 
    TA.activity_id,
	LE.[quarter],
    TA.outlet_id,

    LE.target_1,
    CASE WHEN IA.achievement_1 IS NULL THEN 0 ELSE IA.achievement_1 END AS [achievement_1],
    CASE WHEN LE.target_1 - ISNULL(IA.achievement_1, 0) <= 0 THEN 1 ELSE 0 END AS [Remark_1],

    LE.target_2,
    CASE WHEN IA.achievement_2 IS NULL THEN 0 ELSE IA.achievement_2 END AS [achievement_2],
    CASE WHEN LE.target_2 - ISNULL(IA.achievement_2, 0) <= 0 THEN 1 ELSE 0 END AS [Remark_2],

    LE.target_3,
    CASE WHEN IA.achievement_3 IS NULL THEN 0 ELSE IA.achievement_3 END AS [achievement_3],
    CASE WHEN LE.target_3 - ISNULL(IA.achievement_3, 0) <= 0 THEN 1 ELSE 0 END AS [Remark_3],

    SUM(
        CASE WHEN LE.target_1 - ISNULL(IA.achievement_1, 0) <= 0 THEN 1 ELSE 0 END +
        CASE WHEN LE.target_2 - ISNULL(IA.achievement_2, 0) <= 0 THEN 1 ELSE 0 END +
        CASE WHEN LE.target_3 - ISNULL(IA.achievement_3, 0) <= 0 THEN 1 ELSE 0 END
    ) AS [Remark_ECO]

INTO [uli_loyalty].[dbo].activity_detail_inv_summary
FROM [uli_loyalty].[dbo].temp_act_outlet_list TA
LEFT JOIN [uli_loyalty].[dbo].[temp_act_outlet_list_eco] LE ON TA.activity_id = LE.activity_id AND TA.outlet_id = LE.Outlet_id
LEFT JOIN [uli_loyalty].[dbo].activity_detail_inv_achievement IA ON TA.activity_id = IA.activity_id AND TA.outlet_id = IA.outlet_id AND LE.[quarter]=IA.[quarter]
LEFT JOIN [uli_loyalty].[dbo].activities AC ON TA.activity_id=AC.activity_id

WHERE AC.mechanism_id = '2'
AND LE.[quarter] = 'Q3'
AND LE.[year] = '2025'

GROUP BY
    TA.activity_id,
    TA.outlet_id,
    LE.[quarter],
	LE.[year],
    LE.target_1,
    IA.achievement_1,
    LE.target_2,
    IA.achievement_2,
    LE.target_3,
    IA.achievement_3

-- SELECT * FROM [uli_loyalty].[dbo].activity_detail_inv_summary


END

