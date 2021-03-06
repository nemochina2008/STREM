library(INLA)
setOldClass("inla.mesh")
setOldClass("inla.spde2")
setOldClass("inla.data.stack")
setOldClass("inla")

Model <- setRefClass(
  Class = "Model",
  fields = list(
    study = "Study",
    data = "data.frame",
    locations = "matrix",
    model = "formula",
    coordsScale = "numeric",
    years = "integer",
    result = "inla",
    modelName = "character",
    offsetScale = "numeric",
    family = "character"
  ),
  methods = list(
    initialize = function(...) {
      callSuper(...)
      return(invisible(.self))
    },
    
    setModelName = function(family, randomEffect, tag) {
      modelName <<- if (missing(tag)) paste("SmoothModel", family, randomEffect, sep="-")
      else paste("SmoothModel", family, randomEffect, tag, sep="-")
      return(invisible(.self))
    },
    
    getEstimatesFileName = function() {
      if (inherits(study, "undefinedField") | length(modelName) == 0)
        stop("Provide study and modelName parameters.")
      return(study$context$getFileName(study$context$resultDataDirectory, name=modelName, response=study$response, region=study$studyArea$region))
    },
    
    saveEstimates = function(fileName=getEstimatesFileName()) {
      stop("Unimplemented method saveEstimates.")
    },
    
    loadEstimates = function(fileName=getEstimatesFileName()) {
      message("Loading estimates from ", fileName)
      load(fileName, envir=as.environment(.self))
      return(invisible(.self))
    },
        
    getUnscaledMesh = function() {
      mesh.unscaled <- mesh
      mesh.unscaled$loc <- mesh.unscaled$loc / coordsScale
      return(mesh.unscaled)
    },
    
    getUnscaledMeshCoordinates = function() {
      return(getUnscaledMesh()$loc[,1:2])
    },
    
    getUnscaledObservationCoordinates = function() {
      return(locations / coordsScale)
    },
    
    getObservedOffset = function(distance=data$distance) {      
      return(2/pi * data$length * data$duration * distance / offsetScale)
    },
    
    setup = function(intersections, params, covariatesModel=~1, tag) {
      library(INLA)
      library(plyr)
            
      if (missing(params))
        stop("Missing params argument.")
      if (!hasMember(params, "family"))
        stop("Missing family parameter.")
      if (!hasMember(params, "timeModel"))
        stop("Missing timeModel parameter.")
      if (!inherits(intersections, "Intersections"))
        stop("Argument 'intersections' must be of class 'Intersections'.")
      coordsScale <<- if (!hasMember(params, "coordsScale")) 1 else params$coordScale
      offsetScale <<- if (!hasMember(params, "offsetScale")) 1000^2 else params$offsetScale
      family <<- if (!hasMember(params, "family")) "nbinomial" else params$family
            
      setModelName(family=family, randomEffect=params$timeModel, tag=tag)
      data <<- intersections$getData()
      data$response <<- data$intersections
      locations <<- intersections$getCoordinates() * coordsScale
      years <<- as.integer(sort(unique(data$year)))
      if (hasMember(params, "model")) model <<- params$model
      
      return(invisible(.self))      
    },
    
    estimate = function(save=FALSE, fileName=getEstimatesFileName()) {
      stop("Unimplemented method estimate.")
    },
    
    samplePosterior = function(n, index) {
      library(INLA)
      library(plyr)
      posteriorSamples <- inla.posterior.sample(n=n, result=result)
      xy <- getUnscaledObservationCoordinates()
      if (missing(index)) index <- 1:nrow(xy)
      x <- llply(posteriorSamples,
                 function(x, index) {
                   predictorIndex <- grep("Predictor\\.", rownames(x$latent)[index])
                   #data.frame(x=xy[,1], y=xy[,2], z=exp(x$latent[predictorIndex]) / offsetScale, t=data$year)
                   data.frame(x=xy[,1], y=xy[,2], z=exp(x$latent[predictorIndex]), t=data$year)
                 },
                 index=index, .parallel=F)
      return(x)
    },
        
    getLengthWeights = function(weightedLengths, lengths) {
      lengthWeights <- weightedLengths / lengths
      lengthWeights <- rep(lengthWeights, length(years))
      return(lengthWeights)
    },
    
    getDensityEstimates = function(weights=1, aggregate=F, index, year) {
      xy <- getUnscaledObservationCoordinates()
      xyzt <- data.frame(x=xy[,1], y=xy[,2], density=data$fittedMean * weights / offsetScale, year=data$year)
      if (!missing(year)) xyzt <- xyzt[xyzt$year==year,]
      if (!missing(index)) xyzt <- xyzt[index,]
      if (aggregate)
        xyzt <- ddply(xyzt, .(year), function(x) data.frame(density=mean(x$density), year=x$year[1]))
      return(xyzt)
    },
    
    getPopulationDensity = function(templateRaster=study$getTemplateRaster(), maskPolygon=study$studyArea$boundary, habitatWeights=NULL, index, year, .parallel=TRUE) {
      if (is.null(data$fittedMean))
        stop("Did you forgot to run collectEstimates() first?")
      library(raster)
      
      effortWeights <- if (!is.null(habitatWeights)) {
        if (inherits(study$surveyRoutes, "uninitializedField"))
          stop("You specified habitat weights but survey routes are not available for effort weighting.")
        weightedLengths <- study$surveyRoutes$getWeightedLengths(habitatWeights)
        getLengthWeights(weightedLengths, study$surveyRoutes$lengths)
      }
      else 1
      
      meanPopulationDensity <- getDensityEstimates(weights=1/effortWeights, aggregate=TRUE, index=index, year=year)
      cellArea <- prod(res(templateRaster))
      meanPopulationDensityRaster <- SpatioTemporalRaster(study=study)$fill(z=meanPopulationDensity$density, layerNames=meanPopulationDensity$year, weights=cellArea, .parallel=.parallel)
      #meanPopulationDensityRaster <- SpatioTemporalRaster(study=study)$fill(z=meanPopulationDensity$density, boundary=maskPolygon, layerNames=meanPopulationDensity$year, weights=cellArea, .parallel=.parallel)
      
      return(invisible(meanPopulationDensityRaster))
    },
    
    getPopulationSize = function(populationDensity, habitatWeightsRaster=NULL) {
      stop("Unimplemented method.")
    }
  )
)

DEPRECATED_AggregatedModel <- setRefClass(
  Class = "AggregatedModel",
  contains = "Model",
  fields = list(
  ),
  methods = list(
    aggregate = function() {
      library(plyr)
      data <<- ddply(data, .(year), function(x) {
        data.frame(response=sum(x$response), intersections=sum(x$intersections), duration=1, length=sum(x$duration*x$length*x$distance), distance=1)
      })      
    },
    
    samplePosterior = function(n, index) {
      library(INLA)
      library(plyr)
      posteriorSamples <- inla.posterior.sample(n=n, result=result)
      if (missing(index)) index <- 1:nrow(data)
      x <- llply(posteriorSamples,
                 function(x, index, years) {
                   predictorIndex <- grep("Predictor\\.", rownames(x$latent)[index])
                   data.frame(z=exp(x$latent[predictorIndex]), t=years)
                 },
                 index=index, years=data$year, .parallel=F)
      return(x)
    },
        
    getLengthWeights = function(weightedLengths, lengths) {
      lengthWeights <- sum(weightedLengths) / sum(lengths)
      lengthWeights <- rep(lengthWeights, length(years))
      return(lengthWeights)
    }
    
    #getDensityEstimates = function(weights=1, aggregate=F, index) {
    #  return(data.frame(density=data$fittedMean * weights / offsetScale, year=data$year))
    #}
    
    
    #getPopulationDensity = function(templateRaster=study$getTemplateRaster(), maskPolygon=study$studyArea$boundary, getSD=FALSE) {
    #  warning("Population density unavailable.")
    #  return(list(mean=NA, SD=NA))
    #},
    
    # TODO: Support for custom areas
    #getPopulationSize = function(populationDensity, tracks, habitatWeights) {
    #  if (is.null(data$fittedMean))
    #    stop("Did you forgot to run collectEstimates() first?")
    #  if (length(unique(data$year)) != nrow(data))
    #    stop("The data must be aggregated to determine population size")
    #  area <- if (missing(habitatWeights) || is.null(habitatWeights)) study$studyArea$boundary@polygons[[1]]@area
    #  else cellStats(habitatWeights, sum) * prod(res(habitatWeights))
    #  populationSize <- SimulationPopulationSize(study=study, modelName=modelName, iteration=iteration)
    #  
    #  for (y in sort(data$year)) {
    #    size <- subset(data, year == y)$fittedMean * area / offsetScale
    #    populationSize$addYearSize(y, size)
    #  }        
    #  
    #  if (missing(tracks)) populationSize$loadValidationData()
    #  else populationSize$loadValidationData(tracks=tracks)
    #  
    #  return(populationSize)
    #}
  )
)

