USE [uli_loyalty]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[apps_io_summary_invoice_detail] (@year varchar(5), @month varchar(5), @outlet varchar(20), @invoice varchar(50))
RETURNS TABLE 
AS   
RETURN 

SELECT 
	   RTRIM(A.outlet_id) [outlet_id]
	  ,RTRIM(A.[invoice_no]) [invoice_no]
	  ,B.product_description + ' (' + RTRIM(A.[item_code]) + ')' [product_name]

	  ,'Harga' [bar_harga]
	  ,'Rp. ' + FORMAT(CAST(A.[price] as numeric (18,0)), '#,###') [price]

	  ,'Qty' [bar_qty]
      ,A.[quantity]

	  ,'Total' [bar_total]
	  ,'Rp. ' + FORMAT(CAST(A.[total] as numeric (18,0)), '#,###') [total]

	  ,YEAR(A.[invoice_date]) [year]
	  ,MONTH(A.[invoice_date]) [month]
  FROM [uli_loyalty].[dbo].[invoice_detail] A
  LEFT JOIN [uli_loyalty].[dbo].master_products B ON A.item_code=B.sku_code

  WHERE YEAR(A.[invoice_date]) = @year
  AND MONTH(A.[invoice_date]) = @month
  AND A.outlet_id = @outlet
  AND A.invoice_no = @invoice




/*

Detail Invoice

*/
