###
  processes each .js file in 'bundlePath', extracting AMD/module information
  It then tranforms each file using template to 'outputPath'
###

processBundle = (options)->
  l = require('./utils/logger')
  if not options.verbose then l.log = ->

  l.log 'process called with options\n', options

  _ = require 'underscore'
  _fs = require 'fs'
  _path = require 'path'
  _wrench = require 'wrench'
  getFiles = require "./utils/getFiles"
  template = require "./templates/UMD"
  extractModuleInfo = require "./extractModuleInfo"
  fileRelativeDependencies = require './fileRelativeDependencies'

  bundleFiles =  getFiles options.bundlePath, (fileName)->
    (_path.extname fileName) is '.js' #todo: make sure its an AMD module

  l.log '\nbundleFiles=', bundleFiles

  for modyle in bundleFiles
    l.log '\n', 'processing module:', modyle
    oldJs = _fs.readFileSync(options.bundlePath + '/' + modyle, 'utf-8')
    moduleInfo = extractModuleInfo(oldJs)

    if not _.isEmpty moduleInfo

      if moduleInfo.dependencies[0] is 'require'
        if moduleInfo.parameters[0] is 'require'
          l.warn "'require' found on module #{modyle}, replacing it with myRequire's version."
          moduleInfo.dependencies.shift()
          moduleInfo.parameters.shift()


      moduleInfo.frDependencies = fileRelativeDependencies modyle, bundleFiles, moduleInfo.dependencies

      if options.noExports
        moduleInfo.rootExports = false #Todo:check for existence, allow more than one!

      templateInfo = _.extend moduleInfo, {
        version: options.version
        modulePath: _path.dirname modyle # module path within bundle
      }

      l.log _.pick templateInfo, 'dependencies', 'frDependencies', 'modulePath'

      newJs = template templateInfo

    else
      l.warn "Not AMD module #{modyle}, copying as-is."
      newJs = oldJs

    outputFile = _path.join options.outputPath, modyle

    if not (_fs.existsSync _path.dirname(outputFile))
      l.log "creating directory #{_path.dirname(outputFile)}"
      _wrench.mkdirSyncRecursive(_path.dirname(outputFile))

    _fs.writeFileSync outputFile, newJs, 'utf-8'

  return null # save pointless coffeescript return :-)



module.exports = {
  processBundle: processBundle

  # used by UMD-transformed modules, to make the node (async) require
  getMakeRequire: ()-> require('./makeRequire')
}
