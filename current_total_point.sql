USE [uli_loyalty]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER FUNCTION [dbo].[outlet_wish_item.get_current_total_point](@outlet_id varchar(100), @year varchar(4))  
RETURNS decimal(18,4)
AS   

-- Returns current total point of outlet
BEGIN  
    DECLARE @return decimal(18,4), @invoice_point decimal(18,4), @redeem_point decimal(18,4), 
			@cashback_redeem_point decimal(18,4), @ppob_redeem_point decimal(18,4), @redeem_ovo_point decimal(18,4),
			@ewallet_redeem_point decimal(18,4),
			@year_i integer;  
  	
	IF (@year = '2018' OR @year = '2019' OR @year = '2020' OR @year = '2021' OR @year = '2022' OR @year = '2023' OR @year = '2024' OR @year = '2025')
		BEGIN
			
			SELECT @year_i = CAST(@year as int)

			SELECT	@invoice_point = ISNULL(SUM((ISNULL(A.expected_invoice_reward, 0) 
									 + ISNULL(A.expected_invoice_addt_reward, 0)  
									 + ISNULL(A.expected_invoice_npd_reward, 0))), 0) 
			FROM	 invoice_master A
			WHERE	A.outlet_id = @outlet_id
					and year(invoice_date) = @year_i
			GROUP BY A.outlet_id;  
			
			-- #redeem item catalog (NON OVO)
			SELECT	@redeem_point = ISNULL(SUM(ISNULL(point_redeem, 0)), 0) 
			FROM		point_redeem X
					INNER JOIN point_redeem_detail Y
					ON X.redeem_no = Y.redeem_no
					INNER JOIN redeem_item Z
					ON X.gift_code = Z.redeem_code -- END (NON OVO)
			WHERE	Y.outlet_id = @outlet_id
					AND X.[point_year] = @year_i
					AND ISNULL(Z.type_code, '00') not in ('12'); -- END (NON OVO)
				

			-- #cashback only
			SELECT	@cashback_redeem_point = ISNULL(SUM(ISNULL(point_redeem, 0)), 0) 
			FROM		point_redeem X
					INNER JOIN point_redeem_detail_cashback Y
					ON X.redeem_no = Y.redeem_no
			WHERE	Y.outlet_id = @outlet_id
					AND X.[point_year] = @year_i;
			
			-- #PPOB only
			SELECT	@ppob_redeem_point = ISNULL(SUM(ISNULL(point_redeem, 0)), 0) 
			FROM		point_redeem X
					INNER JOIN [PPOB.transaction_master] Y
					ON X.redeem_no = Y.redeem_no
			WHERE	Y.outlet_id = @outlet_id
					AND X.[point_year] = @year_i;

			-- #redeem OVO only
			SELECT	@redeem_ovo_point = ISNULL(SUM(ISNULL(point_redeem, 0)), 0) 
			FROM		point_redeem X
					INNER JOIN point_redeem_detail Y
					ON X.redeem_no = Y.redeem_no
					INNER JOIN redeem_item Z
					ON X.gift_code = Z.redeem_code -- END (OVO)
			WHERE	Y.outlet_id = @outlet_id
					AND X.[point_year] = @year_i
					AND ISNULL(Z.type_code, '00') in ('12')
					AND X.status_delivery <> 'Failed'; -- END (OVO)			

			-- #EWALLET only
			SELECT	@ewallet_redeem_point = ISNULL(SUM(ISNULL(point_redeem, 0)), 0) 
			FROM		point_redeem X
					INNER JOIN [EWallet.transaction_master] Y
					ON X.redeem_no = Y.redeem_no
			WHERE	Y.outlet_id = @outlet_id
					AND X.[point_year] = @year_i;


			
			SELECT @return = ISNULL(@invoice_point, 0) - ISNULL(@redeem_point, 0) - ISNULL(@cashback_redeem_point, 0) - ISNULL(@ppob_redeem_point, 0) - ISNULL(@redeem_ovo_point, 0) - ISNULL(@ewallet_redeem_point, 0) 
		END
	ELSE 
		BEGIN 
			SET @return = (	SELECT [remain_point] 
							FROM [new_point_balance]
							WHERE [outlet_id] = @outlet_id);
		END



    IF (@return IS NULL)   
        SET @return = 0;

    RETURN @return;  
END; 

/*

Note : Check Point Apps

*/
