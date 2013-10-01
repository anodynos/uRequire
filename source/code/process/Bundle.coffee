# externals
_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
fs = require 'fs'
wrench = require 'wrench'
_B = require 'uberscore'
l = new _B.Logger 'urequire/process/Bundle'
globExpand = require 'glob-expand'

# uRequire
upath = require '../paths/upath'
MasterDefaultsConfig = require '../config/MasterDefaultsConfig'
AlmondOptimizationTemplate = require '../templates/AlmondOptimizationTemplate'
Dependency = require '../fileResources/Dependency'
DependenciesReporter = require './../utils/DependenciesReporter'
UError = require '../utils/UError'

#our file system
BundleFile = require './../fileResources/BundleFile'
FileResource = require './../fileResources/FileResource'
TextResource = require './../fileResources/TextResource'
Module = require './../fileResources/Module'

Build = require './Build'
BundleBase = require './BundleBase'

isFileInSpecs = require '../utils/isFileInSpecs'

debugLevelSkipTempDeletion = 50

###
  @todo: doc it!
###
class Bundle extends BundleBase

  constructor: (bundleCfg)->
    super
    _.extend @, bundleCfg
    @files = {}  # all bundle files are in this map

  inspect: -> l.prettify { @name, @main, @files}

  # these are using _B.CalcCachedProperties functionality.
  # They are cached 1st time accessed.
  # They are cleaned with
  #   `@cleanProps 'propName1', ((p)-> true),  'propName1'
  # or `cleanProps()` to clean all.
  @calcProperties:

    filenames:->
      if _.isEmpty @files
        _.filter globExpand({cwd: @path}, '**/*.*'), (f)=> isFileInSpecs f, @filez #our initial filenames
      else
        _.keys @files

    dstFilenames:-> _.map @files, (f)-> f.dstFilename                     # just dstFilenames, used by Dependency

    fileResources:-> _.pick @files, (f)-> f instanceof FileResource       # includes TextResource & Module

    textResources:-> _.pick @files, (f)-> f instanceof TextResource       # includes Module

    modules:-> _.pick @files, (f)-> f instanceof Module                   # just Modules

    copyBundleFiles: ->
      if _.isEmpty @copy
        {}
      else
        _.pick @files, (f, filename)=> not (f instanceof FileResource) and (isFileInSpecs filename, @copy)

    # XXX_depsVars: format {dep1:['dep1Var1', 'dep1Var2'], dep2:[...], ...}
    globalDepsVars:->
      @inferEmptyDepVars (
        @getDepsVars (dep)=> # filter global & non-node
          (dep.isGlobal) and
          (dep.pluginName isnt 'node') and
          (dep.name(plugin:false) not in @dependencies.node)
        ), 'Gathering global-looking dependencies & infering empty DepVars'

    nodeOnlyDepsVars:->
      l.debug 80, "Gathering 'node'-only dependencies"
      @getDepsVars (dep)=> (dep.pluginName is 'node') or (dep.name(plugin:false) in @dependencies.node)

    exportsBundleDepsVars:->
      @inferEmptyDepVars _.clone(@dependencies.exports.bundle, true),
        "Infering empty depVars for `dependencies.exports.bundle`"

    errorFiles: -> _.pick @files, (f)-> f.hasErrors
      
  isCalcPropDepsVars = (p)-> _(p).endsWith 'depsVars'
  isCalcPropFiles = (p)-> p in ['filenames', 'dstFilenames', 'fileResources', 'textResources', 'modules', 'copyFiles', 'errorFiles']

  Object.defineProperties @::,
    doneOK: get: -> _.isEmpty(@errorFiles) and (@errorsCount is 0)

  ###
  Gathers dependencies & corresponding variables/parameters (they bind with), througout this bundle (all modules).
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
  inferEmptyDepVars: (depVars = {}, whyMessage)->
    if !_.isEmpty(depVars) and l.deb(70) then l.debug 'inferEmptyDepVars:', whyMessage
    for depName of depVars
      if _.isEmpty (depVars[depName] or= [])
        l.debug("inferEmptyDepVars : Dependency '#{depName}' has no corresponding parameters/variable names to bind with.") if l.deb 80
        for aVar in (@getDepsVars((dep)->dep.name(relative:'bundle') is depName)[depName] or [])
          depVars[depName].push aVar if aVar not in depVars[depName]

        l.debug("inferEmptyDepVars: Dependency '#{depName}', infering varNames from bundle's Modules: ", depVars[depName]) if l.deb 80

        if _.isEmpty depVars[depName] # pick from @bundle.dependencies.[depsVars, _KnownDepsVars, ... ] etc
          for depVarsPath in _.map(['depsVars', '_knownDepsVars','exports.bundle', 'exports.root'], (v)-> 'dependencies.' + v)
            dependenciesDepsVars = _B.getp @, depVarsPath, {separator:'.'}
            if (not _.isEmpty dependenciesDepsVars[depName]) and (depVars[depName] isnt dependenciesDepsVars[depName])
              l.warn "#{whyMessage}:\n", "Picking var bindings for `#{depName}` from `@#{depVarsPath}`", dependenciesDepsVars[depName]
              for aVar in dependenciesDepsVars[depName]
                depVars[depName].push aVar if aVar not in depVars[depName]


      if _.isEmpty depVars[depName]
        @handleError new UError """
          No variable names can be identified for injected or global or node-only dependency '#{depName}'.

          These variable names are used to :
            - inject the dependency into each module
              OR
            - grab the dependency from the global object, when running as <script> via the 'combined' template.

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
    l.debug """\n-
      #####################################################################
      loadOrRefreshResources: filenames.length = #{filenames.length}
      #####################################################################""" if l.deb 30
    # check which filenames match resource converters
    # and instantiate them as TextResource or Module
    for filename in filenames
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

      if bf.srcMain and @build.current[bf.srcMain]
        l.debug 60, "Skipping refresh/conversion(s) of '#{bf.srcFilename}', as part of converted @srcMain='#{bf.srcMain}'."
        continue

      l.debug "Refreshing #{bf.constructor.name}: '#{filename}'" if l.deb 80
      try
        if bf.refresh() # updates Resource.hasChanged
          @build.addChangedBundleFile filename, bf
      catch err
        @build.addChangedBundleFile filename, bf # add it as changed file in error / deleted
        if fs.existsSync bf.srcFilepath
          bf.reset()
          bf.hasErrors = true
          @handleError new UError """
            Something wrong while loading/refreshing/processing '#{filename}'.""", {nested:err}
        else
          l.verbose "Missing file #{bf.srcFilepath} - removing bundle file #{filename}"
          delete @files[filename]
          if bf.dstExists and bf.hasErrors isnt 'duplicate'
            l.verbose "Deleting file in `build.dstPath`: #{bf.dstFilepath}"
            try
                fs.unlinkSync bf.dstFilepath
            catch err
              l.er "Cant delete destination file '#{bf.dstFilepath}'."
          bf.hasErrors = false # dont count as error any more

      @build.current[bf.srcMain] = true if bf.srcMain

      if isNew and not bf.srcMain # check there is no same dstFilename, unless they belong to an 'srcMain' group
        if sameDstFile = (_.find @files, (f)=> (f.dstFilename is bf.dstFilename) and (f isnt bf))
          bf.hasErrors = 'duplicate'
          @handleError new UError """
            Same dstFilename='#{sameDstFile.dstFilename}' for new resource '#{bf.srcFilename}' & '#{sameDstFile.srcFilename}'.
          """, {nested:err}

    @cleanProps (if !_.isEmpty @build.changedFiles then isCalcPropFiles),
                (if !_.isEmpty @build.changedModules then isCalcPropDepsVars)

    l.debug "### finished loadOrRefreshResources: #{_.size @build.changedFiles} changed files."
    null
    
  ###
    Our only true entry point
    It builds / converts all resources that are passed as filenames
    It 'temporarilly' sets a @build instance, with which it 'guides' the build.
  ###
  buildChangedResources: (@build, filenames=@filenames)->
    @errorsCount = 0
    isPartialBuild = filenames isnt @filenames # 'partial' i.e 'watched' filenames
    l.debug """\n-
      #####################################################################
      buildChangedResources: build ##{build.count}
      bundle.name = #{@name}, bundle.main = #{@main}
      filenames.length = #{filenames.length} #{if !isPartialBuild then '(full build)' else ''}
      #####################################################################""" if l.deb 20

    @reporter = new DependenciesReporter()

    if isPartialBuild  # 'partial' i.e 'watched' filenames
      # force a full build ?
      if not @build.hasFullBuild
        l.warn "Forcing a full build (this was a partial build, without a previous full build)."
        file.reset() for fn, file of @files
        if @build.template.name is 'combined'
          if not l.deb(debugLevelSkipTempDeletion)
            l.debug 40, "Deleting temporary directory '#{@build.dstPath}'."
            try
              wrench.rmdirSyncRecursive @build.dstPath
            catch err
              l.debug 40, "Can't delete temp dir '#{@build.dstPath}' - perhaps it doesnt exist."
          debugLevelSkipTempDeletion = 0 # dont delete ___temp while watching
          l.warn "Partial/watch build with 'combined' template wont DELETE '#{@build.dstPath}' - when you quit 'watch'-ing, delete it your self!"

        @buildChangedResources @build, @filenames # call self, with all filesystem @filenames
        return # dont run again!

      # filter filenames not passing through bundle.filez
      bundleFilenames = _.filter filenames, (f)=> isFileInSpecs(f, @filez) and f[0] isnt '.' # exclude relative paths
      if diff = filenames.length - bundleFilenames.length
        l.verbose "Ignored #{diff} non bundle.filez"
        filenames = bundleFilenames

    if not filenames.length
      l.verbose "No files to process."
    else
      @loadOrRefreshResources filenames

      if !_.isEmpty @build.changedFiles
        @convertChangedModules()
        @saveChangedResources()
        @copyChangedBundleFiles()
        if @doneOK and !isPartialBuild and
          ((@build.template.name isnt 'combined') or @build.watch)
            @build.hasFullBuild = true

        return @combine() if (@build.template.name is 'combined') # return cause report & done after its finished

      else
        l.verbose "No bundle files *really* changed."

    @build.report @
    @build.done @doneOK

  convertChangedModules:->
    if !_.isEmpty @build.changedModules
      l.debug """\n-
        #####################################################################
        Converting changed modules with template '#{@build.template.name}'
        #####################################################################""" if l.deb 30
      for fn, mod of @modules when mod.hasChanged # if it changed, conversion needed
        if mod.hasErrors
          l.er "Not converting '#{mod.srcFilename}' cause it has errors."
        else
          try
            mod.adjust @build
            mod.runResourceConverters (rc)-> rc.isBeforeTemplate and !rc.isAfterTemplate #@todo: why ? those with both will never run?
            mod.convertWithTemplate @build
            mod.runResourceConverters (rc)-> rc.isAfterTemplate and !rc.isBeforeTemplate
            mod.addReportData()
          catch err
            mod.reset()
            mod.hasErrors = true
            @handleError new UError "Error at `convertChangedModules()`", {nested:err}
    null

  saveChangedResources:->
    if !_.isEmpty @build.changedResources
      l.debug """\n-
        #####################################################################
        Saving changed resource files that have a `converted` String
        #####################################################################""" if l.deb 30
      for fn, res of @fileResources when res.hasChanged
        if res.hasErrors
          l.er "Not saving with errors: '#{res.dstFilename}' (srcFilename = '#{res.srcFilename}')."
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
  # are copied to build.dstPath.
  copyChangedBundleFiles: ->
    if !_.isEmpty @copyBundleFiles
      l.debug """\n-
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

  inferMain: ->
    # if @main is emptry, set to name, or index, main @todo: & other sensible defaults ?
    for mainCand in [@name, 'index', 'main'] when mainCand and not @main
      mainMod = _.find @modules, (m)-> m.path is mainCand

      if mainMod
        @main = mainMod.path
        l.warn """
         combine() note: 'bundle.main', your *entry-point module* was missing from bundle config(s).
         It's defaulting to #{if @main is @name then 'bundle.name = ' else ''
         }'#{@main}', as uRequire found an existing '#{@path}/#{mainMod.srcFilename}' module in your path.
        """

    if not @main
      @handleError new UError """
        'bundle.main' is missing (after so much effort).
        No module found either as name = '#{@name}', nor as ['index', 'main'].
      """

  ###
  ###
  combine: ->
    # run only if we have changedFiles without errors
    if _.isEmpty @build.changedModules # @todo: or (!_.isEmpty(@build.changedfiles) and build.template.{combined}.noModulesBuild)
      l.verbose "Not executing *'combined' template optimizing with r.js*: no @modules changed in build ##{@build.count}."
      @build.report @
      @build.done @doneOK
      return
    else
      if _.size(@build.errorFiles)
        if (_.size(@build.changedModules) - _.size(@build.errorFiles)) <= 0
          l.er "Not executing *'combined' template optimizing with r.js*: no changed modules without error in build ##{@build.count}."
          @build.report @
          @build.done @doneOK
          return
        else
          l.warn "Executing *'combined' template optimizing with r.js*: although there are errors in build ##{@build.count} (using last valid saved modules)."

    l.debug """\n-
      #####################################################################
      'combined' template: optimizing with r.js & almond
      #####################################################################""" if l.deb 30

    @inferMain()

    almondTemplates = new AlmondOptimizationTemplate @
    for depfilename, genCode of almondTemplates.dependencyFiles
      TextResource.save upath.join(@build.dstPath, depfilename+'.js'), genCode

    @copyAlmondJs()
    @copyWebMapDeps()

    try
      fs.unlinkSync @build.combinedFile
    catch err

    rjsConfig =
      paths: _.extend almondTemplates.paths, @getRequireJSConfig().paths
      wrap: almondTemplates.wrap
      baseUrl: @build.dstPath
      include: [@main]
      deps: _.keys @nodeOnlyDepsVars # we include the 'fake' AMD files 'getNodeOnly_XXX' @todo: why 'rjs.deps' and not 'rjs.include' ?
      out: @build.combinedFile
      name: 'almond'

    if rjsConfig.optimize = @build.optimize                # set if we have build:optimize: 'uglify2',
      rjsConfig[@build.optimize] = @build[@build.optimize] # copy { uglify2: {...uglify2 options...}}
    else
      rjsConfig.optimize = "none"
    rjsConfig.logLevel = 0 if l.deb 90

    @rjsOptimize rjsConfig

  requirejs: require 'requirejs'

  # actually combine (r.js optimize)
  rjsOptimize: (rjsConfig)=>
    l.verbose "requirejs.optimize (v#{@requirejs.version}) with uRequire's 'build.js' = \n", _.omit(rjsConfig, ['wrap'])
    rjsStartDate = new Date()
    @requirejs.optimize rjsConfig,
      (buildResponse)=>
        l.debug '@requirejs.optimize rjsConfig, (buildResponse)-> = ', buildResponse if l.deb 20
        l.debug(60, 'Checking r.js output file...')
        if fs.existsSync @build.combinedFile
          l.ok "Combined file '#{@build.combinedFile}' written successfully for build ##{@build.count}, rjs.optimize took #{(new Date() - rjsStartDate) / 1000 }secs ."

          if not _.isEmpty @globalDepsVars
            if (not @build.watch) or l.deb 50
              l.verbose "Global bindinds: make sure the following global dependencies:\n", @globalDepsVars,
                """\n
                are available when combined script '#{@build.combinedFile}' is running on:

                a) nodejs: they should exist as a local `nodes_modules`.

                b) Web/AMD: they should be declared as `rjs.paths` (and/or `rjs.shim`)

                c) Web/Script: the binded variables (eg '_' or '$')
                   must be a globally loaded (i.e `window.$`) BEFORE loading '#{@build.combinedFile}'
                """

          # delete dstPath, used as temp directory with individual AMD files
          if not (l.deb(debugLevelSkipTempDeletion) or @build.watch)
            l.debug(40, "Deleting temporary directory '#{@build.dstPath}'.")
            wrench.rmdirSyncRecursive @build.dstPath
          else
            l.debug("NOT Deleting temporary directory '#{@build.dstPath}', due to build.watch || debugLevel >= #{debugLevelSkipTempDeletion}.")

          @build.report @
          @build.done @doneOK
        else
          l.er """
            Combined file '#{@build.combinedFile}' NOT written - this should not have happened, requirejs reported success.
            Check requirejs's build response:\n
          """, buildResponse
          @build.report @
          @build.done false

      (errorResponse)=>
        @build.report @

        l.er '@requirejs.optimize errorResponse: ', errorResponse, """\n
        Combined file '#{@build.combinedFile}' NOT written."

          Some remedy:

           a) Is your *bundle.main = '#{@main}'* or *bundle.name = '#{@name}'* properly defined ?
              - 'main' should refer to your 'entry' module, that requires all other modules - if not defined, it defaults to 'name'.
              - 'name' is what 'main' defaults to, if its a module.

           b) Perhaps you have a missing dependcency ?
              r.js doesn't like this at all, but it wont tell you unless logLevel is set to error/trace, which then halts execution.

           c) Re-run uRequire with debugLevel >=90, to enable r.js's logLevel:0 (trace).
              *Note this prevents uRequire from finishing properly / printing this message!*

           Note that you can check the AMD-ish files used in temporary directory '#{@build.dstPath}'.

           More remedy on the way... till then, you can try running r.js optimizer your self, based on the following build.js: \u001b[0m

        """, rjsConfig

        @build.done false


  getRequireJSConfig: -> {} #@todo:(7 5 2) HOW LAME - remove & fix this!
#      paths:
#        text: "requirejs_plugins/text"
#        json: "requirejs_plugins/json"

  Object.defineProperty @::, 'mergedPreDefineIFINodesCode', get: ->
    {isLikeCode, toCode, toAst} = Module

    l.debug "Merging pre-Define IFI declarations and statements from all #{_.keys(@modules).length} @modules, into a common section." if l.deb 80

    PreDefineIFI_Declarations = []
    PreDefineIFI_statements = []

    addbodyNode = (node)->
      if node.type is 'VariableDeclaration'
        for decl in node.declarations
          if not _.any(PreDefineIFI_Declarations, (fd)-> _.isEqual decl, fd)
            if dublicateDecl = _.find(PreDefineIFI_Declarations, (fd)-> isLikeCode {type:decl.type, id:decl.id}, fd)
              @handleError new UError """
                Duplicate var declaration while merging pre-Define IFI statements:

                #{toCode(decl)}

                is a duplicate of

                #{toCode(dublicateDecl)}
              """
            else
              l.debug 90, "Merging pre-Define IFI statements - Adding declaration of '#{decl.id.name}'"
              PreDefineIFI_Declarations.push decl
      else
        if not _.any(PreDefineIFI_statements, (fd)-> _.isEqual node, fd)
          PreDefineIFI_statements.push node

    for m, mod of @modules
      for node in (mod.AST_preDefineIFINodes or [])
        addbodyNode node

    if not _.isEmpty PreDefineIFI_Declarations
      PreDefineIFI_statements.unshift
        type: 'VariableDeclaration'
        declarations: PreDefineIFI_Declarations
        kind: 'var'

    toCode PreDefineIFI_statements
  
  copyAlmondJs: ->
    try # copy almond.js from GLOBAL/urequire/node_modules -> dstPath
      BundleFile.copy(
        "#{__dirname}/../../../node_modules/almond/almond.js" # from
        upath.join(@build.dstPath, 'almond.js')            # to
      )
    catch err
      @build.handleError new UError """
        uRequire: error copying almond.js from uRequire's installation node_modules - is it installed ?
        Tried: '#{__dirname}/../../../node_modules/almond/almond.js'
      """, nested:err

  ###
   Copy all bundle's webMap dependencies to dstPath
   @todo: use path.join
   @todo: should copy dep.plugin & dep.resourceName separatelly
  ###
  copyWebMapDeps: ->
    webRootDeps = _.keys @getDepsVars (dep)->dep.depType is Dependency.TYPES.webRootMap
    if not _.isEmpty webRootDeps
      l.verbose "Copying webRoot deps :\n", webRootDeps
      for depName in webRootDeps
#        BundleFile.copy     "#{@webRoot}#{depName}",         # from
#                            "#{@build.dstPath}#{depName}"    # to
        l.er "NOT IMPLEMENTED: copyWebMapDeps #{@webRoot}#{depName}, #{@build.dstPath}#{depName}"

  logNestedErrorMessages = (error)->
    errorMessages = error.message || error + ''
    while error.nested
      error = error.nested
      errorMessages += '\n' + error?.message
    l.er errorMessages

  handleError: (error=new UError "Undefined or null error!")->
    @errorsCount++
    if error.quit
      throw error # 'gracefully' quit: caught by bundleBuilder.buildBundle
    else
      if @build
        logNestedErrorMessages error
        if (@build.continue or @build.watch)
          l.er error
          l.warn "Continuing despite of error due to `build.continue` || `build.watch`"
        else
          error.quit = true
          throw error #'gracefully' quit: caught by bundleBuilder.buildBundle

      else # we have no build to guid us - be optimistic
        l.er error.message
        l.er "Nested error:\n", error.nested if error.nested
        l.warn "Continuing despite of error, cause we have not one build (i.e we might have many!)"
    null

module.exports = Bundle

