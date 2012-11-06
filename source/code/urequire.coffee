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
  resolveWebRoot = require './resolveWebRoot'
  DependenciesReporter = require './DependenciesReporter'
  Dependency = require "./Dependency"


  interestingDepTypes = ['notFoundInBundle', 'untrustedRequireDependencies', 'untrustedAsyncDependencies']
  reporter = new DependenciesReporter(if options.verbose then null else interestingDepTypes )

  bundleFiles =  getFiles options.bundlePath, (fileName)-> true # get all files
  jsFiles =  getFiles options.bundlePath, (fileName)-> (_path.extname fileName) is '.js'

  l.verbose '\nBundle files found: \n', bundleFiles

  for modyle in jsFiles
    l.verbose '\nProcessing module: ', modyle

    oldJs = _fs.readFileSync "#{options.bundlePath}/#{modyle}", 'utf-8'

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

      requireReplacements = {} # final replacements for all require() calls.

      reportedDeps = {}
      reportDep = (dep, reportDepName)->
        (reportedDeps[reportDepName] or= []).push dep.resourceName

      # Go throught all original deps & resolve their fileRelative counterpart.
      # resolvedDeps stored as a <code>Dependency<code> object
      [ arrayDeps      # Store resolvedDeps as res'DepType'
        requireDeps
        asyncDeps ] = for strDepsArray in [
           moduleInfo.arrayDependencies
           moduleInfo.requireDependencies
           moduleInfo.asyncDependencies
          ]
            deps = []

            if not _(strDepsArray).isEmpty()
              for strDep in strDepsArray
                dep = new Dependency strDep, modyle, bundleFiles
                deps.push dep
                requireReplacements[strDep] = dep.name();

                #report deps : those might interest our reporting facility
                if dep.isGlobal()
                  reportDep dep, 'global' #  global-looking deps, like 'underscore'

                if not (dep.isBundleBoundary() or dep.isWebRoot())
                  reportDep dep, 'external' # external-looking deps, like '../../../someLib'

                if dep.isBundleBoundary() and not (dep.isFound() or dep.isGlobal())
                  reportDep dep, 'notFoundInBundle' # seem to belong to bundle, but not found, like '../myLib'

                if dep.isWebRoot()
                  reportDep dep, 'webRoot' # webRoot deps, like '/assets/myLib'
            deps

      # add to reporting
      for repData in [ reportedDeps, (_.pick moduleInfo, interestingDepTypes) ]
        reporter.addReportData repData, modyle

      # replace 'require()' calls using requireReplacements
      moduleInfo.factoryBody = moduleManipulator.getFactoryWithReplacedRequires requireReplacements

      # load ALL require('dep') fileRelative deps on AMD if there is one-or-more OR we want to scanPrevent)
      # RequireJs disables runtime scan if even one dep exists in [].
      # Execution stucks on require('dep') if its not loaded (i.e not present in arrayDeps).
      # see https://github.com/jrburke/requirejs/issues/467
      arrayDependencies = (d.toString() for d in arrayDeps)
      if (not _(arrayDependencies).isEmpty()) or options.scanPrevent
        for reqDep in requireDeps
          if reqDep.pluginName isnt 'node' and
            not (reqDep.toString() in arrayDependencies)
              arrayDependencies.push reqDep.toString()

      templateInfo = #
        version: options.version
        moduleType: moduleInfo.moduleType
        modulePath: modyle # full module path within bundle
        webRoot: resolveWebRoot modyle, options.webRootMap
        arrayDependencies: arrayDependencies
        nodeDependencies: if options.allNodeRequires then arrayDependencies else (d.name() for d in arrayDeps)
        parameters: moduleInfo.parameters
        factoryBody: moduleInfo.factoryBody

      if (not options.noExport) and moduleInfo.rootExport
        templateInfo.rootExport = moduleInfo.rootExport

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
  NodeRequirer: require('./NodeRequirer')
