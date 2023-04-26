if (!require("XML")) {
  install.packages("XML")
}
if (!require("RSQLite")) {
  install.packages("RSQLite")
}
if (!require("DBI")) {
  install.packages("DBI")
}
if (!require("knitr")) {
  install.packages("knitr")
}
if (!require("data.table")) {
  install.packages("data.table")
}
if (!require("stringr")) {
  install.packages("stringr")
}
if (!require("dplyr")) {
  install.packages("dplyr")
}

library(XML)
library(RSQLite)
library(DBI)
library(knitr)
library(data.table)
library(stringr)
library(dplyr)



# Create a new SQLite database
getwd()
fpath <- getwd()
fn <- "/pubmed-tfm-xml/pubmed22n0001-tf.xml"
fpn <- paste0(fpath, fn)
dbfile <- "Practicum.sqlite"
con <- dbConnect(RSQLite::SQLite(), paste0(fpath, dbfile))

# Create the Articles table
dbExecute(con, "
CREATE TABLE IF NOT EXISTS Articles (
  PMID INTEGER PRIMARY KEY,
  JournalID INTEGER,
  ArticleTitle TEXT,
  FOREIGN KEY (JournalID) REFERENCES Journals(JournalID)
)")

# Create the Journals table
dbExecute(con, "
CREATE TABLE IF NOT EXISTS Journals (
  JournalID INTEGER PRIMARY KEY,
  ISSN TEXT,
  Title TEXT,
  PubDate TEXT,
  Year TEXT,
  Month TEXT,
  Quarter TEXT
)")

# Create the Authors table
dbExecute(con, "
CREATE TABLE IF NOT EXISTS Authors (
  AuthorID INTEGER PRIMARY KEY,
  LastName TEXT,
  ForeName TEXT,
  Initials TEXT
)")

# Create the Article_Author table
dbExecute(con, "
CREATE TABLE IF NOT EXISTS Article_Author (
  PMID INTEGER,
  AuthorID INTEGER,
  PRIMARY KEY (PMID, AuthorID),
  FOREIGN KEY (PMID) REFERENCES Articles(PMID),
  FOREIGN KEY (AuthorID) REFERENCES Authors(AuthorID)
)")

# Reading the XML file and parse into DOM
xmlDOM <- xmlParse(file = fpn)

# get the root node of the DOM tree
r <- xmlRoot(xmlDOM)

# get number of children of root (number of articles)
numArticle <- xmlSize(r)

#Parses the Journal XML node in _anJournalNode_ and returns it in a one row data frame.
parseJournal <- function (anJournalNode) {
  
  # parse the Journal into its components
  # Extract ISSN
  ISSN_node <- xpathSApply(anJournalNode, ".//ISSN")
  if (length(ISSN_node) > 0) {
    ISSN <- xmlValue(ISSN_node[[1]])
  } else {
    ISSN <- NA
  }
  
  JournalIssue_node <- xpathSApply(anJournalNode, ".//JournalIssue")
  
  # Extract PubDate
  Year <- xpathSApply(JournalIssue_node[[1]], ".//Year", xmlValue)
  if (length(Year) == 0)
    Year <- NULL
  Month <- xpathSApply(JournalIssue_node[[1]], ".//Month", xmlValue)
  if (length(Month) == 0)
    Month <- NULL
  MedlineDate <- xpathSApply(JournalIssue_node[[1]], ".//MedlineDate", xmlValue)
  if (length(MedlineDate) == 0)
    MedlineDate <- NULL
  
  # Get PubDate, Year, Month, Quarter for each Journal
  result <- convert_date(Year, Month, MedlineDate)
  PubDate <- result[[1]]
  Year <- result[[2]]
  Month <- result[[3]]
  Quarter <- result[[4]]
  
  # Extract Title 
  Title <- xpathSApply(anJournalNode, ".//Title", xmlValue)
  
  newJournal.df <- data.frame(ISSN, Title, PubDate, Year, Month, Quarter, 
                              stringsAsFactors = F)
  
  return(newJournal.df)
}

#Parses the AuthorList XML node in _anAuthorListNode_ 
parseAuthorList <- function (anAuthorListNode)
{
  newAuthorList.df <- data.frame(LastName = character(),
                                 ForeName = character(),
                                 Initials = character(),
                                 stringsAsFactors = F)
  
  if (length(anAuthorListNode) == 0) {
    return(newAuthorList.df)
  }
  
  n <- xmlSize(anAuthorListNode)
  
  # extract each of the <Author> nodes under <AuthorList>
  for (m in 1:n)
  {
    anAuthor <- anAuthorListNode[[m]]
    # extract first child nodes that are always present 
    # extract LastName/ForeName/Initials for each author
    LastName <- xmlValue(anAuthor[[1]])
    ForeName <- xpathSApply(anAuthor, "./ForeName", xmlValue)
    if (length(ForeName) == 0)
      ForeName <- " "
    Initials <- xpathSApply(anAuthor, "./Initials", xmlValue)
    if (length(Initials) == 0)
      Initials <- " "
    
    newAuthorList.df[m,1] <- LastName
    newAuthorList.df[m,2] <- ForeName
    newAuthorList.df[m,3] <- Initials
  }
  
  return(newAuthorList.df)
}

# Takes a single input month which should be a three-letter abbreviation of 
# a month (e.g., "Jan", "Feb", "Mar", etc.). The function then returns the 
# corresponding quarter of the year (1, 2, 3, or 4) for the given month. 
convert_quarter <- function(month){
  month_names <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  month_number <- match(month, month_names)
  return(ceiling(month_number / 3))
}

# Takes three input arguments: year, month, and MedlineDate. 
# The function processes the input data and returns a list containing four 
# elements: a date string, year, month, and quarter. 
convert_date <- function(year, month, MedlineDate) {
  if(is.null(MedlineDate)){
    if (is.null(year)) {
      return(NA)
    }
    
    if (is.null(month)) {
      month <- " "
      quarter <- " "
    }else{
      quarter <- convert_quarter(month)
    }
    
    result <- list(paste(year, month, sep = " "), year, month, quarter)
    return(result)
  }else{
    date <- substr(MedlineDate, 1, 8)
    year <- substr(MedlineDate, 1, 4)
    month <- substr(MedlineDate, 6, 8)
    quarter <- convert_quarter(month)
    result <- list(date, year, month, quarter)
    return(result)
  }
}


# iterate over the first-level child elements off the root:
# the <Article> elements
index <- 1
authorsArr = list() 
journalsArr = list() 
articlesArr = list()
AuthorID<-0

for (i in 1:numArticle)
{
  # get next Article node
  anArticleNode <- r[[i]]
  
  # Extract the Journal node
  # Extract the ArticleTitle node
  # check if Journal node and ArticleTitle node exits, if not, then go to next node.
  journal_node_set <- xpathSApply(anArticleNode, "./PubDetails/Journal")
  article_title_node_set <- xpathSApply(anArticleNode, "./PubDetails/ArticleTitle")
  
  if ((length(journal_node_set) == 0 |length(article_title_node_set) == 0)) {
      next
  }else{
  
    # parse Journal
    journal_node <- journal_node_set[[1]]
    Journal <- parseJournal(journal_node)
    ISSN = Journal$ISSN
    Title = Journal$Title 
    PubDate = Journal$PubDate 
    Year = Journal$Year
    Month = Journal$Month
    Quarter = Journal$Quarter 
    JournalID = length(journalsArr) + 1
    dfJr <- data.frame("JournalID"=JournalID,"ISSN"=ISSN,"Title"=Title, 
                       "PubDate"=PubDate, "Year"=Year, "Month"=Month, "Quarter"=Quarter) 
    journalsArr[[JournalID]] <- dfJr
    
    # Extract PMID
    PMID <- as.integer(xmlAttrs(anArticleNode)["PMID"])
    # Extract ArticleTitle
    article_title_node <- article_title_node_set[[1]]
    ArticleTitle <- xmlValue(article_title_node)
    dfArticle <- data.frame("PMID"=PMID,"ArticleTitle"=ArticleTitle, "JournalID"=JournalID) 
    articlesArr[[index]] <- dfArticle

    # Extract the AuthorList node
    author_list_node_set <- xpathSApply(anArticleNode, "./PubDetails/AuthorList")
    if (length(author_list_node_set) > 0) {
      # get AuthorList node
      author_list_node <- author_list_node_set[[1]]
      # process the set of authorlists into a separate data frame
      article_Authors <- parseAuthorList(author_list_node)
      # Check if article_Authors is not empty
      if (nrow(article_Authors) > 0) {
        article_authors_list <- list()
        for (n in 1:nrow(article_Authors))
        {
          author <- article_Authors[n, ]
          LastName = author$LastName
          ForeName = author$ForeName 
          Initials = author$Initials
          AuthorID = AuthorID + 1
          dfAuthor <- data.frame("AuthorID"=AuthorID,
                             "LastName"=LastName,
                             "ForeName"=ForeName, 
                             "Initials"=Initials) 
          # Append the dfAuthor to the article_authors_list
          article_authors_list <- append(article_authors_list, list(dfAuthor))
        }
        # Append the article_authors_list to the authorsArr
        authorsArr[[index]] <- article_authors_list
      }
      else{
        authorsArr[[index]] <- NULL
      }
    } else{
      authorsArr[[index]] <- NULL
    }
    
    index <- index+1
  }
  
}
# combines all data frames in the authorsArr list into a single data frame 
flattened_authorsArr <- do.call(c, lapply(authorsArr, c))
author_Df <- data.table::rbindlist(flattened_authorsArr)
#removes duplicate rows from the author_Df data frame
distinct_author_Df <- distinct(author_Df, LastName, ForeName, Initials, .keep_all = TRUE)

# combines all data frames in the journalsArr list into a single data frame 
Journal_df <- data.table::rbindlist(journalsArr)
#removes duplicate rows from the Journal_df data frame
distinct_Journal_df <- distinct(Journal_df, Title, ISSN, PubDate, .keep_all = TRUE)


articlesAuthorsArr = list()
for (i in 1:length(articlesArr)) {
  # Get the current article data frame
  article_df <- articlesArr[[i]]
  
  # Extract the ISSN, Title, and PubDate from the article data frame
  PM_ID <- article_df$PMID
  Journal_ID <- article_df$JournalID
  
  # Find the corresponding journal in Journal_df
  journal_info <- Journal_df[Journal_df$JournalID == Journal_ID, c("ISSN", "Title", "PubDate")]

  # Get the correct JournalID from distinct_Journal_df based on the ISSN, Title, and PubDate
  matching_row_index <- which((distinct_Journal_df$ISSN == journal_info$ISSN | (is.na(distinct_Journal_df$ISSN) & is.na(journal_info$ISSN))) &
                                (distinct_Journal_df$Title == journal_info$Title | (is.na(distinct_Journal_df$Title) & is.na(journal_info$Title))) &
                                (distinct_Journal_df$PubDate == journal_info$PubDate | (is.na(distinct_Journal_df$PubDate) & is.na(journal_info$PubDate))))
  
  correct_journal <- distinct_Journal_df[matching_row_index,]
  
  # Update the JournalID in the article data frame
  article_df$JournalID <- correct_journal$JournalID
  
  # Replace the current article data frame in articlesArr with the updated one
  articlesArr[[i]] <- article_df
  
  if (length(authorsArr[[i]]) > 0){
    article_authors_df_list <- authorsArr[[i]]
    for (i in 1:length(article_authors_df_list)) {
      current_df <- article_authors_df_list[[i]]
      # Get the correct AuthorID from distinct_Journal_df based on the LastName, ForeName, and Initials
      matched_row <- which((distinct_author_Df$LastName == current_df$LastName | (is.na(distinct_author_Df$LastName) & is.na(current_df$LastName))) &
                             (distinct_author_Df$ForeName == current_df$ForeName | (is.na(distinct_author_Df$ForeName) & is.na(current_df$ForeName))) &
                             (distinct_author_Df$Initials == current_df$Initials | (is.na(distinct_author_Df$Initials) & is.na(current_df$Initials))))
      
      correct_row <- distinct_author_Df[matched_row,]
      Author_ID <- correct_row$AuthorID
      articlesAuthorsArrID = length(articlesAuthorsArr) + 1
      # Update the AuthorID in the ArticleAuthor data frame
      dfArticleAuthor <- data.frame("PMID"=PM_ID,"AuthorID"=Author_ID)
      articlesAuthorsArr[[articlesAuthorsArrID]] <- dfArticleAuthor
    }
  }
  
  
}
# combines all data frames in the articlesArr list into a single data frame 
article_Df <- data.table::rbindlist(articlesArr)
# combines all data frames in the articlesAuthorsArr list into a single data frame 
articles_Authors_Df <- data.table::rbindlist(articlesAuthorsArr)
#removes duplicate rows from the articles_Authors_Df data frame
distinct_articles_Authors_Df <- distinct(articles_Authors_Df, PMID, AuthorID, .keep_all = TRUE)

# Write the unique data.tables to the tables in the database
dbWriteTable(con, "Articles", article_Df, append=T)
dbWriteTable(con, "Journals", distinct_Journal_df, append=T)
dbWriteTable(con, "Authors", distinct_author_Df, append=T)
dbWriteTable(con, "Article_Author", distinct_articles_Authors_Df, append=T)


