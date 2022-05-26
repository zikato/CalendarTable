

SET LANGUAGE English; /* Language affects the weekday name and DATEFORMAT */
SET DATEFIRST 1;  /* First day of the week is Monday */



DROP TABLE IF EXISTS dbo.Calendar;
CREATE TABLE dbo.Calendar (
	DateVal date NOT NULL CONSTRAINT PK_Calendar_DateVal PRIMARY KEY CLUSTERED
  , YearNum smallint NOT NULL
  , QuarterNum tinyint NOT NULL
  , MonthNum tinyint NOT NULL
  , MonthNameVal nvarchar(30) NOT NULL
  , DayOfYearNum smallint NOT NULL
  , DayOfMonthNum tinyint NOT NULL
  , DayOfWeekNum tinyint NOT NULL
  , DayOfWeekNameVal nvarchar(30) NOT NULL
  , WeekNum tinyint NOT NULL
  , IsoWeekNum tinyint NOT NULL
  , FirstDayOfMonth date NOT NULL
  , LastDayOfMonth date NOT NULL
  , MonthOffset int NOT NULL
  , WeekOffset int NOT NULL
  , IsoWeekOffset int NOT NULL
  , DayOffset int NOT NULL
  , IsWeekend tinyint NOT NULL
  , IsBankHoliday tinyint NOT NULL
  , IsWorkingDay tinyint NOT NULL
  , FiscalYear smallint NOT NULL
  , FiscalMonth tinyint NOT NULL
  , FiscalQuarter tinyint NOT NULL
)

GO

DECLARE 
	@startDate AS date = DATEFROMPARTS(1990, 1, 1)
	, @endDate AS date = DATEFROMPARTS(2100,12,31)
	/* Fiscal Year https://en.wikipedia.org/wiki/Fiscal_year */
	, @fiscalYear_MonthStart tinyint = 8
	, @fiscalYearBegins bit = 0
		/* 
			1 = the fiscal year is denoted by the calendar year in which it begins
			0 = the fiscal year is denoted by the calendar year in which it end
		*/


;WITH
    L0   AS (SELECT c FROM (SELECT 1 UNION ALL SELECT 1) AS D(c)),
    L1   AS (SELECT 1 AS c FROM L0 AS A CROSS JOIN L0 AS B),
    L2   AS (SELECT 1 AS c FROM L1 AS A CROSS JOIN L1 AS B),
    L3   AS (SELECT 1 AS c FROM L2 AS A CROSS JOIN L2 AS B),
    L4   AS (SELECT 1 AS c FROM L3 AS A CROSS JOIN L3 AS B),
	L5   AS (SELECT 1 AS c FROM L4 AS A CROSS JOIN L4 AS B),
    numbers AS (SELECT TOP (POWER(10,6)) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS rownum
             FROM L5)
, dates
AS
(
	SELECT 
		DATEADD(DAY, n.rownum - 1, @startDate) AS DateVal /* zero based */
	FROM numbers AS n
),
calendar
AS
(
	SELECT
		CAST(d.DateVal AS date) AS DateVal
	  , DATEPART(YEAR, d.DateVal) AS YearNum
	  , DATEPART(QUARTER, d.DateVal) AS QuarterNum
	  , DATEPART(MONTH, d.DateVal) AS MonthNum
	  , DATENAME(MONTH, d.DateVal) AS MonthNameVal
	  , DATEPART(DAYOFYEAR, d.DateVal) AS DayOfYearNum
	  , DATEPART(DAY, d.DateVal) AS DayOfMonthNum
	  , DATEPART(WEEKDAY, d.DateVal) AS DayOfWeekNum
	  , DATENAME(WEEKDAY, d.DateVal) AS DayOfWeekNameVal
	  , DATEPART(WEEK, d.DateVal) AS WeekNum
	  , DATEPART(ISO_WEEK, d.DateVal) AS IsoWeekNum
	  /* denormalisation */
	  , DATEADD(DAY, 1, EOMONTH(d.DateVal, -1)) AS FirstDayOfMonth
	  , EOMONTH(d.DateVal) AS LastDayOfMonth
	  /* Offsets */
	  /* Year offset is just a Year */
	  , DATEDIFF(MONTH, @startDate, d.DateVal) AS MonthOffset
	  , DATEDIFF(WEEK, @startDate, d.DateVal) AS WeekOffset
	  , DENSE_RANK() OVER (ORDER BY DATEPART(YEAR, d.DateVal), DATEPART(ISO_WEEK, d.DateVal)) - 1 AS IsoWeekOffset
	  , DATEDIFF(DAY, @startDate, d.DateVal) AS DayOffset
	  /* Booleans */
	  , CASE DATEPART(weekday, DATEADD(day, @@DATEFIRST - 1, d.DateVal)) /* Itzik Ben-Gan's @@datefirst compensation method */
			WHEN 6 THEN 1
			WHEN 7 THEN 1
			ELSE 0 
		END AS IsWeekend
	  , 0 AS IsBankHoliday
	  , 0 AS IsWorkingDay
	/* Fiscal dateparts */
	  , CASE
			WHEN @fiscalYearBegins = 1
				THEN CASE 
					WHEN MONTH(d.DateVal) >= @fiscalYear_MonthStart 
						THEN YEAR(d.DateVal)
					ELSE 
						YEAR(d.DateVal) - 1
				END
			ELSE 
				CASE 
					WHEN MONTH(d.DateVal) < @fiscalYear_MonthStart
						THEN YEAR(d.DateVal)
					ELSE 
						YEAR(d.DateVal) + 1
				END
		END AS FiscalYear
	, ca.FiscalMonth
	, CASE
		WHEN ca.FiscalMonth BETWEEN 1  AND 3  THEN 1
		WHEN ca.FiscalMonth BETWEEN 4  AND 6  THEN 2
		WHEN ca.FiscalMonth BETWEEN 7  AND 9  THEN 3
		WHEN ca.FiscalMonth BETWEEN 10 AND 12 THEN 3
		END AS FiscalQuarter
	FROM 
		dates AS d
	CROSS APPLY
	(
		VALUES 
		(
			/* 
				cycling numbers from 1 to 12
				((num - 1) modulo 12) + 1
			*/
			((MONTH(D.DateVal) + 12 - @fiscalYear_MonthStart)  % 12) + 1
		) 
	) ca(FiscalMonth)
	WHERE 
		D.DateVal < @endDate
)
INSERT INTO dbo.Calendar WITH (TABLOCKX)
SELECT
	*
FROM calendar AS c
ORDER BY c.DateVal

