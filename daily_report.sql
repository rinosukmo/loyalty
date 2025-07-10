 
 DROP TABLE IF EXISTS #TheAddress

CREATE TABLE #TheAddress (
    id INT, 
    outlet_id VARCHAR(50), 
    nama_penerima VARCHAR(200),
	nama_jalan VARCHAR(200),
	no_rumah VARCHAR(200),
	kelurahan VARCHAR(200),
	kecamatan VARCHAR(200),
	kota VARCHAR(200),
	kode_pos VARCHAR(200),
    lokasi TEXT,
    alamat_detail TEXT,
    image_lokasi TEXT,
	[url] TEXT,
    RowNum INT
);

WITH RankedData AS (
    SELECT
        CAST(id AS INT) AS id, 
        CAST(outlet_id AS VARCHAR(50)) AS outlet_id, 
        nama_penerima,
		nama_jalan,
		no_rumah,
		kelurahan,
		kecamatan,
		kota,
		kode_pos,
        lokasi,
		alamat_detail,
        image_lokasi,
		[url],
        ROW_NUMBER() OVER (PARTITION BY outlet_id ORDER BY id DESC) AS RowNum
    FROM
        [uli_loyalty].[dbo].alamat_pengiriman
)
INSERT INTO #TheAddress
SELECT
    id,
    outlet_id,
    nama_penerima,
	nama_jalan,
	no_rumah,
	kelurahan,
	kecamatan,
	kota,
	kode_pos,
    lokasi,
    alamat_detail,
    image_lokasi,
	[url],
    RowNum
FROM
    RankedData
WHERE
    RowNum = 1

-- SELECT * FROM  #TheAddress ;

DROP TABLE IF EXISTS #redeem_outlet
			  SELECT 
			  RTRIM(u.outlet_id) [outlet_id],
			  SUM(p.[point_redeem]) [total_redeem]
			  INTO #redeem_outlet
			  FROM [uli_loyalty].[dbo].[point_redeem] as p
			  INNER JOIN [uli_loyalty].[dbo].user_info as u ON p.user_id=u.user_id
			  LEFT JOIN [uli_loyalty].dbo.temp_master_data_uli as tm ON tm.[KODE TOKO]=u.outlet_id

			  WHERE p.point_year = 2025
		  	  AND ISNULL(tm.[KODE DIS], '') not like '99999999'
			  AND outlet_id not like 'R-%'
			  AND LEFT(u.outlet_id, 3) not in ('888', '999')
			  GROUP BY u.outlet_id

-- SELECT * FROM #redeem_outlet

  SELECT 
		CASE WHEN A.REGION like '%LMT%' THEN A.[REGION] ELSE 'RSM '+A.[REGION] END [REGION],
		CASE WHEN A.[AREA] like '%KAM%' THEN A.[AREA] 
		     WHEN A.[AREA] = 'BUH BALI' THEN 'BUH BALI' ELSE 'ASM '+A.[AREA] END [AREA],
		A.KODE_DISTRIBUTOR,
		A.KODE_OUTLET,
		D.[user_id],
		CASE WHEN G.total_point is NULL THEN '0' ELSE G.total_point END [TOTAL_POINT],
		CASE WHEN H.total_redeem is NULL THEN '0' ELSE H.total_redeem END [REDEEM_POINT],

		CASE WHEN G.total_point is NULL THEN '0' ELSE G.total_point END - 
			CASE WHEN H.total_redeem is NULL THEN '0' ELSE H.total_redeem END [POINT_SAAT_INI],

		C.dt_code_latest [MAPPING_DT_CODE],
		B.Remark_freeze [Remark_Freeze],
		'2025' [YEAR],
		GETDATE() [update_date]

  FROM [uli_loyalty].dbo.summary_outlet A
  RIGHT JOIN [uli_loyalty].[dbo].temp_master_data_uli B ON A.KODE_OUTLET=B.[KODE TOKO]
  LEFT JOIN [uli_loyalty].[dbo].[outlet_monthly_mapping] C ON A.KODE_OUTLET=C.outlet_code
  LEFT JOIN [uli_loyalty].[dbo].user_info D ON A.KODE_OUTLET=D.outlet_id
  LEFT JOIN [uli_loyalty].[dbo].master_peserta E ON A.KODE_OUTLET=E.KODE_OUTLET
  LEFT JOIN #TheAddress F ON A.KODE_OUTLET=F.outlet_id

  LEFT JOIN (  SELECT outlet_id, 
			   CAST(SUM(expected_invoice_addt_reward) as numeric) [total_point]
			   FROM [uli_loyalty].dbo.invoice_master
			   WHERE YEAR(invoice_date) = 2025 AND invoice_type != 'I'
			   GROUP BY outlet_id) G ON A.KODE_OUTLET=G.outlet_id

  LEFT JOIN #redeem_outlet H ON A.KODE_OUTLET=H.outlet_id


  where B.[KODE DIS] != '99999999'


/*

Summary Daily Report

*/