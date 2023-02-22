/* Student:Nan Chen -- CS5200-05, Spring 2023 */
/* Q1 */

/*
1. Find the distinct number of workers who work in the HR department 
and who earn more than ₹250,000.
*/
SELECT COUNT(DISTINCT w.WORKER_ID) AS No_Of_Workers
FROM Worker w
WHERE w.DEPARTMENT='HR' AND w.SALARY>250000

/*
2. Find the last name and title of all workers and the department 
they work in who earn less than the average salary.
*/
WITH AvgSalary AS (
  SELECT AVG(SALARY) AS AverageSalary
  FROM Worker
)
    SELECT 
    w.LAST_NAME AS 'Last Name', 
    t.WORKER_TITLE AS 'Title', 
    w.DEPARTMENT AS 'Department'
    FROM Worker w INNER JOIN Title t on t.WORKER_REF_ID=w.WORKER_ID
    JOIN AvgSalary ON 1=1
    WHERE Salary < AverageSalary
    
/*
3. What is the average salary paid for all workers in each department? 
List the department, the average salary for the department, and 
the number of workers in each department. Name the average 
column 'AvgSal' and the number of workers column to 'Num'.
*/ 
SELECT 
w.DEPARTMENT AS 'Department', 
AVG(SALARY) AS 'AvgSal', 
COUNT(WORKER_ID) AS 'Num'
FROM Worker w
GROUP BY w.DEPARTMENT

/*
4.What is the total compensation for each worker (salary and bonus) 
on a per monthly basis? List the name of the worker, their title, 
and the their monthly compensation (annual compensation divided by 12). 
Change the header for compensation to 'MonthlyComp' and round it to the 
nearest whole number.
*/
/*
creating a SumBonus view based of WORKER_REF_ID and BONUS_AMOUNT in Bonus table.
*/
CREATE VIEW SumBonus AS
SELECT WORKER_REF_ID, SUM(BONUS_AMOUNT) As 'Sum'
FROM Bonus
GROUP BY WORKER_REF_ID

/*
Get the bouns from SumBonus.
*/
SELECT  
w.FIRST_NAME||' '||w.LAST_NAME AS 'Name', 
t.WORKER_TITLE AS 'Title', 
round((w.SALARY+ COALESCE(b.Sum, 0))/12 , 0) AS 'MonthlyComp'
FROM Worker w
INNER JOIN Title t on t.WORKER_REF_ID = w.WORKER_ID
LEFT JOIN SumBonus b on b.WORKER_REF_ID = w.WORKER_ID


/*
5.List the full names of all workers in all capital 
letters who did not get a bonus.
*/
SELECT  UPPER(w.FIRST_NAME||' '||w.LAST_NAME) AS 'Full_Name'
FROM Worker w
LEFT JOIN Bonus b on b.WORKER_REF_ID = w.WORKER_ID
WHERE b.BONUS_AMOUNT IS NULL

/*
6. What are the full names of all workers who have 'Manager' in their 
title. Do not "hard code" the titles; use string searching. 
*/
SELECT  w.FIRST_NAME||' '||w.LAST_NAME AS 'Full_Name'
FROM Worker w
LEFT JOIN Title t on t.WORKER_REF_ID = w.WORKER_ID
WHERE t.WORKER_TITLE LIKE '%Manager%'

