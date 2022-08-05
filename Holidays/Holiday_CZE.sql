
DROP TABLE IF EXISTS #StaticHoliday
CREATE TABLE #StaticHoliday
(
	YearFrom smallint not null
	, YearTo smallint not null
	, MonthPart tinyint not null
	, DayPart tinyint not null
	, HolidayName nvarchar(100) null
)

INSERT INTO #StaticHoliday
VALUES
	(1993, 9999, 1, 1, N'Den obnovy samostatného českého státu / Nový rok')
,	(1890, 9999, 5, 1, N'Svátek práce')
,	(1945, 9999, 5, 8, N'Den vítězství')
,	(1918 , 9999, 7, 5, N'Den slovanských věrozvěstů Cyrila a Metoděje')
,	(1918, 9999, 7, 6, N'Den upálení mistra Jana Husa')
,	(1918, 9999, 9, 28, N'Den české státnosti')
,	(1918, 9999, 10, 28, N'Den vzniku samostatného československého státu')
,	(1989, 9999, 11, 17, N'Den boje za svobodu a demokracii a Mezinárodní den studentstva')
,	(1918, 9999, 12, 24, N'Štědrý den')
,	(1918, 9999, 12, 25, N'1. svátek vánoční')
,	(1918, 9999, 12, 26, N'2. svátek vánoční')

/* Update Static Holidays */

; -- Previous statement must be properly terminated
WITH StaticHolidays
AS
(
    SELECT 
        c.DateVal
        , c.IsBankHoliday
        , c.IsWorkday
	    , sh.*
    FROM dbo.Calendar AS c
    JOIN #StaticHoliday AS sh
        ON c.YearNum >= sh.YearFrom
        AND c.YearNum < sh.YearTo
        AND c.MonthNum = sh.MonthPart
        AND c.DayOfMonthNum = sh.DayPart
)
UPDATE sh
	SET 
        sh.IsBankHoliday = 1
        , sh.IsWorkday = 0
FROM StaticHolidays AS sh 


/* Dynamic Holidays */

; -- Previous statement must be properly terminated
WITH DynamicHolidays
AS
(
    SELECT 
	    c.DateVal
        , c.IsBankHoliday
        , c.IsWorkday
        , reh.*
    FROM dbo.Calendar AS c
    CROSS APPLY dbo.ReturnEasterHolidays(c.YearNum) AS reh
    WHERE 
        reh.EasterDate = c.DateVal
        AND 
        (
    
            reh.EasterDayName = 'Sunday'
            OR
            (
                reh.EasterDayName = 'Monday' /* Velikonoční pondělí - od roku 1918? */
                AND c.YearNum >= 1918
                AND c.YearNum <  9999
            )
            OR 
            (
                reh.EasterDayName = 'Friday' 
                AND c.YearNum >= 2016   /* Velký pátek - od roku 2016 */
                AND c.YearNum <  9999
            )
        )
)
UPDATE dh
    SET 
        dh.IsBankHoliday = 1
        , dh.IsWorkday = 0
FROM DynamicHolidays AS dh


/* Update WorkDayOffset */

; -- Previous statement must be properly terminated
WITH WorkdayOffset
AS
(
    SELECT 
	    c.DateVal
        , c.IsWorkday
        , c.IsBankHoliday
        , c.IsWeekend
        , c.WorkdayOffset
        , SUM(c.IsWorkday) OVER (ORDER BY c.DateVal) AS WorkdayOffsetCalc
    FROM dbo.Calendar AS c
)
UPDATE wo WITH (TABLOCKX)
    SET wo.WorkdayOffset = WorkdayOffsetCalc
FROM WorkdayOffset AS wo

/* 
    Create a supporting index 
CREATE NONCLUSTERED INDEX IX_Calendar_WorkdayOffset ON dbo.Calendar
(WorkdayOffset) INCLUDE (DateVal)

*/

/* Create an ITVF to wrap the logic */
GO
CREATE OR ALTER FUNCTION dbo.GetWorkdayOffset
(
    @StartDate AS date
    , @Offset AS int
)
RETURNS TABLE
AS
RETURN 
    SELECT 
	    c.DateVal AS OffsetDate
    FROM 
        dbo.Calendar AS c
    WHERE 
        c.WorkdayOffset = @Offset + 
        (
            SELECT c.WorkdayOffset
            FROM dbo.Calendar AS c
            WHERE c.DateVal = @StartDate
        )
GO

/* Test */
SELECT * FROM dbo.GetWorkdayOffset(DATEFROMPARTS(2022,9,23),7) AS gwo 


