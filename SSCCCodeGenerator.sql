begin try
begin tran
	declare @NewSSCCID int
	declare @Expander int =0, @GS1ID int=123456789--your GS1 ID
, @CodeData varchar(18)='', @Summ int=0, @ControlDigit int = 0, @TempStr varchar(34);
	if not exists(select top 1 * from tblSSCCStorage where SSCCBoxID is null)
	begin
		insert into tblSSCCStorage (CodeData
					 ,SSCCBoxID
					 ,MDocID,Confirmed)
		values ('', @SSCCBoxID, null,0)
		select @NewSSCCID=SCOPE_IDENTITY() 
		set @Expander=FLOOR(@NewSSCCID / 10000000)-1;
		--если expander когда-то пересечет 10, нужно запросить новый постоянный код GS1, так как мы создадим к тому времени 100 млн коробок
		set @TempStr=convert(varchar(1), @Expander)+convert(varchar(9), @GS1ID)+SUBSTRING(convert(varchar(8), @NewSSCCID), 2, 7)
		declare @pos int
		set @pos = 2 -- место для первого пробела
		while @pos < LEN(@TempStr)+1 
		begin 
			 set @TempStr = STUFF(@TempStr, @pos, 0, SPACE(1)); 
			 set @pos = @pos+2; 
		end 
		;with pre as
		(
			select convert(int, value) num,  ROW_NUMBER() OVER(ORDER BY (SELECT NULL))%2 rn  from STRING_SPLIT( @TempStr , SPACE(1))
		)
		select @Summ=sum(num*iif(rn=1,3,1)) from pre

		set @ControlDigit= FLOOR(@Summ/10)*10+iif(@Summ%10=0,0,10)-@Summ
		set @CodeData = convert(varchar(1), @Expander)+convert(varchar(9), @GS1ID)+SUBSTRING(convert(varchar(8), @NewSSCCID), 2, 7)+convert(varchar(1), @ControlDigit)
		update tblSSCCStorage set CodeData=@CodeData where SSCCID=@NewSSCCID
	end
	select top 1 @NewSSCCID=ssccid from tblSSCCStorage where SSCCBoxID is null order by SSCCID asc
	update tblSSCCStorage set SSCCBoxID=@SSCCBoxID where SSCCID=@NewSSCCID
	select @NewSSCCID
commit tran
end try
begin catch
	if XACT_STATE() <> 0
		rollback tran
	;throw
end catch
