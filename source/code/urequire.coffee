###
  processes each .js file in 'bundlePath', extracting AMD/module information
  It then tranforms each file using template to 'outputPath'
###

processBundle = (options)->
  l = require('./utils/logger')
  if not options.verbose then l.verbose = ->

  l.verbose 'urequire called with options\n', options

  _ = require 'lodash'
  _fs = require 'fs'
  _path = require 'path'
  _wrench = require 'wrench'
  getFiles = require "./utils/getFiles"
  template = require "./templates/UMD"
  AMDModuleManipulator = require "./moduleManipulation/AMDModuleManipulator"
  resolveDependencies = require './resolveDependencies'
  resolveWebRoot = require './resolveWebRoot'
  DependenciesReporter = require './DependenciesReporter'

  interestingDepTypes = ['notFoundInBundle', 'untrustedRequireDependencies', 'untrustedAsyncDependencies']
  reporter = new DependenciesReporter(if options.verbose then null else interestingDepTypes )

  bundleFiles =  getFiles options.bundlePath, (fileName)-> (_path.extname fileName) is '.js'

  l.verbose '\nBundle files found: \n', bundleFiles

  for modyle in bundleFiles
    l.verbose '\nProcessing module: ', modyle

    oldJs = _fs.readFileSync(options.bundlePath + '/' + modyle, 'utf-8')

    moduleManipulator = new AMDModuleManipulator oldJs, beautify:true
    moduleInfo = moduleManipulator.extractModuleInfo()

    if _.isEmpty moduleInfo
      l.warn "Not AMD/node module '#{modyle}', copying as-is."
      newJs = oldJs
    else if moduleInfo.moduleType is 'UMD'
        l.warn "Already UMD module '#{modyle}', copying as-is."
        newJs = oldJs
    else if moduleInfo.untrustedArrayDependencies
        l.err "Module '#{modyle}', has untrusted deps #{d for d in moduleInfo.untrustedDependencies}: copying as-is."
        newJs = oldJs
    else
      moduleInfo.parameters ?= [] #default
      moduleInfo.arrayDependencies ?= [] #default

      #remove reduntant parameters (those in excess of the arrayDeps),
      # requireJS doesn't like them if require is 1st param
      if _(moduleInfo.arrayDependencies).isEmpty()
        moduleInfo.parameters = []
      else
        moduleInfo.parameters = moduleInfo.parameters[0..moduleInfo.arrayDependencies.length-1]

      # 'require' & associates are *fixed* in UMD template (if needed), so remove 'require'
      for pd in [moduleInfo.parameters, moduleInfo.arrayDependencies]
        pd.shift() if pd[0] is 'require'

      requireReplacements = {} # final replacements for require() calls.
      # Go throught all original deps & resolve their fileRelative counterpart.
      # resolvedDeps stored as a <code>Dependency<code> object
      [ resDeps,      # Store resolvedDeps as res'DepType'
        resReqDeps,
        resAsyncReqDeps ] = for strDepsArray in [
             moduleInfo.arrayDependencies,
             moduleInfo.requireDependencies,
             moduleInfo.asyncDependencies
            ]
              resolvedDeps = resolveDependencies modyle, bundleFiles, strDepsArray
              if not _(strDepsArray).isEmpty()
                for strDep, idx in strDepsArray when not (strDep is resolvedDeps.fileRelative[idx].toString())
                  requireReplacements[strDep] = resolvedDeps.fileRelative[idx].toString()
              resolvedDeps

      moduleInfo.factoryBody = moduleManipulator.getFactoryWithReplacedRequires requireReplacements

      arrayDeps = _.clone resDeps.fileRelative
      # load ALL require('dep') fileRelative deps on AMD if there is one-or-more OR we want to scanPrevent)
      # RequireJs disables runtime scan if even one dep exists in [].
      # Execution stucks on require('dep') if its not loaded (i.e not present in arrayDeps). see https://github.com/jrburke/requirejs/issues/467
      if (not _(arrayDeps).isEmpty()) or options.scanPrevent
        for reqDep in resReqDeps.fileRelative
          if not ( _(arrayDeps).any (ad)-> _.isEqual ad, reqDep ) and
             not (reqDep.pluginName is 'node')
              arrayDeps.push reqDep

      templateInfo = #
        version: options.version
        moduleType: moduleInfo.moduleType
        modulePath: modyle # full module path within bundle
        webRoot: resolveWebRoot modyle, options.webRootMap
        arrayDependencies: arrayDeps
        nodeDependencies: if options.allNodeRequires then arrayDeps else resDeps.fileRelative
        parameters: moduleInfo.parameters
        factoryBody: moduleInfo.factoryBody

      if (not options.noExport) and moduleInfo.rootExport
        templateInfo.rootExport = moduleInfo.rootExport

      #some reporting
      for repData in [ resDeps, resReqDeps, resAsyncReqDeps, (_.pick moduleInfo, interestingDepTypes) ]
        reporter.addReportData repData, modyle

      l.verbose 'Template params (main):\n', _.omit templateInfo, 'version', 'modulePath', 'factoryBody'

      newJs = template templateInfo

    outputFile = _path.join options.outputPath, modyle

    if not (_fs.existsSync _path.dirname(outputFile))
      l.verbose "creating directory #{_path.dirname(outputFile)}"
      _wrench.mkdirSyncRecursive(_path.dirname(outputFile))

    _fs.writeFileSync outputFile, newJs, 'utf-8'

  if not _.isEmpty(reporter.reportData)
    l.log '\n########### urequire, final report ########### :\n', reporter.getReport()

  return null # save pointless coffeescript return :-)

module.exports =
  processBundle: processBundle

  # used by UMD-transformed modules, to make the node (async) require
  makeNodeRequire: require('./makeNodeRequire')
