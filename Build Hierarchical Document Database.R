### Query Document Database
###
### Author: Chen, Nan
### Course: CS5200
### Term: 2023 Spring

# assumes that you have set up the database structure by running CreateFStruct.R

# Query Parameters (normally done via a user interface)

quarter <- "Q2"
year <- "2021"
customer <- "Medix"

#get current work directory
wd <- getwd()
wd
setwd("/Users/nanchen/Documents/courses/cs5200/CS5200.BuildDocDB.Chen")
wd <- getwd()
wd

#create a lock file called ".lock" in the folder for some quarter/year  
#and some customer but only if the lock file does not yet exist. If it 
#does exist, the function should return an error code such as -1; 
#if the lock file was successfully created, it should return 0

setLock <- function(customer, year, quarter){
  lock_file_a=paste(wd, "docDB", "reports", year, quarter, customer, ".lock", sep="/")
  if(!file.exists(lock_file_a)){
    file.create(lock_file_a)
    return (0)
  }else{
    return (-1)
  }
}

#test
setLock(customer, year, quarter)

#return the correctly generated report full file file
genReportFName <- function(customer, year, quarter){
  pdf_file_name=paste(customer, year, quarter, "pdf", sep=".")
  return (pdf_file_name)
}

#test
pdf_file_name=genReportFName(customer, year, quarter)
pdf_file_name

# copy the PDF downloaded to the folder identified in QueryDocDB.
# but only if the lock file did not exists
storeReport <- function(customer, year, quarter){
  pdf_file_name = genReportFName(customer, year, quarter)
  #print(pdf_file_name)
  lock_file = paste(wd, "docDB", "reports", year, quarter, customer, ".lock", sep="/")
  #print(lock_file)
  target_folder = paste(wd, "docDB", "reports", year, quarter, customer, sep="/")
  #print(target_folder)
  if(!file.exists(lock_file)){
    file.copy(paste(".", pdf_file_name, sep="/"), target_folder, overwrite=TRUE)
  }
}

#test
storeReport(customer, year, quarter)

#remove the lock file
relLock <- function(customer, year, quarter){
  lock_file = paste(wd, "docDB", "reports", year, quarter, customer, ".lock", sep="/")
  if(file.exists(lock_file)){
    file.remove(lock_file)
  }
}

#test
relLock(customer, year, quarter)

