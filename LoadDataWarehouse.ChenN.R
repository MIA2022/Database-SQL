# Connect to the SQLite database
library(RSQLite)
getwd()
fpath <- getwd()
dbfile <- "Practicum.sqlite"
sqlite_con <- dbConnect(RSQLite::SQLite(), paste0(fpath, dbfile))

# Connect to the MySQL server (without specifying a database), 
# create a new analytical database, and connect to it:

library(RMySQL)

db_user <- 'root'
db_password <- 'Qazwsx123.'
db_name <- 'practicum2'
db_host <- '127.0.0.1'
db_port <- 3306


mysql_con <- dbConnect(MySQL(), user = db_user, password = db_password, host = db_host, port = db_port)

dbGetQuery(mysql_con, paste0("CREATE DATABASE IF NOT EXISTS ", db_name, ";"))

dbDisconnect(mysql_con)
mysql_con <- dbConnect(MySQL(), user = db_user, password = db_password, dbname = db_name, host = db_host, port = db_port)

# extract data from SQLite
# This SQL query retrieves information about authors, including their ID, 
# name, number of articles, and number of co-authors. 
sql_query <- "
SELECT
  AA.AuthorID,
  REPLACE(COALESCE(A.LastName, ''), '''', '''''') || ', ' || COALESCE(A.ForeName, '') || ' ' || COALESCE(A.Initials, '') AS AuthorName,
  COUNT(DISTINCT AA.PMID) AS NumArticles,
  COUNT(DISTINCT AA2.AuthorID) - 1 AS NumCoAuthors
FROM
  Article_Author AS AA
JOIN Authors AS A ON AA.AuthorID = A.AuthorID
JOIN Article_Author AS AA2 ON AA.PMID = AA2.PMID
GROUP BY AA.AuthorID
"

#Execute the SQL query and fetch the results:
author_fact_table_data <- dbGetQuery(sqlite_con, sql_query)

#Create and populate the fact table in the MySQL database:
# Create the fact table
author_fact_table_create_query <- "
CREATE TABLE IF NOT EXISTS AuthorFacts (
  AuthorID INT,
  AuthorName VARCHAR(255),
  NumArticles INT,
  NumCoAuthors INT,
  PRIMARY KEY (AuthorID)
)"
dbExecute(mysql_con, author_fact_table_create_query)

dbSendQuery(mysql_con, "SET GLOBAL local_infile = true")
# Insert the fact table data
dbWriteTable(mysql_con, "AuthorFacts", author_fact_table_data, append = TRUE, row.names = FALSE)




# extract data from SQLite
# This SQL query calculates the total number of articles, number of years, 
# and average number of articles per year, quarter, and month for each journal. 
# It first creates a Common Table Expression (CTE) to calculate the yearly 
# article count for each journal and then aggregates the results to compute the averages.
Journal_query <- "WITH YearlyArticleCount AS (
  SELECT
    j.ISSN,
    j.Title AS JournalName,
    j.Year,
    COUNT(a.PMID) AS NumOfArticlesYear
  FROM
    Journals AS j
  JOIN
    Articles AS a ON a.JournalID = j.JournalID
  GROUP BY
    j.ISSN,
    j.Title,
    j.Year
)


SELECT
    y.ISSN,
    y.JournalName,
    SUM(y.NumOfArticlesYear) AS numsum,
    COUNT(DISTINCT y.Year) AS yearnum,
    CEIL(SUM(y.NumOfArticlesYear) / COUNT(DISTINCT y.Year)) AS AvgNumOfArticlesPerYear,
    CEIL(SUM(y.NumOfArticlesYear) / 4) AS AvgNumOfArticlesPerQuarter,
    CEIL(SUM(y.NumOfArticlesYear) / 12) AS AvgNumOfArticlesPerMonth
  FROM
    YearlyArticleCount AS y
  GROUP BY
    y.ISSN,
    y.JournalName
"

#Execute the SQL query and fetch the results:
Journal_fact_table_data <- dbGetQuery(sqlite_con, Journal_query)


#Create and populate the fact table in the MySQL database:
# Create the fact table
Journal_fact_table_create_query <- "
CREATE TABLE JournalFacts (
  ISSN VARCHAR(255),
  JournalName VARCHAR(255),
  numsum INTEGER,
  yearnum INTEGER,
  AvgNumOfArticlesPerYear INTEGER,
  AvgNumOfArticlesPerQuarter INTEGER,
  AvgNumOfArticlesPerMonth INTEGER,
  PRIMARY KEY (ISSN, JournalName)
)"
dbExecute(mysql_con, Journal_fact_table_create_query)

# Insert the fact table data
dbWriteTable(mysql_con, "JournalFacts", Journal_fact_table_data, append = TRUE, row.names = FALSE)



# close the connections to both databases
dbDisconnect(sqlite_con)
dbDisconnect(mysql_con)

