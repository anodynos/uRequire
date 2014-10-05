_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/process/Bundle'

_.mixin (require 'underscore.string').exports()

fs = require 'fs'

globExpand = require 'glob-expand'

# uRequire
upath = require '../paths/upath'
MasterDefaultsConfig = require '../config/MasterDefaultsConfig'
AlmondOptimizationTemplate = require '../templates/AlmondOptimizationTemplate'
Dependency = require '../fileResources/Dependency'
DependenciesReporter = require './../utils/DependenciesReporter'
UError = require '../utils/UError'
ResourceConverterError = require '../utils/ResourceConverterError'

isTrueOrFileInSpecs = require '../config/isTrueOrFileInSpecs'

#our file system
BundleFile = require './../fileResources/BundleFile'
FileResource = require './../fileResources/FileResource'
TextResource = require './../fileResources/TextResource'
Module = require './../fileResources/Module'

Build = require './Build'
BundleBase = require './BundleBase'

CodeMerger = require '../codeUtils/CodeMerger'
toCode = require '../codeUtils/toCode'

isFileInSpecs = require '../config/isFileInSpecs'

debugLevelSkipTempDeletion = 50

When = require 'when'

###
  @todo: doc it!
###
class Bundle extends BundleBase

  constructor: (bundleCfg)->
    super
    _.extend @, bundleCfg
    @files = {}  # all bundle files are in this map

  inspect: -> "Bundle:" + l.prettify { @path, @filez, @files, @name, @main}

  # these are using _B.CalcCachedProperties functionality.
  # They are cached 1st time accessed.
  # They are cleaned with
  #   `@cleanProps 'propName1', ((p)-> true),  'propName1'
  # or `cleanProps()` to clean all.
  @calcProperties:

    filenames:->
      if _.isEmpty @files
        _.filter globExpand({cwd: @path, filter: 'isFile'}, '**/*'), (f)=> isFileInSpecs f, @filez #our initial filenames
      else
        _.keys @files

    dstFilenames:-> _.map @files, (f)-> f.dstFilename                     # just dstFilenames, used by Dependency

    # all of these hold instances of Module, TextResource etc
    # We want to add some helper methods
    # eg (_.find m.bundle.modules, (mod)-> mod.path is 'specHelpers-imports')
    # @todo: make more generic, eg use Backbone Models & collections
    fileResources:-> _.pick @files, (f)-> f instanceof FileResource       # includes TextResource & Module

    textResources:-> _.pick @files, (f)-> f instanceof TextResource       # includes Module

    modules:-> _.pick @files, (f)-> f instanceof Module                   # just Modules

    # filtered for copy only # todo: allow all & then filter them
    copyBundleFiles: ->
      if _.isEmpty @copy
        {}
      else
        _.pick @files, (f, filename)=> not (f instanceof FileResource) and (isFileInSpecs filename, @copy)

    # XXX_depsVars: format {dep1:['dep1Var1', 'dep1Var2'], dep2:[...], ...}
    localNonNode_depsVars: ->
      @inferEmptyDepVars (@getDepsVars (dep)-> dep.isLocal and not dep.isNode),
        'Gathering @localNonNode_depsVars (bundle`s local dependencies) & infering empty depVars'

    nodeOnly_depsVars:->
      l.debug 80, "Gathering 'node'-only dependencies"
      @getDepsVars (dep)-> dep.isNode # also gets `nodeLocal`

    all_depsVars:-> @inferEmptyDepVars @getDepsVars(), 'Gathering @all_depsVars & infering empty depVars', false

    exportsBundle_depsVars:->
      @inferEmptyDepVars _.clone(@dependencies.exports.bundle, true),
        "Gathering @exportsBundle_depsVars & infering empty depVars for `dependencies.exports.bundle`"

    errorFiles: -> _.pick @files, (f)-> f.hasErrors
      
  isCalcPropDepsVars = (p)-> _(p).endsWith 'depsVars'
  isCalcPropFiles = (p)-> p in ['filenames', 'dstFilenames', 'fileResources', 'textResources', 'modules', 'copyFiles', 'errorFiles']

  Object.defineProperties @::,
    doneOK: get: -> _.isEmpty(@errorFiles) and (@errorsCount is 0)

  ###
  Gathers dependencies & corresponding variables/parameters (they bind with),
  througout this bundle (all modules).

  @param {Function} depFltr a filter, passed a Dependency instance

  @return {dependencies.depsVars} `dependency: ['var1', 'var2']` eg
    {
        'lodash': ['_']
        'jquery': ["$", "jQuery"]
        'models/PersonModel': ['persons', 'personsModel']
    }
  ###
  getDepsVars: (depFltr=->true)->
    depsVars = {}
    for k, mod of @modules
      for dep, vars of mod.getDepsVars(depFltr)
        dv = (depsVars[dep] or= [])
        dv.push v for v in vars when v not in dv
    depsVars

  # Attempts to infer varNames from bundle, for those deps that have empty varNames
  # @param depVars {Object} with {dep:varNames} eg {dep1:['dep1Var1', 'dep1Var2'], dep2:[...]}
  # return depVars, with missing varNames added
  inferEmptyDepVars: (depVars = {}, whyMessage, throwOnMissing = true)->
    if !_.isEmpty(depVars) and l.deb(70)
      l.debug 'inferEmptyDepVars:', whyMessage
      l.debug 80, 'inferEmptyDepVars(depVars = ', depVars
    for depName of depVars
      if _.isEmpty (depVars[depName] or= [])

        l.deb "inferEmptyDepVars : Dependency '#{depName}' has no corresponding parameters/variable names to bind with." if l.deb(80)
        for aVar in (@getDepsVars((dep)->dep.name(relative:'bundle') is depName)[depName] or [])
          depVars[depName].push aVar if aVar not in depVars[depName]

        l.deb "inferEmptyDepVars: Dependency '#{depName}', inferred varNames from bundle's Modules: ", depVars[depName] if l.deb(80)

        if _.isEmpty depVars[depName] # pick from @bundle.dependencies.[depsVars, _KnownDepsVars, ... ] etc
          for depVarsPath in _.map(['depsVars', '_knownDepsVars','exports.bundle', 'exports.root'], (v)-> 'dependencies.' + v)
            dependenciesDepsVars = _B.getp @, depVarsPath, {separator:'.'}
            if (not _.isEmpty dependenciesDepsVars[depName]) and (depVars[depName] isnt dependenciesDepsVars[depName])
              l.warn "#{whyMessage}:\n", "Picking var bindings for `#{depName}` from `@#{depVarsPath}`", dependenciesDepsVars[depName]
              for aVar in dependenciesDepsVars[depName]
                depVars[depName].push aVar if aVar not in depVars[depName]

      if throwOnMissing and _.isEmpty depVars[depName]
        @handleError new UError """
          No variable names can be identified for injected or local or node-only dependency '#{depName}'.

          These variable names are used to :
            - inject the dependency into each module
              OR
            - grab the dependency from the `window` object, when running as <script> via the 'combined' template.

          Remedy:

          If you are injecting eg. at uRequire's config 'bundle.dependencies.exports.bundle', you 'd better declare it as:
            ```
              dependencies: exports: bundle: {
                '#{depName}': 'VARIABLE(S)_IT_BINDS_WITH',
                ...
                jquery: ['$', 'jQuery'],  // Array of known bindings
                backbone: 'Backbone'      // A String will also do
              }
            ```
          instead of the simpler
            ```
              dependencies: exports: bundle: [ '#{depName}', ...., 'jquery', 'backbone' ]
            ```

          Alternativelly, pick one medicine :
            - define at least one module that has this dependency + variable binding (either as AMD or commonJs) and uRequire will infer it!

            - declare it in the above format, but in `bundle.dependencies.varNames` and uRequre will pick it from there!

            - use an `rjs.shim`, and uRequire will pick it from there (@todo: NOT IMPLEMENTED YET!)
        """
        l.warn @dstFilenames


    l.debug 80, 'returning inferred depVars =', depVars

    depVars

  ###
    Processes each filename, either as array of filenames (eg instructed by `watcher`) or all @filenames

    If a filename is new, create a new BundleFile (or more interestingly a TextResource or Module)

    In any case, refresh() each one, either new or existing. Internally BundleFile notes `hasChanged`. 

    @param []<String> with filenames to process.
      @default ALL files from filesystem (property @filenames)

    @return null
  ###
  loadOrRefreshResources: (filenames = @filenames)->
    l.debug """ \n
      #####################################################################
      loadOrRefreshResources: filenames.length = #{filenames.length}
      #####################################################################""" if l.deb 30

    # check which filenames match resource converters
    # and instantiate them as TextResource or Module
    When.iterate(
      (i)-> i + 1
      (i)-> !(i < filenames.length)
      (i)=>
        filename = filenames[i]
        isNew = false

        if not bf = @files[filename] # a new filename
          isNew = true
          lastSrcMain = undefined
          matchedConverters = [] # create a XXXResource (eg Module), if we have some matchedConverters
          dstFilename = filename

          # Add matched converters
          # - match filename in resConv.filez, either srcFilename or dstFilename depending on `~` flag
          # - determine its clazz from type
          # - until a terminal converter found
          for resConv in @resources
            if isFileInSpecs (if resConv.isMatchSrcFilename then filename else dstFilename), resConv.filez

              # converted dstFilename for converters `filez` matching (i.e 'myDep.js' instead of 'myDep.coffee')
              if _.isFunction resConv.convFilename
                dstFilename = resConv.convFilename dstFilename, filename

              lastSrcMain = resConv.srcMain if resConv.srcMain
              matchedConverters.push resConv

          # NOTE: last matching converter (that has a clazz) determines if file is a TextResource || FileResource || Module
          lastResourcesWithClazz =  _.filter matchedConverters, (conv)-> conv.clazz
          resourceClass = _.last(lastResourcesWithClazz)?.clazz or BundleFile       # default is BundleFile

          l.debug "New *#{resourceClass.name}*: '#{filename}'" if l.deb 80
          bf = @files[filename] = new resourceClass {
            bundle:@
            srcFilename: filename
            converters: matchedConverters
            srcMain: lastSrcMain
          }

          bf.dstFilepath_last = dstFilename # used for bf.clean()

        if bf.srcMain and @build.current[bf.srcMain]
          l.debug 60, "Skipping refresh/conversion(s) of '#{bf.srcFilename}', as part of converted @srcMain='#{bf.srcMain}'."
          return

        l.debug "Refreshing #{bf.constructor.name}: '#{filename}'" if l.deb 80

        bf.refresh().then( (isChanged)=>
          if isChanged
            @build.addChangedBundleFile filename, bf
            bf.dstFilepath_last = bf.dstFilepath
        ).catch( (err)=>
            l.debug "Error while refreshing #{bf.constructor.name}: '#{filename}'", err if l.deb 30
            @build.addChangedBundleFile filename, bf # add it as changed file in error / deleted
            if bf.srcExists
              bf.reset()
              bf.hasErrors = true #todo: why set here ?

              bf.clean()if bf.isDeleteErrored

              if err instanceof ResourceConverterError
                @handleError err #something here smells bad with error handling
              else
                @handleError new UError """
                  Unknown error while loading/refreshing/processing '#{filename}'.""", {nested:err}
            else
              delete @mainModule if @mainModule is @files[filename]
              delete @files[filename]
              l.verbose "Missing file #{bf.srcFilepath} - deleting dstFilename = '#{bf.dstFilename}'"
              if bf.dstExists and bf.hasErrors isnt 'duplicate'
                 bf.dstDelete()
              bf.hasErrors = false # dont count as error any more
        ).finally( =>  #todo: refactor
          @build.current[bf.srcMain] = true if bf.srcMain
          if isNew and not bf.srcMain # check there is no same dstFilename, unless they belong to an 'srcMain' group
            if sameDstFile = (_.find @files, (f)=> (f.dstFilename is bf.dstFilename) and (f isnt bf))
              bf.hasErrors = 'duplicate'
              @handleError new UError """
                  Same dstFilename='#{sameDstFile.dstFilename}' for new resource '#{bf.srcFilename}' & '#{sameDstFile.srcFilename}'.
                """, {nested:err}
        )
    , 0).then =>
        @cleanProps (if !_.isEmpty @build.changedFiles then isCalcPropFiles),
                    (if !_.isEmpty @build.changedModules then isCalcPropDepsVars)

        l.debug "### finished loadOrRefreshResources: #{_.size @build.changedFiles} changed files."

  ###
    Our only true entry point
    It builds / converts all resources that are passed as filenames
    It 'temporarilly' sets a @build instance, with which it 'guides' the build.
  ###
  buildChangedResources: (@build, filenames=@filenames)->
    When.promise (resolve, reject)=>
      @errorsCount = 0
      isPartialBuild = filenames isnt @filenames # 'partial' i.e 'watched' filenames
      l.debug """ \n
        #####################################################################
        buildChangedResources: build ##{build.count}
        bundle.name = #{@name}, bundle.main = #{@main}
        filenames.length = #{filenames.length} #{if !isPartialBuild then '(full build)' else ''}
        #####################################################################""" if l.deb 20

      @reporter = new DependenciesReporter()

      if isPartialBuild  # 'partial' i.e 'watched' filenames
        if not @build.hasFullBuild # force a full build ?
          l.warn "Forcing a full build (this was a partial build, without a previous full build)."
          file.reset() for fn, file of @files
          if @build.template.name is 'combined'
            @build.deleteCombinedTemp()
            l.warn "Partial/watch build with 'combined' template wont DELETE '#{@build.template._combinedFileTemp}' - when you quit 'watch'-ing, delete it your self!"

          return resolve @buildChangedResources @build, @filenames # call self, with all filesystem @filenames
           # dont run again!

        # filter filenames not passing through bundle.filez
        bundleFilenames = _.filter filenames, (f)=> isFileInSpecs(f, @filez) and f[0] isnt '.' # exclude relative paths
        if diff = filenames.length - bundleFilenames.length
          l.verbose "Ignored #{diff} non-`bundle.filez`"
          filenames = bundleFilenames
      else
        @build.doClean()

      if not filenames.length
        resolve l.verbose "No files to process."
      else
        @loadOrRefreshResources(filenames).then( =>
          if not _.isEmpty @build.changedFiles
            @convertChangedModules().then =>
              @concatMainModuleBanner()
              @saveChangedResources()
              @copyChangedBundleFiles()
              if @doneOK and !isPartialBuild and
                ((@build.template.name isnt 'combined') or @build.watch)
                  @build.hasFullBuild = true

              if (@build.template.name is 'combined')
                return resolve @combine() # return cause report & done() should run only after its finished
              else
                @build.report @
#                if l.deb 95
                l.deb "@doneOK = #{@doneOK} and #{if @doneOK then 'resolve()' else 'reject()'}"
                if @doneOK then resolve() else reject() #todo: resolve report data
          else
            l.verbose "No bundle files *really* changed."
            resolve()
        ).catch reject

  convertChangedModules:->
    if _.isEmpty @build.changedModules
      When()
    else
      changedModules = (mod for fn, mod of @modules when mod.hasChanged)
      l.debug """ \n
        #####################################################################
        Converting #{changedModules.length} changed modules with template '#{@build.template.name}'
        #####################################################################""" if l.deb 30

      When.each changedModules, (mod)=> mod.convert @build


  # add template.banner to 'bundle.main', if it exists & has changed
  concatMainModuleBanner:->
    if !_.isEmpty @build.changedModules
      if @build.template.banner and (@build.template.name isnt 'combined')
        if (@mainModule or @inferMainModule())
          if @mainModule.hasChanged
            l.debug 40, "Concating `bundle.template.banner` to `@bundle.main` file = `#{@mainModule.dstFilename}`"
            @mainModule.converted = @build.template.banner + '\n' + @mainModule.converted
        else
          l.warn "Can't concat `build.template.banner` - no @mainModule - tried `bundle.main`, `bundle.name`, 'index', 'main'."
      null

  saveChangedResources:->
    if !_.isEmpty @build.changedResources
      l.debug """ \n
        #####################################################################
        Saving changed resource files that have a `converted` String
        #####################################################################""" if l.deb 30
      for fn, res of @fileResources when res.hasChanged
        if res.hasErrors
          l.warn "Not saving with errors: '#{res.dstFilename}' (srcFilename = '#{res.srcFilename}')."
        else
          if res.converted and _.isString(res.converted) # only non-empty Strings are written
            try
              if _.isFunction @build.out
                @build.out res.dstFilename, res.converted
              else
                res.save()
            catch err
              res.hasErrors = true
              @handleError new UError """
                Error while #{if _.isFunction(@build.out) then '`build.out()`-ing' else '`save()`-ing'} resource '#{res.dstFilename}'.""", nested: err
          else
            l.debug 80, "Not saving non-String: '#{res.srcFilename}' as '#{res.dstFilename}'."

        res.hasChanged = false # @todo: multiple builds - note at @build instead of res
    null

  # All @files (i.e bundle.filez) that ARE NOT `FileResource`s and below (i.e are plain `BundleFile`s)
  # are copied to build.dstPath
  copyChangedBundleFiles: ->
    if !_.isEmpty @copyBundleFiles
      l.debug """ \n
        #####################################################################
        Copying #{_.size @copyBundleFiles} non-resources files (that match `bundle.copy`)"
        #####################################################################""" if l.deb 30
      copiedCount = skippedCount = 0
      for fn, bundleFile of @copyBundleFiles when bundleFile.hasChanged
        try
          if bundleFile.copy() then copiedCount++ else skippedCount++
          bundleFile.hasChanged = false # @todo: multiple builds - note at @build
        catch err
          bundleFile.hasErrors = true #todo : needed ?
          @handleError err

    @build._copied = [copiedCount, skippedCount]

  # ovewrites and returns @mainModule, wether found or not
  inferMainModule: ->
    if @main # respect only @main
      mainMod = _.find @modules, (m)=> m.path is @main
    else # if @main is empty, try @name, 'index', 'main'
      for mainCand in [@name, 'index', 'main'] when mainCand
        mainMod = _.find @modules, (m)-> m.path is mainCand
        break if mainMod

    @mainModule = mainMod

  requirejs: require 'requirejs'
  ###
  ###
  combine: ->
    When.promise (resolve, reject)=>
      # run only if we have changedFiles without errors
      if _.isEmpty @build.changedModules # @todo: or (!_.isEmpty(@build.changedfiles) and build.template.{combined}.noModulesBuild)
        l.verbose "Not executing *'combined' template optimizing with r.js*: no @modules changed in build ##{@build.count}."
        @build.report @
        return resolve @doneOK
      else
        if errFiles = _.size(@build.errorFiles)

          if isTrueOrFileInSpecs @build.deleteErrored, @build.template.combinedFile
            if fs.existsSync @build.template.combinedFile
              l.verbose "Deleting previous destination combined file `#{@build.template.combinedFile}` cause of #{errFiles} error files."
              try
                fs.unlinkSync upath.join @build.template.combinedFile
              catch err
                l.warn "Can't delete `#{@build.template.combinedFile}`.", err

          if (_.size(@build.changedModules) - errFiles) <= 0
              l.er "Not executing *'combined' template optimizing with r.js*: no changed modules without error in build ##{@build.count}."
              @build.report @
              return resolve @doneOK
            else
              l.warn "Executing *'combined' template optimizing with r.js*: although there are errors in build ##{@build.count} (using last valid saved modules)."

      l.debug """ \n
        #####################################################################
        'combined' template: optimizing with r.js & almond
        #####################################################################""" if l.deb 30

      if @mainModule or @inferMainModule()
        if not @main
          @main = @mainModule.path
          l.warn """
            `combine` template note: `bundle.main`, your *entry-point module* was missing from `bundle` config.
            It's defaulting to #{if @main is @name then '`bundle.name` = ' else ''}'#{@main
            }', as uRequire found an existing '#{@path}/#{@mainModule.srcFilename}' module in your path.
          """
      else
        combErr = """`bundle.main` should be your *entry-point module*, kicking off the bundle.
                      It is required for `combined` template execution."""
        if not @main
          @handleError new UError """
            Missing `bundle.main` from config.
            #{combErr}
            Tried to infer it from `bundle.name` = '#{@name}', or as ['index', 'main'], but no suitable module was found in bundle.
          """
        else
          @handleError new UError """
            Module `bundle.main` = '#{@main}' not found in bundle.
            #{combErr}
            NOT trying to infer from `bundle.name` = '#{@name}', nor as ['index', 'main'] - `bundle.main` is respected.
          """

      combinedTemplate = new AlmondOptimizationTemplate @
      for depfilename, genCode of combinedTemplate.dependencyFiles
        TextResource.save upath.join(@build.template._combinedFileTemp, depfilename+'.js'), genCode

      @copyAlmondJs()
      @copyWebMapDeps()

      rjsConfig =
        paths: _.extend combinedTemplate.paths, @getRequireJSConfig().paths
        wrap: combinedTemplate.wrap
        baseUrl: @build.template._combinedFileTemp
        include: [@main]

        # include the 'fake' AMD files 'getExcluded_XXX'
        # and `export: bundle` deps
        # @todo: why 'rjs.deps' and not 'rjs.include' ?
        deps: _.union _.keys(@nodeOnly_depsVars), _.keys(combinedTemplate.exportsBundle_bundle_depsVars)
        useStrict: if @build.useStrict or _.isUndefined(@build.useStrict) then true else false # any truthy or undefined instructs `true`
        name: 'almond'

        out: (text)=>
          text =
            (if @build.template.banner then @build.template.banner + '\n' else '') +
            combinedTemplate.uRequireBanner +
            "// Combined template optimized with RequireJS/r.js v#{@requirejs.version} & almond." + '\n' +
            text

          FileResource.save @build.template.combinedFile, text

      # todo: re-move this to blendConfigs
      if rjsConfig.optimize = @build.optimize                # set if we have build:optimize: 'uglify2',
        rjsConfig[@build.optimize] = @build[@build.optimize] # copy { uglify2: {...uglify2 options...}}
      else
        rjsConfig.optimize = "none"
      rjsConfig.logLevel = 0 if l.deb 90


      #@todo: blend it !
      if not _.isEmpty @build.rjs
        _.defaults rjsConfig, _.clone(@build.rjs, true)

      # actually combine (r.js optimize)
      l.debug("requirejs.optimize (v#{@requirejs.version}) with uRequire's 'build.js' = \n", _.omit(rjsConfig, ['wrap'])) if l.deb 20
      rjsStartDate = new Date()
      @requirejs.optimize rjsConfig,
        (buildResponse)=>
          l.debug '@requirejs.optimize rjsConfig, (buildResponse)-> = ', buildResponse if l.deb 20
          if fs.existsSync @build.template.combinedFile
            l.ok "Combined file '#{@build.template.combinedFile}' written successfully for build ##{@build.count}, rjs.optimize took #{(new Date() - rjsStartDate) / 1000 }secs ."

            if not _.isEmpty @localNonNode_depsVars
              if (not @build.watch) or l.deb 50
                l.verbose "\nDependencies: make sure the following `local` depsVars bindinds:\n",
                  combinedTemplate.localDepsVars,
                  """\n
                  are available when combined script '#{@build.template.combinedFile}' is running on:
                    a) nodejs: they should exist as a local `nodes_modules`.
                    b) Web/AMD: they should be declared as `rjs.paths` (and/or `rjs.shim`)
                    c) Web/Script: the binded variables (eg '_' or '$')
                       must be a globally loaded (i.e `window.$`)
                       BEFORE loading '#{@build.template.combinedFile}'\n
                  """

            # delete _combinedFileTemp, used as temp directory with individual AMD files
            if not (l.deb(debugLevelSkipTempDeletion) or @build.watch)
              @build.deleteCombinedTemp()
            else
              l.debug(10, "NOT Deleting temporary directory '#{@build.template._combinedFileTemp}', due to build.watch || debugLevel >= #{debugLevelSkipTempDeletion}.")

            @build.report @
            resolve @doneOK
          else
            l.er """
              Combined file '#{@build.template.combinedFile}' NOT written - this should not have happened, requirejs reported success.
              Check requirejs's build response:\n
            """, buildResponse
            @build.report @
            reject false

        (errorResponse)=>
          @build.report @

          l.er '@requirejs.optimize errorResponse: ', errorResponse, """\n
          Combined file '#{@build.template.combinedFile}' NOT written."

            Some remedy:

             a) Is your *bundle.main = '#{@main}'* or *bundle.name = '#{@name}'* properly defined ?
                - 'main' should refer to your 'entry' module, that requires all other modules - if not defined, it defaults to 'name'.
                - 'name' is what 'main' defaults to, if its a module.

             b) Perhaps you have a missing dependcency ?
                r.js doesn't like this at all, but it wont tell you unless logLevel is set to error/trace, which then halts execution.

             c) Re-run uRequire with debugLevel >=90, to enable r.js's logLevel:0 (trace).
                *Note this prevents uRequire from finishing properly / printing this message!*

             Note that you can check the AMD-ish files used in temporary directory '#{@build.template._combinedFileTemp}'.

             More remedy on the way... till then, you can try running r.js optimizer your self, based on the following build.js: \u001b[0m

          """, rjsConfig

          reject false


  getRequireJSConfig: -> #@todo:(7 5 2) HOW LAME - remove & fix this!
    if not _.isEmpty @build?.rjs
      @build.rjs
    else
      {}

  Object.defineProperties @::,

    mergedPreDefineIIFECode: get: ->
      l.debug "Merging pre-Define IIFE code from all #{_.keys(@modules).length} @modules" if l.deb 80
      cm = new CodeMerger
      for m, mod of @modules
        cm.add mod.AST_preDefineIIFENodes

      toCode cm.AST, format:indent:base: 1

    mergedCode: get: ->
      l.debug "Merging mergedCode code from all #{_.keys(@modules).length} @modules" if l.deb 80
      cm = new CodeMerger
      for m, mod of @modules
        cm.add mod.mergedCode

      toCode cm.AST, format:indent:base: 1

  copyAlmondJs: ->
    try # copy almond.js from node_modules -> build.template._combinedFileTemp
      BundleFile.copy(
        "#{__dirname}/../../../node_modules/almond/almond.js"      # from
        upath.join(@build.template._combinedFileTemp, 'almond.js') # to
      )
    catch err
      @build.handleError new UError """
        uRequire: error copying almond.js from uRequire's installation node_modules - is it installed ?
        Tried: '#{__dirname}/../../../node_modules/almond/almond.js'
      """, nested:err

  ###
   Copy all bundle's webMap dependencies to build.template._combinedFileTemp
   @todo: use path.join
   @todo: should copy dep.plugin & dep.resourceName separatelly
  ###
  copyWebMapDeps: ->
    webRootDeps = _.keys @getDepsVars (dep)->dep.isWebRootMap
    if not _.isEmpty webRootDeps
      l.verbose "Copying webRoot deps :\n", webRootDeps
      for depName in webRootDeps
#        BundleFile.copy     "#{@webRoot}#{depName}",         # from
#                            "#{@build.template._combinedFileTemp}#{depName}"    # to
        l.er "NOT IMPLEMENTED: copyWebMapDeps #{@webRoot}#{depName}, #{@build.template._combinedFileTemp}#{depName}"
    null

  printError: (error, nesting=0)->
    if not error
      l.er "printError: NO ERROR (#{error})"
    else
      if not error.printed
        error.printed = true
        l.er "printError ##{nesting}:", (error?.constructor?.name or "No error.constructor.name"),
             "\n #{_.repeat('    ', nesting)}",
             (if error.message
                "error.message = #{error.message}"
              else error)

        l.deb 110, '\n error.stack = \n', error.stack # dev only

        if error.nested
          l.warn "with nested ##{nesting+1} error following .... :"
          @printError error.nested, nesting+1

  # @todo: refactor error handling!
  handleError: (error)->
    @printError error
    error or= new UError "Undefined or null error!"

    @errorsCount++
    if error.quit
      throw error # 'gracefully' quit: caught by bundleBuilder.buildBundle
    else
      if @build
        if (@build.continue or @build.watch)
          l.warn "Continuing despite of error due to `build.continue` || `build.watch`"
        else
          error.quit = true
          throw error #'gracefully' quit: caught by bundleBuilder.buildBundle

      else # we have no build to guide us - be optimistic
        l.warn "Continuing despite of error, cause we have not one build (i.e we might have many!)"
    null

module.exports = Bundle

_.extend module.exports.prototype, {l, _, _B}