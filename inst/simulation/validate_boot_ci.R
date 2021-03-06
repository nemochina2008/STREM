#library(devtools); install_github("statguy/Winter-Track-Counts")
library(parallel)
library(doMC)
registerDoMC(cores=round(detectCores()))
library(STREM)
source("~/git/STREM/setup/WTC-Boot.R")
library(plyr)
#library(reshape2)
library(boot)

parseArguments()
modelName <- extraArgs[1]
iteration <- as.integer(task_id)
if (F) {
modelName <- "FMPModel"
scenario <- "A"
iteration <- as.integer(1)
scenario <- "E"
iteration <- as.integer(10)
}
mss <- getMSS(scenario=scenario)
study <- mss$study
context <- study$context
validation <- Validation(study=study, populationSizeCutoff=Inf)

nSamples <- 100

model <- study$getModel(modelName=modelName, iteration=iteration)
model$loadEstimates()
model$collectEstimates()
fitted <- model$getDensityEstimates()

#t <- length(model$years)
#n <- nrow(fitted) / t
#fitted$id <- rep(1:n, times=t)
#fitted <- dcast(fitted, year ~ id, value.var="density")

getPopulationSize <- function(fitted, index, year, model, readHabitatIntoMemory) {
  populationSize <- study$getPopulationSize(model, index=index, year=year, readHabitatIntoMemory=readHabitatIntoMemory, loadValidationData=F, save=F)
  #print(populationSize)
  return(populationSize$sizeData$Estimated)
}

findCI <- function(fitted, iteration, model, modelName) {
  populationSize <- study$loadPopulationSize(iteration, modelName)
  
  # x <- subset(fitted, year==2001)
  b <- ddply(fitted, .(year), function(x, iteration, model, populationSize) {
    message("Resampling year ", x$year[1], "...")
    year <- as.integer(x$year[1])
    true <- subset(populationSize$sizeData, Year == year)$Observed
    b <- boot(data=x$density, statistic=getPopulationSize, R=1000, year=year, model=model, readHabitatIntoMemory=F, parallel="multicore")
    #ci95 <- quantile(b$t, c(.025,.975))
    #ci50 <- quantile(b$t, c(.25,.75))
    bci <- try(boot.ci(b, conf=c(.95, .50), type=c("bca")))
    if (!(is.null(bci) | inherits(bci, "try-error"))) {
      ci95 <- bci$bca[1,4:5]
      ci50 <- bci$bca[2,4:5]
      p95 <- ci95[1] <= true & ci95[2] >= true
      p50 <- ci50[1] <= true & ci50[2] >= true
      return(data.frame(year=year, p95=p95, p50=p50))
    }
    else return(data.frame(year=year, p95=NA, p50=NA))
  }, iteration=iteration, model=model, populationSize=populationSize)
  return(b)
}

bootCI <- llply(1:nSamples, function(i) {
  message("Resampling ", i, "/", nSamples, "...")
  return(findCI(fitted, iteration, model, modelName))
}, .parallel=F)

bootCI <- do.call(rbind, bootCI)
save(bootCI, file=validation$getCredibilityIntervalsValidationFileName(modelName=modelName, iteration=iteration))

if (F) {
  modelName <- "FMPModel"
  scenario <- "A"
  mss <- getMSS(scenario=scenario)
  study <- mss$study
  validation <- Validation(study=study, populationSizeCutoff=Inf)
  iterations <- validation$getCredibilityIntervalsValidationIterations(modelName)
  p95 <- c()
  p50 <- c()
  for (i in iterations) {
    load(file=validation$getCredibilityIntervalsValidationFileName(modelName=modelName, iteration=i))
    p95 <- c(p95, bootCI$p95)
    p50 <- c(p50, bootCI$p50)
  }
  mean(p95, na.rm=T)
  mean(p50, na.rm=T)
}
