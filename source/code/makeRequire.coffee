module.exports = (basePath)->
  relativePath = require './utils/pathRelative'
#  console.log 'creating asyncRequire, for basepath = ' + basePath

  (dependencies, callback)->
#    console.log 'asyncRequire called'
#    console.log   'base/filePath =      $' + basePath
#    console.log 'callback = ' + callback

    resolvedDeps = []
    for dep in dependencies
#      depPath = relativePath '$/' + basePath, "$/" + dep, dot4Current:true
#      console.log 'dep =                $', dep
#      console.log 'resolved depPath =   ', depPath
      resolvedDeps.push require(relativePath '$/' + basePath, "$/" + dep, dot4Current:true)
    callback.apply null, resolvedDeps

# TODO: make test specs!
#relativeAsyncRequire = makeRelativeAsynchRequire 'views/'
#relativeAsyncRequire ['views/PersonEditView', 'Models/PersonModel']