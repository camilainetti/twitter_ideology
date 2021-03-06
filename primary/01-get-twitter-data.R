#==============================================================================
# 01-get-twitter-data.R
# Purpose: download list of Twitter followers of politicians from Twitter API
# Details: follower lists are stored in 'outfolder' as .Rdata files
# Author: Pablo Barbera
#==============================================================================

# setup
library(tweetscores)
setwd("~/git/twitter_ideology/primary")
outfolder <- 'data/followers_lists/'
oauth_folder <- '~/Dropbox/credentials/twitter'

## scraping list of social media accounts for Members of the US Congress
## from 'unitedstates' GitHub account
congress <- scrapeCongressData()
write.csv(congress, file='data/congress-social-media.csv', row.names=FALSE)

## preparing to download follower lists
accounts <- congress$twitter[!is.na(congress$twitter)]

## adding primary candidates

# DEMOCRATS: Hillary Clinton, Bernie Sanders, Martin O'Malley, 
# Lincoln Chafee, Jim Webb
dems <- c('HillaryClinton', 'SenSanders', "GovernorOMalley",
    "LincolnChafee", "JimWebbUSA")

# Ben Carson, Ted Cruz, Carly Fiorina, Lindsey Graham,
# Mike Huckabee, George Pataki, Rand Paul, Marco Rubio,
# Rick Santorum, Bobby Jindal, Rick Perry, Donald Trump,
# Jeb Bush, Chris Christie, John Kasich, Scott Walker,
reps <- c("RealBenCarson", "tedcruz", "CarlyFiorina", "GrahamBlog", 
    "GovMikeHuckabee", "GovernorPataki", "RandPaul", "marcorubio", 
    "RickSantorum", "bobbyjindal", "GovernorPerry", "realDonaldTrump",
    "JebBush", "GovChristie", "JohnKasich", "ScottWalker")

# adding also major media outlets in the US to help w/estimation
media <- c("EconUS", "BBCWorld", "nprnews", "NewsHour", "WSJ", "ABC", 
    "CBSNews", "NBCNews", "CNN", "USATODAY", "theblaze", "nytimes", 
    "washingtonpost", "msnbc", "GuardianUS", "Bloomberg", "NewYorker", 
    "politico", "YahooNews", "FoxNews", "MotherJones", "Slate", "BreitbartNews", 
    "HuffPostPol", "StephenAtHome", "thinkprogress", "TheDailyShow", 
    "DRUDGE_REPORT", "dailykos", "seanhannity", "ajam", "edshow", 
    "glennbeck", "rushlimbaugh", "BuzzFeedPol")

accounts <- unique(c(accounts, dems, reps, media, "POTUS"))

## downloading user data
users <- getUsersBatch(screen_names=accounts, oauth_folder=oauth_folder)
names(users)[names(users)=="name"] <- "twitter_name"

## merging with congress data
users$twitter <- tolower(users$screen_name)
congress$twitter <- tolower(congress$twitter)
congress$type <- "Congress"
users <- merge(users, congress, by="twitter", all.x=TRUE)
users$party[users$twitter %in% tolower(reps)] <- "Republican"
users$party[users$twitter %in% tolower(dems)] <- "Democrat"
users$type[users$twitter %in% tolower(c(dems, reps))] <- "Primary Candidate"
users$type[users$twitter %in% tolower(media)] <- "Media Outlets"
users$type[users$twitter == "potus"] <- "Pres. Obama"

table(users$type, exclude=NULL)
table(users$party, exclude=NULL)

write.csv(users, file='data/accounts-twitter-data.csv',
    row.names=FALSE)

## keeping only accounts with 1000+ followers
accounts <- users$screen_name[users$followers_count>1000]

# first check if there's any list of followers already downloaded to 'outfolder'
accounts.done <- gsub(".rdata", "", list.files(outfolder))
accounts.left <- accounts[accounts %in% accounts.done == FALSE]
accounts.left <- accounts.left[!is.na(accounts.left)]

# loop over the rest of accounts, downloading follower lists from API
while (length(accounts.left) > 0){

    # sample randomly one account to get followers
    #new.user <- sample(accounts.left, 1)
    new.user <- accounts.left[1]
    cat(new.user, "---", users$followers_count[users$screen_name==new.user], 
        " followers --- ", length(accounts.left), " accounts left!\n")    
    
    # download followers (with some exception handling...) 
    error <- tryCatch(followers <- getFollowers(screen_name=new.user,
        oauth_folder=oauth_folder, sleep=0.5, verbose=FALSE), error=function(e) e)
    if (inherits(error, 'error')) {
        cat("Error! On to the next one...")
        next
    }
    
    # save to file and remove from lists of "accounts.left"
    file.name <- paste0(outfolder, new.user, ".rdata")
    save(followers, file=file.name)
    accounts.left <- accounts.left[-which(accounts.left %in% new.user)]

}



