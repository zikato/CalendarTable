DROP TABLE IF EXISTS dbo.Calendar;
CREATE TABLE dbo.Calendar (
	DateVal date NOT NULL CONSTRAINT PK_Calendar_DateVal PRIMARY KEY CLUSTERED
  , YearNum smallint NOT NULL
  , QuarterNum tinyint NOT NULL
  , MonthNum tinyint NOT NULL
  , MonthNameVal nvarchar(30) NOT NULL
  , DayOfMonthNum tinyint NOT NULL
  , DayOfYearNum smallint NOT NULL
  , DayOfWeekNum tinyint NOT NULL
  , DayOfWeekNameVal nvarchar(30) NOT NULL
  , WeekNum tinyint NOT NULL
  , IsoWeekNum tinyint NOT NULL
  , YearFirstDay date NOT NULL
  , YearLastDay date NOT NULL
  , QuarterFirstDay date NOT NULL
  , QuarterLastDay date NOT NULL
  , MonthFirstDay date NOT NULL
  , MonthLastDay date NOT NULL
  , WeekFirstDay date NOT NULL
  , WeekLastDay date NOT NULL
  , MonthOffset smallint NOT NULL
  , WeekOffset smallint NOT NULL
  , IsoWeekOffset smallint NOT NULL
  , DayOffset int NOT NULL
  , WorkdayOffset int NOT NULL
  , IsWeekend tinyint NOT NULL
  , IsBankHoliday tinyint NOT NULL
  , IsWorkday tinyint NOT NULL
  , FiscalYear smallint NOT NULL
  , FiscalMonth tinyint NOT NULL
  , FiscalQuarter tinyint NOT NULL
  , FiscalYearFirstDay date NOT NULL
  , FiscalYearLastDay date NOT NULL
  , INDEX IX_Calendar_DayOffset UNIQUE NONCLUSTERED (DayOffset)
)


GO

SET LANGUAGE English; /* Language affects the weekday name and DATEFORMAT */
SET DATEFIRST 1;  /* First day of the week is Monday */

DECLARE 
	@startDate AS date = DATEFROMPARTS(1990, 1, 1)
	, @endDate AS date = DATEFROMPARTS(2100,12,31)
	/* Fiscal Year https://en.wikipedia.org/wiki/Fiscal_year */
	, @fiscalYear_MonthStart tinyint = 1
	, @fiscalYearEnds bit = 1
		/* 
			0 = the fiscal year is denoted by the calendar year in which it begins
			1 = the fiscal year is denoted by the calendar year in which it end
		*/



; -- Previous statement must be properly terminated
WITH
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
		/* Denormalisation */
		, CAST(DATEADD(YEAR, DATEDIFF(YEAR, 0, d.DateVal), 0) AS date) AS YearFirstDay
		, CAST(DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, d.DateVal) + 1, 0)) AS date) AS YearLastDay
		, CAST(DATEADD(QUARTER, DATEDIFF(QUARTER, 0, d.DateVal), 0) AS date) AS QuarterFirstDay
		, CAST(DATEADD(DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, d.DateVal) + 1, 0)) AS date) AS QuarterLastDay
		, CAST(DATEADD(DAY, 1, EOMONTH(d.DateVal, -1)) AS date) AS MonthFirstDay
		, CAST(EOMONTH(d.DateVal) AS date) AS MonthLastDay
		, CAST(DATEADD(DAY, 1-DATEPART(WEEKDAY, d.DateVal), d.DateVal) AS date) AS WeekFirstDay /* Aaron Bertrand */
		, CAST(DATEADD(DAY, 7-DATEPART(WEEKDAY, d.DateVal), d.DateVal) AS date) AS WeekLastDay
		/* Offsets */
		/* Year offset is just a Year */
		, DATEDIFF(MONTH, @startDate, d.DateVal) AS MonthOffset
		, DATEDIFF(WEEK, @startDate, d.DateVal) AS WeekOffset
        , DENSE_RANK() OVER (ORDER BY DATEPART(YEAR, d.DateVal), DATEPART(ISO_WEEK, d.DateVal)) - 1 AS IsoWeekOffset
		, DATEDIFF(DAY, @startDate, d.DateVal) AS DayOffset
		, DATEDIFF(DAY, @startDate, d.DateVal) AS WorkdayOffset /* dummy values - recalculate on Holiday update */
		/* Booleans */
		, CASE DATEPART(weekday, DATEADD(day, @@DATEFIRST - 1, d.DateVal)) /* Itzik Ben-Gan's @@datefirst compensation method */
			WHEN 6 THEN 1
			WHEN 7 THEN 1
			ELSE 0 
		END AS IsWeekend
		, 0 AS IsBankHoliday
		, 0 AS IsWorkday
		/* Fiscal dateparts */
		, fy.FiscalYear
		, FLOOR(((12 + MONTH(d.DateVal) - @fiscalYear_MonthStart) % 12) / 3 ) + 1 AS FiscalQuarter
		, fm.FiscalMonth
		, DATEFROMPARTS(fy.FiscalYear - @fiscalYearEnds, @fiscalYear_MonthStart, 1) AS FiscalYearFirstDay
		, DATEADD(DAY, -1, DATEFROMPARTS(fy.FiscalYear +1 - @fiscalYearEnds, @fiscalYear_MonthStart, 1)) AS FiscalYearLastDay
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
	) fm(FiscalMonth)
	CROSS APPLY
	(
		VALUES 
		(
			(YEAR(d.DateVal) - 1) + @fiscalYearEnds + CASE WHEN MONTH(d.DateVal) < @fiscalYear_MonthStart THEN 0 ELSE 1 END
		)
	) fy (FiscalYear)
	WHERE 
        d.DateVal > @startDate
		AND D.DateVal < @endDate
)
INSERT INTO dbo.Calendar WITH (TABLOCKX)
(
      DateVal
    , YearNum
    , QuarterNum
    , MonthNum
    , MonthNameVal
    , DayOfYearNum
    , DayOfMonthNum
    , DayOfWeekNum
    , DayOfWeekNameVal
    , WeekNum
    , IsoWeekNum
    , YearFirstDay
    , YearLastDay
    , QuarterFirstDay
    , QuarterLastDay
    , MonthFirstDay
    , MonthLastDay
    , WeekFirstDay
    , WeekLastDay
    , MonthOffset
    , WeekOffset
    , IsoWeekOffset
    , DayOffset
    , WorkdayOffset
    , IsWeekend
    , IsBankHoliday
    , IsWorkday
    , FiscalYear
    , FiscalQuarter
    , FiscalMonth
    , FiscalYearFirstDay
    , FiscalYearLastDay

)

SELECT
	  c.DateVal
    , c.YearNum
    , c.QuarterNum
    , c.MonthNum
    , c.MonthNameVal
    , c.DayOfYearNum
    , c.DayOfMonthNum
    , c.DayOfWeekNum
    , c.DayOfWeekNameVal
    , c.WeekNum
    , c.IsoWeekNum
    , c.YearFirstDay
    , c.YearLastDay
    , c.QuarterFirstDay
    , c.QuarterLastDay
    , c.MonthFirstDay
    , c.MonthLastDay
    , c.WeekFirstDay
    , c.WeekLastDay
    , c.MonthOffset
    , c.WeekOffset
    , c.IsoWeekOffset
    , c.DayOffset
    , c.WorkdayOffset
    , c.IsWeekend
    , c.IsBankHoliday
    , c.IsWorkday
    , c.FiscalYear
    , c.FiscalQuarter
    , c.FiscalMonth
    , c.FiscalYearFirstDay
    , c.FiscalYearLastDay
FROM calendar AS c
ORDER BY c.DateVal

SELECT 
	*
FROM dbo.Calendar AS c 