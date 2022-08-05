/*

To determine whether a year is a leap year, follow these steps:

If the year is evenly divisible by 4, go to step 2. Otherwise, go to step 5.
If the year is evenly divisible by 100, go to step 3. Otherwise, go to step 4.
If the year is evenly divisible by 400, go to step 4. Otherwise, go to step 5.
The year is a leap year (it has 366 days).
The year is not a leap year (it has 365 days).


Leap years
Divisible by 4						1988, 1992, 1996
Divisibile by 4, 100 and 400		1600, 2000, 2400
Divisible by 4, 100 but not 400		1700, 1800, 1900, 2100, 2200, 2300, 2500, 2600 


*/

CREATE OR ALTER FUNCTION dbo.IsLeapYear
(
	@year smallint
)
RETURNS TABLE WITH SCHEMABINDING
AS
RETURN
SELECT CAST
(
	CASE WHEN @year % 4 = 0
		THEN CASE WHEN @year % 100 = 0
			THEN CASE WHEN @year % 400 = 0
				THEN 1
				ELSE 0
				END
			ELSE 1
			END
		ELSE 0
		END
	AS tinyint
) AS RESULT
GO