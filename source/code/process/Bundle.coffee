# externals
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
UError = require '../utils/UError'

#our file types
BundleFile = require './BundleFile'
UResource = require './UResource'
UModule = require './UModule'

Build = require './Build'
BundleBase = require './BundleBase'

###

###
DEB_LEVEL_NO_DELETE_COMBINE_DIR = 50
class Bundle extends BundleBase
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p

  constructor:-> @_constructor.apply @, arguments
  _constructor: (bundleCfg)->
    _.extend @, bundleCfg
    @reporter = new DependenciesReporter()
    @filenames = globExpand {cwd: @path}, @filez #our initial filenames
    @files = {}  # all bundle files are in this map
#    @files[filename] = {} for filename in @filenames #initialized to an unknown placeholder

  @staticProperty requirejs: get:=> require 'requirejs'

  isFileInSpecs = (file, filez)-> #todo: (3 6 4) convert to proper In/in agreement
    agrees = false
    for agreement in _B.arrayize filez #go throug all (no bailout when true) cause we have '!*glob*'
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

    If a filename is new, create a new BundleFile (or more interestingly a UResource or UModule)

    In any case, refresh() each one, either new or existing

    @param []<String> with filenames to process.
      @default read ALL files from filesystem (property @filenames)
  ###
  loadOrRefreshResources: (filenames = @filenames)->
    l.verbose """\n
    #####################################################################
    loadOrRefreshResources: filenames.length = #{filenames.length}
    #####################################################################
    """

    # check which filenames match resource converters
    # and instantiate them as UResource or UModule
    for filename in filenames
      isNew = false
      if not @files[filename] # a new filename
        isNew = true
        # check if we create a uResource (eg UModule) - if we have some matchedConverters
        matchedConverters = []; resourceClass = UModule # default
        # add all matched converters (until a terminal converter found)
        for resourceConverter in @resources
          if isFileInSpecs filename, resourceConverter.filez
            matchedConverters.push resourceConverter
            if resourceConverter.isModule is false
              resourceClass = UResource
            if resourceConverter.isTerminal
              break

        if _.isEmpty matchedConverters # no resourceConverters matched,
          resourceClass = BundleFile  # its just a bundle file
          # else its a convertible UResource or UModule

        l.debug "New *#{resourceClass.name}*: '#{filename}'" if l.deb 80
        @files[filename] = new resourceClass @, filename, matchedConverters

      else
        l.debug "Refreshing existing resource: '#{filename}'" if l.deb 80

      try
        @files[filename].refresh() # compilations / conversions happen here

        if isNew # check there is no same dstFilename
          if sameDstFile = (
            _.find @files, (f)=>
                f.dstFilename is @files[filename].dstFilename and
                f isnt @files[filename]
          )
            l.err uerr = """
              Same dstFilename '#{sameDstFile.dstFilename}' for '#{@files[filename].filename}' & '#{sameDstFile.filename}'
            """
            @files[filename].hasErrors = true
            throw new UError uerr

      catch err
        if not fs.existsSync @files[filename].srcFilepath  # remove it, if missing from filesystem
          l.verbose """
            Missing file '#{@files[filename].srcFilepath}'.
              Deleting destination file '#{@files[filename].dstFilepath}'.
              Removing bundle resource  '#{filename}'."""

          fs.unlinkSync @files[filename].dstFilepath
          delete @files[filename]
        else
          l.err uerr = "Something wrong while loading/refreshing/processing '#{filename}'."
          uerr = new UError uerr, nested:err
          if @build.continue or @build.watch
            l.warn "Continuing from error due to @build.continue || @build.watch - not throwing:\n", uerr
          else
            l.log uerr; throw uerr

    @filenames = _.keys @files
    @dstFilenames = _.map @files, (file)-> file.dstFilename

  ###
    build / convert all resources that have changed since last
  ###
  buildChangedResources: (@build, filenames=@filenames)->
    l.verbose """\n
    #####################################################################
    buildChangedResources: filenames.length = #{filenames.length}
    #####################################################################
    """

    # some intricacies when combining
    if @build.template.name is 'combined'

      # where to output AMD-like templates & where the combined file
      if not @build.combinedFile
        # its 1st time we run - fix this
        @build.combinedFile = upath.changeExt @build.outputPath, '.js'
        @build.outputPath = "#{@build.combinedFile}__temp"
        l.debug("Setting @build.combinedFile =", @build.outputPath,
                ' and @build.outputPath = ', @build.outputPath) if l.deb 30

      # before any individual filenames can be combined (now this is kinda lame bu very usefull)
      if @build.watch and                                 # If in watch mode
         (not @watchHasFullBuild) and                     # and havent fully build once (to have our __temp dir)
         (filenames isnt @filenames)                  # and a partial build is asked
#         (not l.deb DEB_LEVEL_NO_DELETE_COMBINE_DIR)      # and aren't debuging high
            filenames = @filenames                        # make sure we have a full build
            l.warn """
               'combined' template : performing a full build 1st time on *watch* (to get our __temp directory)
               Note: when you quit 'watch'-ing, you have to delete '#{@build.outputPath}' you self!
             """
            resource.reset() for fn, resource of @files
            @watchHasFullBuild = true                     # and note it


    # now load/refresh some filenames or all @filenames
    @loadOrRefreshResources filenames

    @copyNonResourceFiles()

    l.verbose """\n
    #####################################################################
    Converting changed modules with template '#{@build.template.name}'
    #####################################################################
    """
    @changedCount = 0; @errorCount = 0
    for filename, resource of @files when \
        (filenames is @filenames) or (filename in filenames)

      if resource.hasChanged # it has changed, conversion needed
        if resource instanceof UModule
          resource.convert @build

        if _.isFunction @build.out # @todo:5 else if String, output to this file ?
          @build.out resource.dstFilepath, resource.converted
        resource.hasChanged = false
        @changedCount++

      @errorCount++ if resource.hasErrors

    report = @reporter.getReport @build.interestingDepTypes
    if not _.isEmpty(report)
      l.warn 'Report for this `build`:\n', report
      @reporter = new DependenciesReporter()

    l.verbose "#{@changedCount} changed resources were built."
    l.err "#{@errorCount} resources with errors in this build." if @errorCount > 0

    # 'combined' or done()
    if (@build.template.name is 'combined')
      if @changedCount > 0
        @combine @build
      else
        l.debug 30, "Not executing 'combined' building, cause there are no changes built."
        @build.done @errorCount is 0
    else
      @build.done @errorCount is 0

  ###
  ###
  combine: (@build)->
    l.verbose """\n
    #####################################################################
    combine: optimizing with r.js
    #####################################################################
    """

    if not @main # set to name, or index.js, main.js @todo: & other sensible defaults ?
      for mainCand in [@name, 'index', 'main'] when mainCand and not mainModule
        mainModule = _.find @files, (resource)-> resource.modulePath is mainCand          
          
        if mainModule
          @main = mainModule.modulePath
          l.warn """
           combine() note: 'bundle.main', your *entry-point module* was missing from bundle config(s).
           It's defaulting to #{if @main is @name then 'bundle.name = ' else ''
           }'#{@main}', as uRequire found an existing '#{@path}/#{mainModule.filename}' module in your path.
          """

    if not @main
      l.err """
        Quiting cause 'bundle.main' is missing (after so much effort).
        No module found either as name = '#{@name}', nor as ['index', 'main'].
      """
      @build.done false
      return

    else
      globalDepsVars = @getDepsVars {depType: Dependency.TYPES.global}
      # check we have a global dependency without a variable binding & quit!
      if _.any(globalDepsVars, (v,k)-> _.isEmpty v)
        l.err """
          Some global dependencies are missing a variable binding:

          #{l.prettify _B.go globalDepsVars, fltr: (v)->_.isEmpty v}

          These variable names are used to grab the dependency from the global object, when running as <script>.
          Eg. 'jquery' corresponds to '$' or 'jQuery', hence it should be known as `jquery: ['$', 'jQuery']`

          Remedy:

          You should add it at uRequireConfig 'bundle.dependencies.depsVars' as:
            ```
              depsVars: {
                'myDep1': 'VARIABLE_IT_BINDS_WITH',
                'myDep2': ['VARIABLE_IT_BINDS_WITH', 'ANOTHER VARIABLE_IT_BINDS_WITH']
              }
            ```
          Alternativelly, pick one medicine :
            - define at least one module that has this dependency + variable binding (currently using AMD only) and uRequire will find it!
            - use an `rjs.shim`, and uRequire will pick it from there (@todo: NOT IMPLEMENTED YET!)
            - RTFM & let us know if still no remedy!
        """
        @errorCount++ #lame - make it count the real errors !
        if not (@build.watch or @build.continue)
          @build.done false
          return

      almondTemplates = new AlmondOptimizationTemplate {
        globalDepsVars
        noWeb: @dependencies.noWeb
        @main
      }

      for depfilename, genCode of almondTemplates.dependencyFiles
        Build.outputToFile upath.join(@build.outputPath, depfilename+'.js'), genCode

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
          if _.isObject optimize # eg optimize: { uglify2: {...uglify2 options...}}
            optimizeMethod = _.find optimizers, (v)-> v in _.keys optimize
          else
            if _.isString optimize
              optimizeMethod = _.find optimizers, (v)-> v is optimize

        if not optimizeMethod # should hold the name eg 'uglify2'
          l.err "Unknown optimize method '#{optimize}' - using 'uglify2' as default"
          optimizeMethod = optimizers[0]

        rjsConfig.optimize = optimizeMethod
        rjsConfig[optimizeMethod] = optimize[optimizeMethod] #set optimize options, eg  { uglify2: {...uglify2 options...}}

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
          l.verbose "Combined file '#{build.combinedFile}' written successfully."

          globalDepsVars = @getDepsVars depType:'global'
          if not _.isEmpty globalDepsVars
            if (not build.watch and not build.verbose) or l.deb 20
              l.log "Global bindinds: make sure the following global dependencies:\n", globalDepsVars,
                """\n
                are available when combined script '#{build.combinedFile}' is running on:

                a) nodejs: they should exist as a local `nodes_modules`.

                b) Web/AMD: they should be declared as `rjs.paths` (or `rjs.baseUrl`)

                c) Web/Script: the binded variables (eg '_' or '$')
                   must be a globally loaded (i.e `window.$`) BEFORE loading '#{build.combinedFile}'
                """

          # delete outputPath, used as temp directory with individual AMD files
          if not (l.deb(DEB_LEVEL_NO_DELETE_COMBINE_DIR) or build.watch)
            l.debug(40, "Deleting temporary directory '#{build.outputPath}'.")
            wrench.rmdirSyncRecursive build.outputPath
          else
            l.debug("NOT Deleting temporary directory '#{build.outputPath}', due to build.watch || debugLevel >= #{DEB_LEVEL_NO_DELETE_COMBINE_DIR}.")
          build.done @errorCount is 0
        else
          l.err """
          Combined file '#{build.combinedFile}' NOT written."

            Some remedy:

             a) Is your *bundle.main = '#{@main}'* or *bundle.name = '#{@name}'* properly defined ?
                - 'main' should refer to your 'entry' module, that requires all other modules - if not defined, it defaults to 'name'.
                - 'name' is what 'main' defaults to, if its a module.

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
      Build.copyFileSync(
        "#{__dirname}/../../../node_modules/almond/almond.js" # from
        upath.join(@build.outputPath, 'almond.js')            # to
      )
    catch err
      l.err uerr = """
        uRequire: error copying almond.js from uRequire's installation node_modules - is it installed ?
        Tried: '#{__dirname}/../../../node_modules/almond/almond.js'
      """
      uerr = new UError uerr, nested:err
      if @build.continue
        l.err "Continuing from error due to @build.continue - not throwing:\n", uerr
      else throw uerr

  # All @files (i.e bundle.filez) that ARE NOT `UResource`s and below (i.e are plain `BundleFile`s)
  # are copied to build.outputPath.
  copyNonResourceFiles: ->
    if not _.isEmpty @copy then nonResourceFilenames = #save time
      _.filter @filenames, (fn)=> not (@files[fn] instanceof UResource)

    if not _.isEmpty nonResourceFilenames
      l.verbose """\n
      #####################################################################
      Copying #{nonResourceFilenames.length} non-resources files..."
      #####################################################################
      """
      for fn in nonResourceFilenames
        if isFileInSpecs fn, @copy
          Build.copyFileSync @files[fn].srcFilepath, @files[fn].dstFilepath

  ###
   Copy all bundle's webMap dependencies to outputPath
   @todo: use path.join
   @todo: should copy dep.plugin & dep.resourceName separatelly
  ###
  copyWebMapDeps: ->
    webRootDeps = _.keys @getDepsVars(depType: Dependency.TYPES.webRootMap)
    if not _.isEmpty webRootDeps
      l.verbose "Copying webRoot deps :\n", webRootDeps
      for depName in webRootDeps
#        Build.copyFileSync  "#{@webRoot}#{depName}",         #from
#                            "#{@build.outputPath}#{depName}" #to
        l.err "NOT IMPLEMENTED: Build.copyFileSync  #{@webRoot}#{depName}, #{@build.outputPath}#{depName}"


  ###
  Gets dependencies & the variables (they bind with), througout this bundle.

  The information is gathered from all modules and joined together.

  Also it uses bundle.dependencies.depsVars, if some dep has no corresponding vars [].

  @param {Object} q optional query with two optional fields : depType & depName

  @return {dependencies.depsVars} `dependency: ['var1', 'var2']` eg
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

    # pick from @dependencies.depsVars only for existing deps, that have no vars info discovered yet
    # todo: remove from here / refactor
    if @dependencies?.depsVars
      vn = _B.go @dependencies.depsVars,
                 fltr:(v,k)=>
                    (depsVars[k] isnt undefined) and
                    _.isEmpty(depsVars[k]) and
                    not (k in @dependencies?.noWeb)
      if not _.isEmpty vn
        l.warn "\n Picked from `@dependencies.depsVars` for some deps with missing dep-variable bindings: \n", vn
        gatherDepsVars vn

    # 'urequireCfg.bundle.dependencies._knownDepsVars' contain known ones
    #   eg `jquery:['$'], lodash:['_']` etc
    # todo: remove from here / refactor
    vn = _B.go @dependencies._knownDepsVars,
               fltr:(v,k)=>
                  (depsVars[k] isnt undefined) and
                  _.isEmpty(depsVars[k]) and
                  not (k in @dependencies?.noWeb)
    if not _.isEmpty vn
      l.warn "\n Picked from `@dependencies._knownDepsVars` for some deps with missing dep-variable bindings: \n", vn
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

