###
  processes each .js file in 'bundlePath', extracting AMD/module information
  It then tranforms each file using template to 'outputPath'
###

processBundle = (options)->
  l = require('./utils/logger')
  if not options.verbose then l.log = ->

  l.log 'uRequire called with options\n', options

  _ = require 'lodash'
  _fs = require 'fs'
  _path = require 'path'
  _wrench = require 'wrench'
  getFiles = require "./utils/getFiles"
  template = require "./templates/UMD"
  extractModuleInfo = require "./extractModuleInfo"
  resolveDependencies = require './resolveDependencies'
  resolveWebRoot = require './resolveWebRoot'

  bundleFiles =  getFiles options.bundlePath, (fileName)->
    (_path.extname fileName) is '.js' #todo: make sure its an AMD module

  l.log 'Bundle files found: \n', bundleFiles

  for modyle in bundleFiles
    l.log 'Processing module: ', modyle

    oldJs = _fs.readFileSync(options.bundlePath + '/' + modyle, 'utf-8')
    moduleInfo = extractModuleInfo oldJs, {beautifyFactory:true, extractRequires:true}

    if _.isEmpty moduleInfo
      l.warn "Not AMD module #{modyle}, copying as-is."
      newJs = oldJs
    else # we have a module

      # 'require' is always 1st fixed parameter (in template) of params in factoryFunction and define([]). The nodecall also has nodeRequire
      if moduleInfo.parameters[0] is 'require' #so remove it
        moduleInfo.parameters.shift()
      if moduleInfo.dependencies[0] is 'require'
        moduleInfo.dependencies.shift()

      resDeps = resolveDependencies modyle, bundleFiles, moduleInfo.dependencies
      moduleInfo.dependencies = resDeps.bundleRelative
      moduleInfo.nodeDependencies = resDeps.fileRelative


      if resDeps.notFoundInBundle.length > 0
        l.warn """
          #{modyle} has bundle-looking dependencies not found in bundle:
            * #{nfib for nfib in resDeps.notFoundInBundle}
          They are added as-is.
        """
      if resDeps.external.length > 0
        l.warn """
          #{modyle} has external dependencies (not checked in #{options.version}):
            * #{nfib for nfib in resDeps.external}
           They are added as-is.
        """

      moduleInfo.webRoot = resolveWebRoot modyle, options.webRootMap

      if options.noExports
        moduleInfo.rootExports = false #Todo:check for existence, allow more than one?

      templateInfo = _.extend moduleInfo,
        version: options.version
        modulePath: _path.dirname modyle # module path within bundle

      l.log _.pick templateInfo, 'dependencies', 'requireDependencies', 'nodeDependencies', 'webRoot', 'modulePath'

      newJs = template templateInfo


    outputFile = _path.join options.outputPath, modyle

    if not (_fs.existsSync _path.dirname(outputFile))
      l.log "creating directory #{_path.dirname(outputFile)}"
      _wrench.mkdirSyncRecursive(_path.dirname(outputFile))

    _fs.writeFileSync outputFile, newJs, 'utf-8'

  return null # save pointless coffeescript return :-)


makeNodeRequire = require('./makeNodeRequire')

module.exports =
  processBundle: processBundle

  # used by UMD-transformed modules, to make the node (async) require
  makeNodeRequire: makeNodeRequire
