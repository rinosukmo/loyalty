USE [uli_loyalty]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[apps_io_redeem_loyalty] 
				 (@outlet varchar(50), 
				  @giftcode varchar(200), 
				  @qty int,
				  @year int,
				  @redeemno varchar(50))
				  
AS
BEGIN


DROP TABLE IF EXISTS #tempouserid
SELECT [user_id], outlet_id, store_name 
INTO #tempouserid
FROM [uli_loyalty].[dbo].user_info WHERE outlet_id = @outlet

DROP TABLE IF EXISTS #cekpoint
SELECT
    A.redeem_code,
    A.point,
    CAST(dolphin.[dbo].[outlet_wish_item.get_current_total_point](@outlet, @year) AS NUMERIC) AS total_point,
	CAST(dolphin.[dbo].[outlet_wish_item.get_current_total_point](@outlet, @year) AS NUMERIC) - A.point AS berapa,
	CASE WHEN CAST(dolphin.[dbo].[outlet_wish_item.get_current_total_point](@outlet, @year) AS NUMERIC) - A.point < 0 
	THEN 1 ELSE 0 END AS cek_poin
INTO #cekpoint
FROM dolphin.dbo.redeem_item A
WHERE A.redeem_code = @giftcode

 -- SELECT * FROM #cekpoint

DROP TABLE IF EXISTS #cektime
SELECT 
	  A.[user_id] 
	 ,COALESCE(B.[redeem_code],'-') [redeem_code]
	 ,CASE WHEN B.[created_date] >= DATEADD(MINUTE, -2, GETDATE()) THEN 1 ELSE 0 END [cek_status]
	 ,COALESCE(B.created_date,GETDATE()) [created_date]
INTO #cektime
FROM #tempouserid A
LEFT JOIN ( SELECT TOP 1 [user_id], [redeem_code], [created_date]
		    FROM [uli_loyalty].[dbo].[log_validasi_redeem]
			WHERE [user_id] = (SELECT [user_id] FROM #tempouserid)
			ORDER BY  [created_date] DESC) B
			ON A.[user_id]=B.[user_id]


DROP TABLE IF EXISTS #alamatoutlet
SELECT TOP 1 
       RTRIM([outlet_id]) [outlet_id], [nama_penerima], [nama_jalan], [no_rumah]
      ,[provinsi], [kota], [kecamatan], [kelurahan], [kode_pos]
INTO #alamatoutlet
FROM [uli_loyalty].[dbo].[alamat_pengiriman]
WHERE RTRIM([outlet_id]) = @outlet
ORDER BY [id] DESC

-- SELECT * FROM #alamatoutlet


DROP TABLE IF EXISTS #outletinfo
SELECT A.[user_id], RTRIM(A.user_email) [user_email], RTRIM(A.no_hp) [no_hp], CONVERT(DATE, A.date_created) [date_created], 
	   B.jenis, LEFT(REPLACE(NEWID(), '-', ''), 14) [redeem_no]
INTO	#outletinfo
FROM dolphin.dbo.user_info A
LEFT JOIN dolphin.dbo.master_peserta B ON A.outlet_id=B.KODE_OUTLET
WHERE outlet_id = @outlet


-- SELECT * FROM #outletinfo


INSERT INTO [uli_loyalty].[dbo].[point_redeem]
SELECT 
	   --(SELECT redeem_no FROM #outletinfo) [redeem_no]
	   @redeemno [redeem_no]
      ,GETDATE() [redeem_date]
      ,(SELECT [user_id] FROM #outletinfo) [user_id]
      ,(@qty * (SELECT point FROM [uli_loyalty].[dbo].redeem_item WHERE redeem_code = @giftcode)) [point_redeem]
      ,@giftcode [gift_code]
      ,((@qty * (SELECT point FROM [uli_loyalty].[dbo].redeem_item WHERE redeem_code = @giftcode)) * 4000) [amount]
      ,'DIPROSES' [status_delivery]
      ,NULL [delivery_date]
      ,NULL [return_date]
      ,NULL [minimum_point]
      ,NULL [no_voucher]
      ,NULL [trxNo]
      ,@year [point_year]
      ,NULL [received_date]
      ,NULL [url_image]
      ,NULL [note]
      ,NULL [email_user]
      ,NULL [is_directgift]
WHERE (SELECT [cek_status] FROM #cektime) = 0
AND (SELECT [cek_poin] FROM #cekpoint) != 1


INSERT INTO [uli_loyalty].[dbo].[point_redeem_detail]
SELECT 
       --(SELECT redeem_no FROM #outletinfo) [redeem_no]
	   @redeemno [redeem_no]
      ,@outlet [outlet_id]
      ,'loyalty' [redeem_type]
      ,(SELECT nama_penerima FROM #alamatoutlet) [nama_penerima]
      ,(SELECT nama_jalan FROM #alamatoutlet) [nama_jalan]
      ,(SELECT no_rumah FROM #alamatoutlet) [no_rumah]
      ,(SELECT kelurahan FROM #alamatoutlet) [kelurahan]
      ,(SELECT kecamatan FROM #alamatoutlet) [kecamatan]
      ,(SELECT provinsi FROM #alamatoutlet) [provinsi]
      ,(SELECT kota FROM #alamatoutlet) [kota]
      ,(SELECT kode_pos FROM #alamatoutlet) [kode_pos]
      ,(SELECT no_hp FROM #outletinfo) [no_telp]
      ,NULL [foto_ktp]
      ,NULL [foto_kk]
WHERE (SELECT [cek_status] FROM #cektime) = 0
AND (SELECT [cek_poin] FROM #cekpoint) != 1


INSERT INTO [uli_loyalty].[dbo].[notifications]
SELECT 
		 @outlet as [outlet_id]
		,'Redeem ' + (
				CASE WHEN (SELECT type_code FROM [uli_loyalty].[dbo].redeem_item WHERE redeem_code = @giftcode) = 08 THEN 'Peralatan Rumah Tangga'
					 WHEN (SELECT type_code FROM [uli_loyalty].[dbo].redeem_item WHERE redeem_code = @giftcode) = 04 THEN 'Elektronik'
					 WHEN (SELECT type_code FROM [uli_loyalty].[dbo].redeem_item WHERE redeem_code = @giftcode) = 04 THEN 'Kendaraan'
				ELSE 'Juragan' END)
				as [notification_title]

		,CASE WHEN (SELECT vendor_code FROM [uli_loyalty].[dbo].redeem_item WHERE redeem_code = @giftcode) = 'V03' THEN 
		 'Selamat! Penukaran point Juragan Anda untuk ' + (SELECT RTRIM(gift_name) FROM [uli_loyalty].[dbo].redeem_item WHERE redeem_code = @giftcode) + ' dengan nomor redeem ' +
		  @redeemno + ' akan segera diproses. Terima Kasih.' 
		  ELSE 'Selamat atas penukaran point Juragan Anda! Nomor redeem Anda adalah ' + @redeemno + '. Terima Kasih.'
		  END [notification_detail]
        
		,GETDATE() as [notification_date]
		,NULL [area]
		,NULL [status]
WHERE (SELECT [cek_status] FROM #cektime) = 0
AND (SELECT [cek_poin] FROM #cekpoint) != 1


END


/*

Redeem Apps

*/
