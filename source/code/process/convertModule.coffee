_ = require 'lodash'
ModuleGeneratorTemplates = require '../templates/ModuleGeneratorTemplates'
ModuleManipulator = require "../moduleManipulation/ModuleManipulator"
Dependency = require "../Dependency"
l = require '../utils/logger'

###
@param {String} modyle The module name
@param {String} oldModuleJs The javascript content of the original/old module
@param {Array<String>} bundleFiles A list of the names of all files in bundle (bundle root directory)
@param {Object} options Options for conversion as passed by urequireCmd.
@param {DependencyReporter} reporter an optional `DependencyReporter`

@return {String} the converted module js
###
convertModule = (modyle, oldJs, bundleFiles, options, reporter)->
  moduleManipulator = new ModuleManipulator oldJs, beautify:true
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

    if options.noExport
      delete moduleInfo.rootExports
    else
      moduleInfo.rootExports = moduleInfo.rootExport if moduleInfo.rootExport #backwards compatible:-)
      if not _.isArray moduleInfo.rootExports
        moduleInfo.rootExports = [ moduleInfo.rootExports ]

    # pass moduleInfo to optional reporting
    if reporter
      for repData in [ (_.pick moduleInfo, reporter.interestingDepTypes) ]
        reporter.addReportData repData, modyle

    #remove reduntant parameters (those in excess of the arrayDeps),
    # requireJS doesn't like them if require is 1st param
    if _.isEmpty moduleInfo.arrayDependencies
      moduleInfo.parameters = []
    else
      moduleInfo.parameters = moduleInfo.parameters[0..moduleInfo.arrayDependencies.length-1]

    # 'require' & associates are *fixed* in UMD template (if needed), so remove 'require'
    for pd in [moduleInfo.parameters, moduleInfo.arrayDependencies]
      pd.shift() if pd[0] is 'require'

    requireReplacements = {} # final replacements for all require() calls.

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

          for strDep in (strDepsArray || [])
            dep = new Dependency strDep, modyle, bundleFiles
            deps.push dep
            requireReplacements[strDep] = dep.name()
            reporter.reportDep dep, modyle if reporter

          deps

    # replace 'require()' calls using requireReplacements
    moduleInfo.factoryBody = moduleManipulator.getFactoryWithReplacedRequires requireReplacements

    # load ALL require('dep') fileRelative deps on AMD to prevent scan @ runtime.
    # If there's no deps AND we have --scanAllow, ommit from adding them (unless we have a rootExports)
    # RequireJs disables runtime scan if even one dep exists in [].
    # Execution stucks on require('dep') if its not loaded (i.e not present in arrayDeps).
    # see https://github.com/jrburke/requirejs/issues/467
    arrayDependencies = (d.toString() for d in arrayDeps)
    if not (_.isEmpty(arrayDependencies) and options.scanAllow and not moduleInfo.rootExports)
      for reqDep in requireDeps
        if reqDep.pluginName isnt 'node' and # 'node' is a fake plugin name, for nodejs-only-executing modules
          not (reqDep.toString() in arrayDependencies)
            arrayDependencies.push reqDep.toString()

    templateInfo = #
      version: version # 'var version = xxx' added by grunt concat @ .js top. (alt use options.version)
      moduleType: moduleInfo.moduleType
      modulePath: modyle # full module path within bundle
      webRootMap: options.webRootMap || '.'
      arrayDependencies: arrayDependencies
      nodeDependencies: if options.allNodeRequires then arrayDependencies else (d.name() for d in arrayDeps)
      parameters: moduleInfo.parameters
      factoryBody: moduleInfo.factoryBody

      rootExports: moduleInfo.rootExports # todo: generalize
      noConflict: moduleInfo.noConflict
      nodejs: moduleInfo.nodejs #todo: not working

    l.verbose 'Template params (main):\n', _.omit templateInfo, 'version', 'modulePath', 'factoryBody'

    newJs = (new ModuleGeneratorTemplates templateInfo)[options.template]()

  return newJs

module.exports = convertModule