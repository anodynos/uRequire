###
  processes each .js file in 'bundlePath', extracting AMD/module information
  It then tranforms each file using template to 'outputPath'
###

processBundle = (options)->
  l = require('./utils/logger')
  if not options.verbose then l.verbose = ->

  l.verbose 'uRequire called with options\n', options

  _ = require 'lodash'
  _fs = require 'fs'
  _path = require 'path'
  _wrench = require 'wrench'
  getFiles = require "./utils/getFiles"
  template = require "./templates/UMD"
  AMDModuleManipulator = require "./moduleManipulation/AMDModuleManipulator"
  resolveDependencies = require './resolveDependencies'
  resolveWebRoot = require './resolveWebRoot'
  DependencyReporter = require './DependencyReporter'

  interestingDepTypes = ['notFoundInBundle', 'untrustedRequireDependencies', 'untrustedAsyncDependencies']
  reporter = new DependencyReporter(if options.verbose then null else interestingDepTypes )

  bundleFiles =  getFiles options.bundlePath, (fileName)->
    (_path.extname fileName) is '.js' #todo: make sure its an AMD module

  l.verbose '\nBundle files found: \n', bundleFiles

  for modyle in bundleFiles
    l.verbose '\nProcessing module: ', modyle

    oldJs = _fs.readFileSync(options.bundlePath + '/' + modyle, 'utf-8')

    moduleManipulator = new AMDModuleManipulator oldJs, beautify:true
    moduleInfo = moduleManipulator.extractModuleInfo()

    if _.isEmpty moduleInfo
      l.warn "Not AMD module '#{modyle}', copying as-is."
      newJs = oldJs
    else # we have a module
      if moduleInfo.untrustedDependencies
        l.err "Module '#{modyle}', has untrusted deps #{d for d in moduleInfo.untrustedDependencies}: copying as-is."
        newJs = oldJs
      else
        moduleInfo.parameters ?= [] #default
        moduleInfo.dependencies ?= [] #default

        # In the UMD template 'require' is *fixed*, so remove it
        for pd in [moduleInfo.parameters, moduleInfo.dependencies]
          pd.shift() if pd[0] is 'require'

        requireReplacements = {} # the final replacements for require() calls.
                                # All original deps and their fileRelative counterpart
        [ resDeps,
          resReqDeps,
          resAsyncReqDeps ] = for deps in [
               moduleInfo.dependencies,
               moduleInfo.requireDependencies,
               moduleInfo.asyncDependencies
              ]
                resolvedDeps = resolveDependencies modyle, bundleFiles, deps
                if not _(deps).isEmpty()
                  for dep, idx in deps when not (dep is resolvedDeps.fileRelative[idx])
                    requireReplacements[dep] = resolvedDeps.fileRelative[idx]
                resolvedDeps

#        l.log '\n', requireReplacements
        _(moduleInfo).extend moduleManipulator.getModuleInfoWithReplacedFactoryRequires(requireReplacements)

        arrayDeps = _.clone resDeps.fileRelative
        arrayDeps.push reqDep for reqDep in _.difference(resReqDeps.fileRelative, arrayDeps)

        templateInfo = #
          version: options.version
          modulePath: _path.dirname modyle # module path within bundle
          webRoot: resolveWebRoot modyle, options.webRootMap
          arrayDependencies: arrayDeps
          nodeDependencies: if options.allNodeRequires then arrayDeps else resDeps.fileRelative
          parameters: moduleInfo.parameters || []
          factoryBody: moduleInfo.factoryBody[1..moduleInfo.factoryBody.length-2] #drop '{' & '}'

        if (not options.noExport) and moduleInfo.rootExport
          templateInfo.rootExport = moduleInfo.rootExport

        #some reporting
        for repData in [ resDeps, resReqDeps, resAsyncReqDeps, (_.pick moduleInfo, interestingDepTypes) ]
          reporter.addReportData repData, modyle

#        l.verbose 'Template params (main):\n', _.omit templateInfo, 'version', 'modulePath', 'type', 'factoryBody'

        newJs = template templateInfo

    outputFile = _path.join options.outputPath, modyle

    if not (_fs.existsSync _path.dirname(outputFile))
      l.verbose "creating directory #{_path.dirname(outputFile)}"
      _wrench.mkdirSyncRecursive(_path.dirname(outputFile))

    _fs.writeFileSync outputFile, newJs, 'utf-8'

  if not _.isEmpty(reporter.reportData)
    l.log '\n########### uRequire, final report ########### :\n', reporter.getReport()

  return null # save pointless coffeescript return :-)

module.exports =
  processBundle: processBundle

  # used by UMD-transformed modules, to make the node (async) require
  makeNodeRequire: require('./makeNodeRequire')
