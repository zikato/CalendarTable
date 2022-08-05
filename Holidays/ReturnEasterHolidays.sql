CREATE OR ALTER FUNCTION dbo.ReturnEasterHolidays
(
	@year smallint
)
RETURNS TABLE WITH SCHEMABINDING
AS
RETURN
SELECT
	DATEADD(DAY, holidays.offset, EasterDate.Val) AS EasterDate
	, holidays.name AS EasterDayName
FROM 
(VALUES ((24 + 19 * (@year % 19)) % 30 )) AS EpactCalc(Val)
CROSS APPLY (VALUES (EpactCalc.Val - (EpactCalc.Val / 28))) AS PaschalDaysCalc(Val)
CROSS APPLY (VALUES (PaschalDaysCalc.Val - ((@year + @year / 4 + PaschalDaysCalc.Val - 13) % 7 ))) AS NumOfDaysToSunday(Val)
CROSS APPLY (VALUES (3 + (NumOfDaysToSunday.Val + 40) / 44 )) AS EasterMonth(Val)
CROSS APPLY (VALUES (NumOfDaysToSunday.Val + 28 - (31 * (EasterMonth.Val / 4)))) AS EasterDay(Val) 
CROSS APPLY (VALUES (DATEFROMPARTS(@year, EasterMonth.val, EasterDay.val))) AS EasterDate(Val) 
CROSS APPLY 
(
	VALUES 
	(-2, 'Friday')
	, (0, 'Sunday') 
	, (1, 'Monday')
) AS holidays(offset, name)
GO



