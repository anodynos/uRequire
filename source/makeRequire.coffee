module.exports = (basePath)->
  relativePath = require './pathRelative'
  console.log 'returning asyncRequire, for basepath = ' + basePath

  (dependencies, callback)->
    console.log 'asyncRequire called, basepath = ' + basePath
    resolvedDeps = []
    console.log 'callback = ' + callback

    for dep in dependencies
      depPath = relativePath '$bundle/' + basePath, "$bundle/" + dep, dot4Current:true
#      resolvedDeps.push require(depPath)
      resolvedDeps.push depPath

    callback.apply null, resolvedDeps

# TODO: make test specs!
#relativeAsyncRequire = makeRelativeAsynchRequire 'views/'
#relativeAsyncRequire ['views/PersonEditView', 'Models/PersonModel']