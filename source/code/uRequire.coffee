###
  processes each .js file in 'bundlePath', extracting AMD/module information
  It then tranforms each file using template to 'outputPath'
###

processBundle = (options)->
  l = require('./utils/logger')
  if not options.verbose then l.log = ->

  l.log 'process called with options\n', options

  _ = require 'lodash'
  _fs = require 'fs'
  _path = require 'path'
  _wrench = require 'wrench'
  getFiles = require "./utils/getFiles"
  template = require "./templates/UMD"
  extractModuleInfo = require "./extractModuleInfo"
  resolveDependencies = require './resolveDependencies'

  bundleFiles =  getFiles options.bundlePath, (fileName)->
    (_path.extname fileName) is '.js' #todo: make sure its an AMD module

  l.log '\nbundleFiles=', bundleFiles

  for modyle in bundleFiles
    l.log '\n', 'processing module:', modyle
    oldJs = _fs.readFileSync(options.bundlePath + '/' + modyle, 'utf-8')
    moduleInfo = extractModuleInfo(oldJs)

    if not _.isEmpty moduleInfo

      resDeps = resolveDependencies modyle, bundleFiles, moduleInfo.dependencies
      moduleInfo.dependencies = resDeps.bundleRelative
      moduleInfo.frDependencies = resDeps.fileRelative

      if resDeps.notFoundInBundle.length > 0
        l.warn """
          #{modyle} has dependencies not found in bundle:
            * #{nfib for nfib in resDeps.notFoundInBundle}
          They are added as-is.
        """

      if resDeps.external.length > 0
        l.warn """
                  #{modyle} has external dependencies:
                    * #{nfib for nfib in resDeps.external}
                  They are added as-is.
        """

      # 'require' as param
      # require is always 1st fixed (*in template) parameter of factory
      if moduleInfo.parameters[0] is 'require' #so remove it
        moduleInfo.parameters.shift() if moduleInfo.parameters[0] is 'require'

      # nodeRequire is always 1st fixed* argument when calling factory (from node!)
      if moduleInfo.frDependencies[0] is 'require' #so remove it
        moduleInfo.frDependencies.shift()

      # if there are dependencies, add 'require' as the first one
      if moduleInfo.dependencies[0] isnt 'require'
        if moduleInfo.dependencies.length > 0 # only if other deps exist (requireJS bug)
          moduleInfo.dependencies.unshift 'require'

        #l.log "'require' pseudo-parameter found on module #{modyle}, replacing it with uRequire's version."

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


makeNodeRequire = require('./makeNodeRequire')

module.exports =
  processBundle: processBundle

  # used by UMD-transformed modules, to make the node (async) require
  makeNodeRequire: makeNodeRequire
