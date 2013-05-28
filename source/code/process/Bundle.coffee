# external
_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
fs = require 'fs'
wrench = require 'wrench'
_B = require 'uberscore'
l = new _B.Logger 'urequire/Bundle'
globExpand = require 'glob-expand'
minimatch = require 'minimatch'

# uRequire
upath = require '../paths/upath'
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
    _.extend @, bundleCfg
    @reporter = new DependenciesReporter()
    @filenames = globExpand {cwd: @bundlePath}, @filespecs #our initial filenames
    @files = {}  # all bundle files are in this map
    @files[filename] = {} for filename in @filenames #initialized to an empty hash
    @loadResources()

  @staticProperty requirejs: get:=> require 'requirejs'

  isFileInSpecs = (file, filespecs)-> #todo: (3 6 4) convert to proper In/in agreement
    agrees = false
    for agreement in _B.arrayize filespecs #go throug all (no bailout when true) cause we have '!*glob*'
      if _.isString agreement
        agrees =
          if agreement[0] is '!'
            if minimatch file, agreement.slice(1) then false else agrees # falsify if minimatches, leave as is otherwise
          else
            agrees = agrees || minimatch file, agreement                 # if true leave it, otherwise try to truthify with minimatch
      else
        if _.isRegExp agreement
          agrees = agrees || file.match agreement
        else
          if _.isFunction agreement
            agrees = agreement file

    agrees

  ###
    Processes each filename, either as array of filenames (eg instructed by `watcher`) or all @filenames

    @param []<String> with filenames to process.
      @default read ALL files from filesystem (property @filenames)
  ###
  loadResources: (filenames = @filenames)->
    if filenames isnt @filenames # perhaps new files - add 'em to @files
      for fn in filenames when not @files[fn]
        @files[fn] = {}

    for filename in filenames
      try
        if _.isEmpty @files[filename] # possibly create a uResource (eg UModule) for 1st time
          l.debug "New resource: '#{filename}'" if l.deb 80

          #create a new UResource / UModule, adding all matched converters
          resourceClass = UModule     # default
          matchedConverters = []
          for resourceConverter in @resources
            if isFileInSpecs filename, resourceConverter.filespecs
              matchedConverters.push resourceConverter
              if resourceConverter.isModule is false
                resourceClass = UResource
              if resourceConverter.isTerminal
                break

          if not _.isEmpty matchedConverters
            @files[filename] = new resourceClass @, filename, matchedConverters
          # else we have no resources matched, its a file we dont know of

        else
          l.debug "Refreshing existing resource: '#{filename}'" if l.deb 80
          @files[filename].refresh()

      catch err
        l.debug(80, err)
        if not fs.existsSync @files[filename].fullPath  # remove it, if missing from filesystem
          l.log "Missing file '#{filename}', removing resource file."
          delete @files[filename]
        else
          err.uRequire = "*uRequire #{l.VERSION}*: Something went wrong while processing '#{filename}'."
          l.err err.uRequire
          if filenames is @filenames
            throw err #otherwise we are in 'watch' mode

      finally #keep filenames in sync
        @filenames = _.keys @files

  ###
  @build / convert all resources that have changed since last @build
  ###
#  buildChangedResources: (@build)->
#    l.log '@moduleFilenames =', @moduleFilenames
#    l.log '@processModuleFilenames =', @processModuleFilenames

  buildChangedResources: (@build)->
    # first, decide where to output when combining
    if @build.template.name is 'combined'
      if not @build.combinedFile # change @build's paths
        @build.combinedFile = upath.changeExt @build.outputPath, '.js'
        @build.outputPath = "#{@build.combinedFile}__temp"
        l.debug("Setting @build.combinedFile =", @build.outputPath,
                ' and @build.outputPath = ', @build.outputPath
        ) if l.deb 30

    @copyNonResourceFiles()

    changedCount = 0; errorCount = 0
    for filename, resource of @files  #when resource instanceof UModule
      if resource.hasChanged # it has changed, conversion needed
        changedCount++
        if resource.hasErrors
          errorCount++
        else
          l.debug 50, "Building changed resource '#{filename}'"
          resource.convert @build
          if _.isFunction @build.out # @todo:5 else if String, output to this file ?
            @build.out upath.join(@build.outputPath, resource.convertedFilename), resource.converted
          resource.hasChanged = false

    report = @reporter.getReport @build.interestingDepTypes
    if not _.isEmpty(report)
      l.verbose 'Report for this `build`:\n', report
      @reporter = new DependenciesReporter()

    if changedCount > 0
      if errorCount is 0
        l.verbose "#{changedCount} changed files in this build."
      else
        l.warn "#{changedCount} changed files & #{changedCount} with errors in this build."
      
    if (@build.template.name is 'combined') and changedCount
      @combine @build
    else
      @build.done true


  ###
  ###
  combine: (@build)->
    l.debug 30, 'combine: optimizing with r.js'

    if not @main # set to bundleName, or index.js, main.js @todo: & other sensible defaults ?
      for mainModuleCandidate in [@bundleName, 'index', 'main'] when mainModuleCandidate and not mainModule
        mainModule = _.find @files, (resource)-> resource.modulePath is mainModuleCandidate

        if mainModule
          @main = mainModule.modulePath
          l.warn """
           combine() note: 'bundle.main', your *entry-point module* was missing from bundle config(s).
           It's defaulting to #{if @main is @bundleName then 'bundle.bundleName = ' else ''
           }'#{@main}', as uRequire found an existing '#{@bundlePath}/#{mainModule.filename}' module in your bundlePath.
          """

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
          noWeb: @dependencies.noWeb
          @main
        }

        for fileName, genCode of almondTemplates.dependencyFiles
          Build.outputToFile "#{@build.outputPath}/#{fileName}.js", genCode

        @copyAlmondJs()
        @copyWebMapDeps()

        try #delete old combinedFile
          fs.unlinkSync @build.combinedFile
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
    #        if fs.existsSync @combinedFile
    #          l.verbose "uRequire: combined file '#{combinedFile}' written successfully."
          name: 'almond'
          optimize: "none"

        # 'optimize' ? in 3 different ways
        if optimize = @build.optimize # @todo: allow full r.js style optimize / uglify / uglify2
          optimizers = ['uglify2', 'uglify']
          if optimize is true
            optimizeMethod = optimizers[0] # enable 'uglify2' for true
          else
            if _.isObject optimize # eg {optimize:uglify2:{...uglify2 options...}}
              optimizeMethod = _.find optimizers, (v)-> v in _.keys optimize
            else
              if _.isString optimize
                optimizeMethod = _.find optimizers, (v)-> v is optimize

          if optimizeMethod
            rjsConfig.optimize = optimizeMethod
            rjsConfig[optimizeMethod] = optimize[optimizeMethod]
          else
            l.err "Quitting - unknown optimize method:", optimize
            build.done false

        rjsConfig.logLevel = 0 if l.deb 90

        # actually combine (r.js optimize)
        l.verbose "Optimize with r.js (v#{@requirejs.version}) with uRequire's 'build.js' = \n", _.omit(rjsConfig, ['wrap'])
        try
          @requirejs.optimize _.clone(rjsConfig, true), (buildResponse)->
            l.verbose 'r.js buildResponse = ', buildResponse
        catch err
          err.uRequire = "Error optimizing with r.js (v#{@requirejs.version})"
          l.err err

  #      if true
        setTimeout  (=>
          l.debug(60, 'Checking r.js output file...')
          if fs.existsSync build.combinedFile
            l.log "Combined file '#{build.combinedFile}' written successfully."

            globalDepsVars = @getDepsVars depType:'global'
            if not _.isEmpty globalDepsVars
              l.log "Global bindinds: make sure the following global dependencies:\n", globalDepsVars, """\n
                  are available when combined script '#{build.combinedFile}' is running on:

                  a) nodejs: they should exist as a local `nodes_modules`.

                  b) Web/AMD: they should be declared as `rjs.paths` (or `rjs.baseUrl`)

                  c) Web/Script: the binded variables (eg '_' or '$')
                     must be a globally loaded (i.e `window.$`) BEFORE loading '#{build.combinedFile}'
              """

            # delete outputPath, used as temp directory with individual AMD files
            if not l.deb 50
              l.debug(40, "Deleting temporary directory '#{build.outputPath}'.")
              wrench.rmdirSyncRecursive build.outputPath
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

  getRequireJSConfig: ()-> #@todo:(7 5 2) remove & fix this!
      paths:
        text: "requirejs_plugins/text"
        json: "requirejs_plugins/json"

  copyAlmondJs: ->
    try # copy almond.js from GLOBAL/urequire/node_modules -> outputPath
      Build.copyFileSync "#{__dirname}/../../../node_modules/almond/almond.js", "#{@build.outputPath}/almond.js"
    catch err
      err.uRequire = """
        uRequire: error copying almond.js from uRequire's installation node_modules - is it installed ?
        Tried: '#{__dirname}/../../../node_modules/almond/almond.js'
      """
      l.err err.uRequire
      throw err

  copyNonResourceFiles: ->
    if not _.isEmpty @copyNonResources
      # get all filenames from @files that have an empty {}
      nonResourceFilenames = _.filter _.keys(@files), (fn)=> _.isEmpty @files[fn]
      if not _.isEmpty nonResourceFilenames
        l.verbose "Copying non-resources files"
        for fn in nonResourceFilenames
          if isFileInSpecs fn, @copyNonResources
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

    # gather depsVars from all loaded resources
    for uMK, resource of @files when resource instanceof UModule
      gatherDepsVars resource.getDepsVars q

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

#
#if l.deb 90
#  YADC = require('YouAreDaChef').YouAreDaChef
#
#  YADC(Bundle)
#    .before /_constructor/, (match, bundleCfg)->
#      l.debug("Before '#{match}' with bundleCfg = \n", _.omit(bundleCfg, []))
#    .before /combine/, (match)->
#      l.debug('combine: optimizing with r.js')

module.exports = Bundle

