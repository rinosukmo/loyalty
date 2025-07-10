USE [uli_loyalty]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[apps_io_summary_invoice] (@year varchar(5), @month varchar(5), @outlet varchar(20))
RETURNS TABLE 
AS   
RETURN 

SELECT 
	   RTRIM(A.[outlet_id]) [outlet_id]

	  ,CASE WHEN CONVERT(DATE, A.[invoice_date]) = CONVERT(DATE, GETDATE()) THEN 'Hari ini, ' + FORMAT(A.[invoice_date], 'dd MMMM, yyyy','id-ID') 
	        ELSE FORMAT(A.[invoice_date], 'dddd, dd MMMM, yyyy','id-ID') END [invoice_date]

	  ,'Nomor Invoice' [bar_invoice]
	  ,'#' + RTRIM(A.[invoice_no]) [invoice_no]

	  ,'Total Belanja' [bar_total]
	  ,'Rp. ' + FORMAT(CAST(A.[invoice_amount] as numeric (18,0)), '#,###') [invoice_amount]

	  ,CAST(A.[invoice_amount] as numeric) [cek]

	  ,YEAR(A.[invoice_date]) [year]
	  ,MONTH(A.[invoice_date]) [month]

  FROM [uli_loyalty].[dbo].[invoice_master] A

  WHERE A.invoice_type = 'I'
  AND YEAR(A.[invoice_date]) = @year
  AND MONTH(A.[invoice_date]) = @month
  AND A.outlet_id = @outlet


/*

Summary Invoice

*/
