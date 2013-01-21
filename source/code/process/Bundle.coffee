# external
_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
_B = require 'uberscore'
_fs = require 'fs'
_wrench = require 'wrench'

# uRequire
Logger = require '../utils/Logger'
l = new Logger 'Bundle'

upath = require '../paths/upath'
getFiles = require "./../utils/getFiles"
uRequireConfigMasterDefaults = require '../config/uRequireConfigMasterDefaults'
AlmondOptimizationTemplate = require '../templates/AlmondOptimizationTemplate'
Dependency = require '../Dependency'
DependenciesReporter = require './../DependenciesReporter'
UModule = require './UModule'
Build = require './Build'
BundleBase = require './BundleBase'


###

###
class Bundle extends BundleBase
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor:-> @_constructor.apply @, arguments

  interestingDepTypes: ['notFoundInBundle', 'untrustedRequireDependencies', 'untrustedAsyncDependencies']

  @staticProperty requirejs: get:=> require 'requirejs'

  _constructor: (bundleCfg)->
    _.extend @, _B.deepCloneDefaults bundleCfg, uRequireConfigMasterDefaults.bundle

    @main or= 'main' # @todo:5 add implicit bundleName, or index.js, main.js & other sensible defaults
    @bundleName or= @main # @todo:4 where should this default to ?

    @uModules = {}
    @reporter = new DependenciesReporter @interestingDepTypes #(if @build.verbose then null else @interestingDepTypes)

    #@property filenames: get: -> getFiles @bundlePath # get all filenames each time we 'refresh'
    ###
    Read / refresh all files in directory.
    Not run everytime there is a file added/removed, unless we need to:
    Runs initially and in unkonwn -watch / refresh situations
    ###
    for getFilesFactory, filesFilter of {
      filenames: -> true # get all files
      moduleFilenames: (mfn)=> # get only modules
        (_B.inAgreements(mfn, @includes) and not _B.inAgreements(mfn, @excludes)) #@todo:2 (uberscore):notFilters()
    }
      do (bundle = @)->
        Bundle.property _B.okv {}, getFilesFactory,
          get: do(getFilesFactory, filesFilter)-> -> #return a function with these fixed 
              existingFiles = (bundle["_#{getFilesFactory}"] or= [])
              try
                 files =  getFiles bundle.bundlePath, filesFilter
              catch err
                err.uRequire = "*uRequire #{l.VERSION}*: Something went wrong reading from '#{@bundlePath}'."
                l.err err.uRequire
                throw err

              newFiles = _.difference files, existingFiles
              if not _.isEmpty newFiles
                l.verbose "New #{getFilesFactory} :\n", newFiles
                existingFiles.push file for file in newFiles

              deletedFiles = _.difference existingFiles, files
              if not _.isEmpty deletedFiles
                l.verbose "Deleted #{getFilesFactory} :\n", deletedFiles
                @deleteModules deletedFiles
                bundle["_#{getFilesFactory}"] = files

              files
            @

    @loadModules()

  ###
    Processes each module, as instructed by `watcher` in a [] paramor read file system (@moduleFilenames)
    @param @build - see `config/uRequireConfigMasterDefaults.coffee`
    @param String or []<String> with filenames to process.
      @default read files from filesystem (property @moduleFilenames)
  ###
  loadModules: (moduleFilenames = @moduleFilenames)->
    for moduleFN in _B.arrayize moduleFilenames
      try
        moduleSource = _fs.readFileSync "#{@bundlePath}/#{moduleFN}", 'utf-8'

        # check exists & source up to date
        if @uModules[moduleFN]
          if uM.sourceCode isnt moduleSource
            delete @uModule[moduleFN]

        if not @uModules[moduleFN]
          @uModules[moduleFN] = new UModule @, moduleFN, moduleSource
      catch err
        l.err 'TEMP:' + err
        if not _fs.existsSync "#{@bundlePath}/#{moduleFN}" # remove it, if missing from filesystem
          l.log "Removed file : '#{@bundlePath}/#{moduleFN}'"
          delete @uModules[moduleFN] if @uModules[moduleFN]
        else
          err.uRequire = "*uRequire #{l.VERSION}*: Something went wrong while processing '#{moduleFN}'."
          l.err err.uRequire
          throw err

  ###
  @build / convert all uModules that have changed since last @build
  ###
  buildChangedModules: (@build)->

    # first, decide where to output when combining
    if @build.template.name is 'combined'
      if not @build.combinedFile # change @build's paths
        @build.combinedFile = upath.changeExt @build.outputPath, '.js'
        @build.outputPath = "#{@build.combinedFile}__temp"
        l.debug 95, "Setting @build.combinedFile = '#{@build.outputPath}' and @build.outputPath = '#{@build.outputPath}'"
      #@interestingDepTypes.push 'global' #@todo: add to this reporter's run !

    @copyNonModuleFiles() #@todo:5 unless bundle or @build says no

    haveChanges = false

    for mfn, uModule of @uModules
      if not uModule.convertedJs # it has changed, then conversion is needed :-)
        haveChanges = true

        # @todo: reset reporter!
        uModule.convert @build

        if _.isFunction @build.out
          @build.out uModule.modulePath, uModule.convertedJs
          # @todo:5 else if String, output to this file ?

    if @build.template.name is 'combined' and haveChanges
      @combine @build

    if not _.isEmpty(@reporter.reportData)
      l.log '\n########### urequire, final report ########### :\n', @reporter.getReport()

  #Bundle::@build.debugLevel = 10 # @todo: try this for debugin'

  getRequireJSConfig: ()-> #@todo: remove & fix this!
      paths:
        text: "requirejs_plugins/text"
        json: "requirejs_plugins/json"

  copyAlmondJs:->
    try # copy almond.js from GLOBAL/urequire/node_modules -> outputPath
      Build.copyFileSync "#{__dirname}/../../../node_modules/almond/almond.js", "#{@build.outputPath}/almond.js"
    catch err
      err.uRequire = """
        uRequire: error copying almond.js from uRequire's installation node_modules - is it installed ?
        Tried: '#{__dirname}/../../../node_modules/almond/almond.js'
      """
      l.err err.uRequire
      throw err

  copyNonModuleFiles: ->
    nonModules = (fn for fn in @filenames when fn not in @moduleFilenames)
    if not _.isEmpty nonModules
      l.verbose "Copying non-module/excluded files : \n", nonModules
      for fn in nonModules
        Build.copyFileSync "#{@bundlePath}/#{fn}", "#{@build.outputPath}/#{fn}"

  ###
   Copy all bundle's webMap dependencies to outputPath
   @todo: should copy dep.plugin & dep.resourceName separatelly
  ###
  copyWebMapDeps: ->
    webRootDeps = _.keys @getDepsVars(depType: Dependency.TYPES.webRootMap)
    if not _.isEmpty webRootDeps
      l.verbose "Copying webRoot deps :\n", webRootDeps
      for depName in webRootDeps
        Build.copyFileSync  "#{@webRoot}#{depName}", #from
                          "#{@build.outputPath}#{depName}" #to

  deleteModules: (modules)-> #todo: implement it
    l.debug 50, "delete #{@uModules[m]}" for m in modules if @uModules[m]

  ###

  ###
  combine: (@build)->
    almondTemplates = new AlmondOptimizationTemplate {
      globalDepsVars: @getDepsVars {depType: Dependency.TYPES.global}
      @main
    }

    for fileName, genCode of almondTemplates.dependencyFiles
      Build.outputToFile "#{@build.outputPath}/#{fileName}.js", genCode

    @copyAlmondJs()

    @copyWebMapDeps()

    try #delete old combinedFile
      _fs.unlinkSync @build.combinedFile
    catch err

    rjsConfig =
      paths: _.extend almondTemplates.paths, @getRequireJSConfig().paths

      wrap: almondTemplates.wrap
      baseUrl: @build.outputPath
      include: @main
      out: @build.combinedFile
#      out: (text)=>
#        #todo: @build.out it!
#        l.verbose "uRequire: writting combinedFile '#{combinedFile}'."
#        @outputToFile text, @combinedFile
#        if _fs.existsSync @combinedFile
#          l.verbose "uRequire: combined file '#{combinedFile}' written successfully."

      optimize: "none" #  uglify: {beautify: true, no_mangle: true} ,
      name: 'almond'

    l.verbose "Optimize with r.js with uRequire's 'build.js' = ", JSON.stringify _.omit(rjsConfig, ['wrap']), null, ' '
    @requirejs.optimize rjsConfig, (buildResponse)->
      l.verbose 'r.js buildResponse = ', buildResponse

    setTimeout (->
      if _fs.existsSync build.combinedFile
        l.verbose "Combined file '#{build.combinedFile}' written successfully."

        # delete outputPath, used as temp directory with individual AMD files
        if Logger::debugLevel < 50
          l.debug 40, "Deleting temporary directory '#{build.outputPath}'."
          _wrench.rmdirSyncRecursive build.outputPath
        else
          l.debug "NOT Deleting temporary directory '#{build.outputPath}', due to debugLevel >= 50."
      else
        l.err """
        Combined file '#{build.combinedFile}' NOT written."

        Perhaps you have a missing dependcency ? Note you can check AMD files used in temporary directory '#{build.outputPath}'.
        """

      ), 100

  ###
  Gets dependencies & the variables (they bind with), througout this bundle.

  The information is gathered from all modules and joined together.

  Also it uses bundle.dependencies.variableNames, if some dep has no corresponding vars [].

  @param {Object} q optional query with two optional fields : depType & depName

  @return {dependencies.variableNames} `dependency: ['var1', 'var2']` eg
              {
                  'underscore': '_'
                  'jquery': ["$", "jQuery"]
                  'models/PersonModel': ['persons', 'personsModel']
              }

  ###
  getDepsVars: (q)->
    depsAndVars = {}

    gatherDepsVars = (depsVars)-> # add non-exixsting var to the dep's `vars` array
      for dep, vars of depsVars
        dv = (depsAndVars[dep] or= [])
        dv.push v for v in vars when v not in dv

    for uMK, uModule of @uModules
      gatherDepsVars uModule.getDepsAndVars q

    # pick only for existing deps, that have no vars info discovered yet
    if variableNames = @dependencies?.variableNames
      vn = _B.go variableNames, fltr:(v,k)-> (depsAndVars[k] isnt undefined) and _.isEmpty depsAndVars[k]
      if not _.isEmpty vn
        l.warn "\n Had to pick from variableNames for some deps = \n", vn
      gatherDepsVars vn

    depsAndVars


if Logger::debugLevel > 90
  YADC = require('YouAreDaChef').YouAreDaChef

  YADC(Bundle)
    .before /_constructor/, (match, bundleCfg)->
      l.debug "Before '#{match}' with bundleCfg = \n", _.omit(bundleCfg, [])
    .before /combine/, (match)->
      l.debug 'combine: optimizing with r.js'

module.exports = Bundle