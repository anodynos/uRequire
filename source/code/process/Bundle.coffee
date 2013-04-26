# external
_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
_fs = require 'fs'
_wrench = require 'wrench'
_B = require 'uberscore'

l = new _B.Logger 'Bundle'

# uRequire
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
  _constructor: (bundleCfg)->
    _.extend @, _B.deepCloneDefaults bundleCfg, uRequireConfigMasterDefaults.bundle #todo: do we need this here ?

    @reporter = new DependenciesReporter()

    @uModules = {}
    @loadModules()

    ### handle bundle.bundleName & bundle.main ###
    #@bundleName or= @main # @todo:4 where else should this default to, if not @main ?


  @staticProperty requirejs: get:=> require 'requirejs'

  ###
  Read / refresh all files in directory.
  Not run everytime there is a file added/removed, unless we need to:
  Runs initially and in unkonwn -watch / refresh situations (@todo:NOT IMPLEMENTED)
  ###
  for getFilesFactory, filesFilter of {

    filenames: (mfn)-> not _B.inAgreements mfn, @ignore # get all non-ignored files

    moduleFilenames: (mfn)-> # get only modules
       not _B.inAgreements(mfn, @ignore) and
        _B.inAgreements(mfn, @_knownModules)

    processModuleFilenames: (mfn)->
      _B.inAgreements(mfn, @_knownModules) and
      (not _B.inAgreements mfn, @ignore) and
      (_B.inAgreements(mfn, @processModules) or _.isEmpty @processModules)

    copyNonModulesFilenames: (mfn)->
       not _B.inAgreements(mfn, @ignore) and
       not _B.inAgreements(mfn, @_knownModules) and
       _B.inAgreements(mfn, @copyNonModules)
  }
      Bundle.property _B.okv {}, getFilesFactory,
        get: do(getFilesFactory, filesFilter)-> -> #return a function with these fixed
          existingFiles = (@["_#{getFilesFactory}"] or= [])
          try
             files =  getFiles @bundlePath, _.bind filesFilter, @
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
            @["_#{getFilesFactory}"] = files

          files
        @


  ###
    Processes each module, as instructed by `watcher` in a [] paramor read file system (@moduleFilenames)
    @param @build - see `config/uRequireConfigMasterDefaults.coffee`
    @param String or []<String> with filenames to process.
      @default read files from filesystem (property @moduleFilenames)
  ###
  loadModules: (moduleFilenames = @processModuleFilenames)->
    for moduleFN in _B.arrayize moduleFilenames
      fullModulePath = "#{@bundlePath}/#{moduleFN}"
      try
        moduleSource = _fs.readFileSync fullModulePath, 'utf-8'

        # check exists & source up to date
        if @uModules[moduleFN]
          if uM.sourceCode isnt moduleSource
            delete @uModule[moduleFN]

        if not @uModules[moduleFN]
          @uModules[moduleFN] = new UModule @, moduleFN, moduleSource
      catch err
        l.debug(80, err)
        if not _fs.existsSync fullModulePath  # remove it, if missing from filesystem
          l.log "Missing file '#{fullModulePath}', removing module '#{moduleFN}'"
          delete @uModules[moduleFN] if @uModules[moduleFN]
        else
          err.uRequire = "*uRequire #{l.VERSION}*: Something went wrong while processing '#{fullModulePath}', for module '#{moduleFN}'."
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
        l.debug("Setting @build.combinedFile =", @build.outputPath,
                ' and @build.outputPath = ', @build.outputPath
        ) if l.deb 30

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

    report = @reporter.getReport @build.interestingDepTypes
    if not _.isEmpty(report)
      l.log 'Report for this `build`:\n', report

    if @build.template.name is 'combined'
      if haveChanges
        @combine @build
      else
        @build.done true
    else
      @build.done true

  getRequireJSConfig: ()-> #@todo:(7 5 2) remove & fix this!
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
    cnmf = @copyNonModulesFilenames
    if not _.isEmpty cnmf
      l.verbose "Copying non-module/excluded files : \n", cnmf
      for fn in cnmf
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
    l.debug("delete #{@uModules[m]}" for m in modules if @uModules[m]) if l.deb 30

  ###

  ###
  combine: (@build)->

    if not @main # set to bundleName, or index.js, main.js & other sensible defaults
      for mainModuleCandidate in [@bundleName, 'index', 'main'] when mainModuleCandidate and not @main
        @main = _.find @moduleFilenames, (mf)->
            for ext in Build.moduleExtensions
              if mf is mainModuleCandidate + ".#{ext}"
                return true
            false

        if @main
          l.warn """
           combine() note: 'bundle.main', your *entry-point module* was missing from bundle config(s).
           It's defaulting to '#{upath.trimExt @main}', from existing '#{@bundlePath}/#{@main}' module in your bundlePath.
           """
          @main = upath.trimExt @main

    if not @main
      l.err """
        Quiting cause 'bundle.main' is missing (after so much effort).
        No module found either as bundleName = '#{@bundleName}', nor as ['index', 'main'].
      """
      @build.done false

    else
      globalDepsVars = @getDepsVars {depType: Dependency.TYPES.global}
      # check we have a global dependency without a variable binding & quit!
      if _.any(globalDepsVars, (v,k)-> _.isEmpty v)
        l.err """
          Quiting cause some global dependencies are missing a variable binding:

          #{l.prettify _B.go globalDepsVars, fltr: (v)->_.isEmpty v}

          These variable names are used to grab the dependency from the global object, when running as <script>.
          Eg. 'jquery' corresponds to '$' or 'jQuery', hence it should be known as `jquery: ['$', 'jQuery']`

          Remedy:

          You should add it at uRequireConfig 'bundle.dependencies.variableNames' as:
            ```
              variableNames: {
                'myDep1': 'VARIABLE_IT_BINDS_WITH',
                'myDep2': ['VARIABLE_IT_BINDS_WITH', 'ANOTHER VARIABLE_IT_BINDS_WITH']
              }
            ```
          Alternativelly, pick one medicine :
            - define at least one module that has this dependency + variable binding (currently using AMD only) and uRequire will find it!
            - use an `rjs.shim`, and uRequire will pick it from there (@todo: NOT IMPLEMENTED YET!)
            - RTFM & let us know if still no remedy!
        """
        @build.done false

      else

        almondTemplates = new AlmondOptimizationTemplate {
          globalDepsVars
          noWeb:@dependencies.noWeb
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
          include: [@main]
          deps: @dependencies.noWeb # we include the 'fake' AMD files 'getNoWebDep_XXX'
          out: @build.combinedFile
    #      out: (text)=>
    #        #todo: @build.out it!
    #        l.verbose "uRequire: writting combinedFile '#{combinedFile}'."
    #        @outputToFile text, @combinedFile
    #        if _fs.existsSync @combinedFile
    #          l.verbose "uRequire: combined file '#{combinedFile}' written successfully."

          optimize: "none" #  uglify: {beautify: true, no_mangle: true} ,
          name: 'almond'
        rjsConfig.logLevel = 0 if _B.Logger.debugLevel >= 90

        # actually combine (r.js optimize)
        l.verbose "Optimize with r.js with uRequire's 'build.js' = \n", _.omit(rjsConfig, ['wrap'])
        @requirejs.optimize _.clone(rjsConfig), (buildResponse)->
          l.verbose 'r.js buildResponse = ', buildResponse

  #      if true
        setTimeout  (=>
          l.debug(60, 'Checking r.js output file...')
          if _fs.existsSync build.combinedFile
            l.log "Combined file '#{build.combinedFile}' written successfully."

            globalDepsVars = @getDepsVars depType:'global'
            if not _.isEmpty globalDepsVars
              l.log """
                Global bindinds: make sure the following global dependencies
                """
                , globalDepsVars, """

                are available when combined script '#{build.combinedFile}' is running on:

                  a) nodejs: they should exist as a local `nodes_modules`.

                  b) Web/AMD: they should be declared as `rjs.paths` (or `rjs.baseUrl`)

                  c) Web/Script: the binded variables (eg '_' or '$')
                     must be a globally loaded (i.e `window.$`) BEFORE loading '#{build.combinedFile}'
              """

            # delete outputPath, used as temp directory with individual AMD files
            if _B.Logger.debugLevel < 50
              l.debug(40, "Deleting temporary directory '#{build.outputPath}'.")
              _wrench.rmdirSyncRecursive build.outputPath
            else
              l.debug("NOT Deleting temporary directory '#{build.outputPath}', due to debugLevel >= 50.")
            build.done true
          else
            l.err """
            Combined file '#{build.combinedFile}' NOT written."

              Some remedy:

               a) Is your *bundle.main = '#{@main}'* or *bundle.bundleName = '#{@bundleName}'* properly defined ?
                  - 'main' should refer to your 'entry' module, that requires all other modules - if not defined, it defaults to 'bundleName'.
                  - 'bundleName' is what 'main' defaults to, if its a module.

               b) Perhaps you have a missing dependcency ?
                  r.js doesn't like this at all, but it wont tell you unless logLevel is set to error/trace, which then halts execution.

               c) Re-run uRequire with debugLevel >=90, to enable r.js's logLevel:0 (trace).
                  *Note this prevents uRequire from finishing properly / printing this message!*

               Note that you can check the AMD-ish files used in temporary directory '#{build.outputPath}'.

               More remedy on the way... till then, you can try running r.js optimizer your self, based on the following build.js: \u001b[0m

            """, rjsConfig

            build.done false
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
    depsVars = {}

    gatherDepsVars = (_depsVars)-> # add non-exixsting var to the dep's `vars` array
      for dep, vars of _depsVars
        dv = (depsVars[dep] or= [])
        dv.push v for v in vars when v not in dv

    # gather depsVars from all loaded uModules
    for uMK, uModule of @uModules
      gatherDepsVars uModule.getDepsVars q

    # pick from @dependencies.variableNames only for existing deps, that have no vars info discovered yet
    # todo: remove from here / refactor
    if @dependencies?.variableNames
      vn = _B.go @dependencies.variableNames,
                 fltr:(v,k)=>
                    (depsVars[k] isnt undefined) and
                    _.isEmpty(depsVars[k]) and
                    not (k in @dependencies?.noWeb)
      if not _.isEmpty vn
        l.warn "\n Picked from `@dependencies.variableNames` for some deps with missing dep-variable bindings: \n", vn
        gatherDepsVars vn

    # 'urequireCfg.bundle.dependencies._knownVariableNames' contain known ones
    #   eg `jquery:['$'], lodash:['_']` etc
    # todo: remove from here / refactor
    vn = _B.go @dependencies._knownVariableNames,
               fltr:(v,k)=>
                  (depsVars[k] isnt undefined) and
                  _.isEmpty(depsVars[k]) and
                  not (k in @dependencies?.noWeb)
    if not _.isEmpty vn
      l.warn "\n Picked from `@dependencies._knownVariableNames` for some deps with missing dep-variable bindings: \n", vn
      gatherDepsVars vn

    depsVars


if _B.Logger.debugLevel > 90
  YADC = require('YouAreDaChef').YouAreDaChef

  YADC(Bundle)
    .before /_constructor/, (match, bundleCfg)->
      l.debug("Before '#{match}' with bundleCfg = \n", _.omit(bundleCfg, []))
    .before /combine/, (match)->
      l.debug('combine: optimizing with r.js')

module.exports = Bundle



