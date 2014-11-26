_.mixin (require 'underscore.string').exports()
fs = require 'fs'
globExpand = require 'glob-expand'
umatch = require 'umatch'
upath = require 'upath'

When = require '../promises/whenFull'
execP = When.node.lift require("child_process").exec

try bower = require "bower" catch err

# uRequire
MasterDefaultsConfig = require '../config/MasterDefaultsConfig'
Dependency = require '../fileResources/Dependency'
DependenciesReporter = require './../utils/DependenciesReporter'
ResourceConverterError = require '../utils/ResourceConverterError'

BundleFile = require './../fileResources/BundleFile'
FileResource = require './../fileResources/FileResource'
TextResource = require './../fileResources/TextResource'
Module = require './../fileResources/Module'

Build = require './Build'
BundleBase = require './BundleBase'

CodeMerger = require '../codeUtils/CodeMerger'
toCode = require '../codeUtils/toCode'

{shimBlender, dependenciesBindingsBlender} = require '../config/blendConfigs'

class Bundle extends BundleBase

  constructor: (bundleCfg)->
    super
    _.extend @, bundleCfg
    @files = {}  # all bundle files are in this map

  inspect: -> "Bundle:" + l.prettify { @target, @name, @main, @path, @filez, @files }

  isCalcPropDepsVars = (p)-> _(p).endsWith 'depsVars'
  isCalcPropFiles = (p)-> p in ['filenames', 'dstFilenames', 'fileResources', 'textResources', 'modules', 'copyFiles', 'errorFiles']

  # these are using _B.CalcCachedProperties functionality.
  # They are cached 1st time accessed.
  # They are cleaned with
  #   `@cleanProps 'propName1', ((p)-> true),  'propName1'
  # or `cleanProps()` to clean all.
  @calcProperties:

    filenames:->
      if _.isEmpty @files
        _.filter globExpand({cwd: @path, filter: 'isFile'}, '**/*'), (f)=> umatch f, @filez #our initial filenames
      else
        _.keys @files

    dstFilenames:-> # dstFilenames & dstFilenamesSaved - used by `Dependency` to know if dep.isFound
      _.reduce @files,
        (fnames, f)->
          fnames.push f.dstFilename
          if _.size(f.dstFilenamesSaved) > 1 # has many saved names
            for fn in f.dstFilenamesSaved when fn isnt f.dstFilename
              fnames.push fn
          fnames
        []

    # mainModule, as declared in `bundle.main` or infered as @name, 'index' or 'main'
    mainModule: ->
      if @main # respect only @main
        mainMod = _.find @modules, (m)=> m.path is @main
      else
        if _.size(@modules) is 1
          mainMod = _.find @modules
        else # if @main is empty and we have many, try @name, 'index', 'main'
          for mainCand in [@name, 'index', 'main'] when mainCand
            mainMod = _.find @modules, (m)-> m.path is mainCand
            break if mainMod
      mainMod

    # all of these hold instances of Module, TextResource etc
    fileResources:-> _.pick @files, (f)-> f instanceof FileResource       # includes TextResource & Module

    textResources:-> _.pick @files, (f)-> f instanceof TextResource       # includes Module

    modules:-> _.pick @files, (f)-> f instanceof Module                   # just Modules

    errorFiles: -> _.pick @files, (f)-> f.hasErrors

    ###  XXX_depsVars: format {dep1:['dep1Var1', 'dep1Var2'], dep2:[...], ...} ###

    # from *modules* only (non-module depVars (eg imports) are injected on modules, BUT NOT on `combined`)

    modules_depsVars:->
      @inferEmptyDepVars @getModules_depsVars(), 'modules_depsVars', false

    modules_localNonNode_depsVars: ->
      @inferEmptyDepVars (@getModules_depsVars (dep)-> dep.isLocal and not dep.isNode), 'modules_localNonNode_depsVars'

    modules_localNode_depsVars: ->
      @inferEmptyDepVars (@getModules_depsVars (dep)-> dep.isLocal and dep.isNode), 'modules_localNode_depsVars', false

    modules_local_depsVars: ->
      dependenciesBindingsBlender.blend {}, @modules_localNonNode_depsVars, @modules_localNode_depsVars

    modules_node_depsVars:-> # also gets `nodeLocal`
      @inferEmptyDepVars (@getModules_depsVars (dep)-> dep.isNode), 'modules_node_depsVars', false

    # from imports only

    imports_depsVars:->
      @inferEmptyDepVars @getImports_depsVars(), 'imports_depsVars'

    imports_nonNode_depsVars:->
      @inferEmptyDepVars @getImports_depsVars( (d)-> not d.isNode ), 'imports_nonNode_depsVars'

    imports_bundle_depsVars:->  #i.e, bundle deps like 'agreement/isAgree'
      @inferEmptyDepVars @getImports_depsVars( (d)-> d.isBundle ), 'imports_bundle_depsVars'

    imports_local_nonNode_depsVars:->
      @inferEmptyDepVars @getImports_depsVars( (d)-> d.isLocal and not d.isNode ), 'imports_local_nonNode_depsVars'

    # from both modules & imports

    local_depsVars: -> #
      dependenciesBindingsBlender.blend {}, @modules_local_depsVars,
                                            @getImports_depsVars (d)-> d.isLocal

    local_nonNode_depsVars: -> # includes module & imports
      dependenciesBindingsBlender.blend {}, @modules_localNonNode_depsVars,
                                            @getImports_depsVars (d)-> d.isLocal and not d.isNode

    local_node_depsVars: -> # includes module & imports
      dependenciesBindingsBlender.blend {}, @modules_localNode_depsVars,
                                            @getImports_depsVars (d)-> d.isLocal and d.isNode

  # special cases

    nonImports_local_depsVars: -> # imports are injected onto modules on non-combined - the real module-only declared ones
      _.pick @modules_local_depsVars, (vars, dep)=> not @dependencies.imports[dep]

    # gather from all known depVars places
    all_depsVars:->
      depVarObjectPaths = (_.map ['depsVars', 'rootExports'], (v)-> 'dependencies.' + v) #todo: gather from @modules.flags.rootExports
                            .concat ['modules_depsVars', 'imports_depsVars']

      (allDepVarObjs = (_B.getp @, depVarsPath, {separator:'.'} for depVarsPath in depVarObjectPaths)).unshift {}
      dependenciesBindingsBlender.blend.apply null, allDepVarObjs

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
  getModules_depsVars: (depFltr=->true)->
    dependenciesBindingsBlender.blend.apply null, (mod.getDepsVars(depFltr) for k, mod of @modules)

  getImports_depsVars: (depFltr=->true)->
    _.pick @dependencies.imports, (vars, dep)=> depFltr new Dependency(dep, _.find @modules) # _.find returns a random module - it shouldn't matter cause we should only use bundleRelative on `imports`

  # Attempts to infer varNames from bundle, for those deps that have empty varNames
  # @param depVars {Object} with {dep:varNames} eg {dep1:['dep1Var1', 'dep1Var2'], dep2:[...]}
  # return depVars, with missing varNames added
  inferEmptyDepVars: (depVars = {}, whereFrom, throwOnMissing = true)->
    whyMessage = "infer empty depVars (#{if throwOnMissing then 'MANDATORY' else 'OPTIONAL'}) for `@#{whereFrom or 'UNKNOWN'}`."
    if !_.isEmpty(depVars) and l.deb(80)
      l.debug whyMessage, 'depVars = \n', depVars

    for depName of depVars
      if _.isEmpty (depVars[depName] or= [])

        l.deb "inferEmptyDepVars : Dependency '#{depName}' has no corresponding parameters/variable names to bind with." if l.deb(80)
        for aVar in (@getModules_depsVars((dep)->dep.name(relative:'bundle') is depName)[depName] or [])
          depVars[depName].push aVar if aVar not in depVars[depName]

        l.deb "inferEmptyDepVars: Dependency '#{depName}', inferred varNames from bundle's Modules: ", depVars[depName] if l.deb(80)

        if _.isEmpty depVars[depName] # pick from @bundle.dependencies.[depsVars, _KnownDepsVars, ... ] etc
          for depVarsPath in _.map(['depsVars', '_knownDepsVars', 'imports', 'rootExports'], (v)-> 'dependencies.' + v)
            dependenciesDepsVars = _B.getp @, depVarsPath, {separator:'.'}
            if (not _.isEmpty dependenciesDepsVars?[depName]) and (depVars[depName] isnt dependenciesDepsVars[depName])
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

          If you are injecting eg. at uRequire's config 'bundle.dependencies.imports', you 'd better declare it as:
            ```
              dependencies: imports: {
                '#{depName}': 'VARIABLE(S)_IT_BINDS_WITH',
                ...
                jquery: ['$', 'jQuery'],  // Array of known bindings
                backbone: 'Backbone'      // A String will also do
              }
            ```
          instead of the simpler
            ```
              dependencies: imports: [ '#{depName}', ...., 'jquery', 'backbone' ]
            ```

          Alternativelly, pick one medicine :
            - define at least one module that has this dependency + variable binding (either as AMD or commonJs) and uRequire will infer it!

            - declare it in the above format, but in `bundle.dependencies.varNames` and uRequre will pick it from there!

            - use an `rjs.shim`, and uRequire will pick it from there (@todo: NOT IMPLEMENTED YET!)
        """

    l.debug 80, 'returning inferred depVars =', depVars
    depVars

  getBundleFile: (filename)->
    if not bf = @files[filename] # a new filename
      # check which ResourceConverters match filename
      # and instantiate it as BundleFile | FileResource | TextResource | Module
      lastSrcMain = undefined
      matchedConverters = [] # create a XXXResource (eg Module), if we have some matchedConverters
      dstFilename = filename

      # Add matched converters
      # - match filename in resConv.filez, either srcFilename or dstFilename depending on `~` flag
      # - determine its clazz from type
      # - until a terminal converter found
      for resConv in @resources
        if umatch (if resConv.isMatchSrcFilename then filename else dstFilename), resConv.filez

          # converted dstFilename for converters `filez` matching (i.e 'myDep.js' instead of 'myDep.coffee')
          if _.isFunction resConv.convFilename
            dstFilename = resConv.convFilename dstFilename, filename

          lastSrcMain = resConv.srcMain if resConv.srcMain
          matchedConverters.push resConv

      if lastSrcMain and lastSrcMain not in @filenames
        throw new UError "srcMain = '#{lastSrcMain}' doesn't exist in bundle's source filenames.", quit: true

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

      # duplicate check: check there's no same dstFilename, unless they belong to an 'srcMain' group
      if not bf.srcMain
        if sameDstFile = _.find(@files, (f)=> (f.dstFilename is dstFilename) and f isnt bf)
          sameDstFile.hasErrors = bf.hasErrors = 'duplicate' # @todo: improve lame duplicate check while watching
          @handleError new UError """
            Same dstFilename='#{sameDstFile.dstFilename}' for new resource '#{bf.srcFilename}' & '#{sameDstFile.srcFilename}'.
          """
    bf

  ###
    Processes each filename, either as array of filenames (eg instructed by `watcher`) or all @filenames

    For each filename it retrieves the BundleFile (or subclass) instance and calls refresh()

    @param []<String> with filenames to process.
      @default ALL files from filesystem (property @filenames)

    @return null
  ###
  loadOrRefreshResources: (filenames = @filenames)->
    l.debug """ \n
      #####################################################################
      loadOrRefreshResources: filenames.length = #{filenames.length}
      #####################################################################""" if l.deb 30

    When.iterate(
      (i)-> i + 1
      (i)-> !(i < filenames.length)
      (i)=>
        bf = @getBundleFile filename = filenames[i]

        if bf.srcMain # part of srcMain group
          if filename isnt bf.srcMain
            l.debug 60, "Skipping conversion(s) of '#{bf.srcFilename}', as part of @srcMain='#{bf.srcMain}'."

            if not @build.current['srcMain_inBuild']
              if bf.srcMain not in filenames # of this build cycle
                l.debug 60, "Forcing conversion of @srcMain='#{bf.srcMain}' triggered by '#{bf.srcFilename}'."
                filenames.push bf.srcMain
              @build.current['srcMain_inBuild'] = true

              # reset srcMain bundleFiles's attributes if already loaded
              @files[bf.srcMain].reset() if @files[bf.srcMain]

            return

        l.debug "Refreshing #{bf.constructor.name}: '#{filename}'" if l.deb 80

        bf.refresh().then( (isChanged)=>
          if isChanged
            @build.addChangedBundleFile filename, bf
        ).catch (err)=>
            l.debug "Error while refreshing #{bf.constructor.name}: '#{filename}'", err if l.deb 30
            @build.addChangedBundleFile filename, bf # add it as changed file in error / deleted
            if bf.srcExists
              bf.clean() if bf.isDeleteErrored
              bf.reset()
              bf.hasErrors = true
              if err instanceof UError
                @handleError err # improve error handling
              else
                @handleError new UError """
                  Unknown error while loading/refreshing/processing '#{filename}'.""", {nested:err}
            else
              delete @files[filename]
              l.verbose "Missing file #{bf.srcFilepath} - deleting dstFilename = '#{bf.dstFilename}'"
              bf.clean() if bf.hasErrors isnt 'duplicate'
              bf.hasErrors = false # dont count as error any more

    , 0).then =>
        @cleanProps (if !_.isEmpty @build.changedFiles then isCalcPropFiles),
                    (if !_.isEmpty @build.changedModules then isCalcPropDepsVars)

        l.debug "### finished loadOrRefreshResources: #{_.size @build.changedFiles} changed files."

  ###
    Our only true entry point
    It builds / converts all resources that are passed as filenames
    It 'temporarilly' sets a @build instance, with which it 'guides' the build.
  ###
  buildChangedResources: When.lift (@build, filenames=@filenames)->
    @build.newBuild()
    l.debug """ \n
      #####################################################################
      buildChangedResources: build ##{build.count}
      bundle.name = #{@name}, bundle.main = #{@main}, build.target = #{@build.target}
      #####################################################################""" if l.deb 20

    file.hasChanged = false for fn, file of @files

    if isPartialBuild = filenames isnt @filenames # 'partial' i.e 'watched' filenames
      if not @hasFullBuild # force a full build ?
        l.warn "Forcing a full build (this was a partial build, without a previous full build)."
        file.reset() for fn, file of @files
        if @build.template.name is 'combined'
          @build.deleteCombinedTemp()
          l.warn "Partial/watch build with 'combined' template wont DELETE '#{@build.template._combinedTemp}' - when you quit 'watch'-ing, delete it your self!"
        filenames = @filenames #do all @filenames
        isPartialBuild = false
      else
        # filter filenames not passing through bundle.filez
        bundleFilenames = _.filter filenames, (f)=> umatch(f, @filez) and f[0] isnt '.' # exclude relative paths
        if diff = filenames.length - bundleFilenames.length
          l.verbose "Ignored #{diff} non-`bundle.filez`"
          filenames = bundleFilenames
    else
      @build.doClean() if @build.count is 1 # dont clean each time bb.buildBundle is called

    @build.current.isPartial = isPartialBuild

    if (@build.template.name is 'combined') and !fs.existsSync(@build.template._combinedTemp) and (@build.count > 1)
      l.verbose "Resaving _combinedTemp `#{@build.template._combinedTemp}` cause build ##{@build.count} requested for `#{@build.target or 'empty build.target'}` but it was previously deleted."
      @saveResources true # all
      @copyBundleFiles true # all

    l.deb "Processing #{filenames.length} files  #{if !isPartialBuild then '(full build)' else '(partial build)'}" if l.deb 20

    if not filenames.length
      l.verbose "No files to process."
    else
      @reporter = new DependenciesReporter()
      
      @loadOrRefreshResources(filenames).then =>
        if not _.isEmpty @build.changedFiles
          @convertChangedModules().then( =>
            @concatMainModuleBanner()
            @saveResources()
            @copyBundleFiles()
            (if @build.template.name is 'combined'
                @build.combine().catch((err)=> @build.handleError err)
             else
                When()
            ).then =>
              @runAfterSaveConverters().then =>
                @fillDepsInfo()
          ).catch( (err)=>
            @build.handleError err
          ).finally =>
            @build.finishBuild()
        else
          l.verbose "No bundle files *really* changed."
          if not _.isEmpty(@errorFiles)
            @build.handleError new Error "There are still #{_.size @errorFiles} files with errors in bundle:\n" + l.prettify @errorFiles
          @build.finishBuild()

  localPathsCacheFile = '.urequire-local-deps-cache.json'
  fillDepsInfo: When.lift ->
    if (@build.count is 1) and #only once for each build @todo: or when deps change ?
      (@dependencies.paths.bower or @dependencies.paths.npm)
        l.debug """ \n
          #####################################################################
          fillDepsInfo: bundle.name = #{@name}, bundle.main = #{@main}, build.target = #{@build.target}
          #####################################################################""" if l.deb 30

        @useLocalCache().then( (cache)=>
          dirtyCache = {}

          When.sequence [ #todo: revise the whole caching / dirtying strategy to a more transparent one
            =>
              if @dependencies.paths.bower
                When(
                  if _.isEmpty cache.bower
                    @getBowerPaths().then (bowerPaths)-> dirtyCache.bower = bowerPaths
                  else
                    cache.bower
                ).then (bowerPaths)=>
                  l.deb 40, "Blending `bundle.dependencies.paths.bower`"
                  @dependencies.paths.bower = dependenciesBindingsBlender.blend {}, bowerPaths, @dependencies.paths.bower
              else
                When()

            =>
              if @dependencies.shim
                When(
                  if _.isEmpty(cache.shim)
                    dirtyCache.shim = @getShimDeps()
                  else
                    cache.shim
                ).then (bowerShims)=> # fill in `exports` from bundle's depVars
                  for bowerDep of bowerShims
                    if _.isEmpty(bowerShims[bowerDep].exports) and !_.isEmpty(dv = @local_depsVars[bowerDep])
                      bowerShims[bowerDep].exports = dv[0] # requirejs `exports` support only one
                      if _.isEmpty dirtyCache.shim
                        dirtyCache.shim = bowerShims
                  l.deb 40, "Blending `bundle.dependencies.shim`"
                  @dependencies.shim = shimBlender.blend {}, bowerShims, @dependencies.shim
            =>
              if @dependencies.paths.npm
                When(
                  if _.isEmpty cache.npm
                    @getNpmPaths().then (npmPaths)-> dirtyCache.npm = npmPaths
                  else
                    cache.npm
                ).then (npmPaths)=>
                  l.deb 40, "Blending `bundle.dependencies.paths.npm`"
                  @dependencies.paths.npm = dependenciesBindingsBlender.blend npmPaths, @dependencies.paths.npm
              else
                When()
            =>
              if !_.isEmpty(dirtyCache) and @dependencies.paths.useCache
                l.verbose "Saving dirty paths cache to `#{localPathsCacheFile}`"
                fs.writeFileP localPathsCacheFile, JSON.stringify(_.extend(cache, dirtyCache), null, 2)
              else
                When()
          ]
        ).catch (err)=>
           @build.handleError new UError "Error while filling `bundle.dependencies.paths`", nested: err

  useLocalCache: ->
    fs.existsP(localPathsCacheFile).then (isExists)=>
      if isExists
        if @dependencies.paths.useCache
          l.deb 60, "Loading local paths cache `#{localPathsCacheFile}`"
          fs.readFileP(localPathsCacheFile).then(JSON.parse).then (cache)=>
            if _.isEmpty cache
              l.warn "Deleting local paths cache `#{localPathsCacheFile}` cause its empty."
              fs.unlinkP(localPathsCacheFile).yield {}
            else
              l.deb 40, "Local paths cache `#{localPathsCacheFile}` loaded"
              cache
        else
          l.deb 40, "Deleting local paths cache `#{localPathsCacheFile}` cause `@dependencies.paths.useCache` is falsey."
          fs.unlinkP(localPathsCacheFile).yield {}
      else
        {}

  getNpmPaths: ->
    l.deb 30, "Getting local npm paths (using `package.json` information)"
    if _.isEmpty @package
      throw new UError "`package.json` is missing / empty, cant fill `bundle.dependencies.paths.npm`"

    depPaths = {}
    for deps in [@package.dependencies, @package.devDependencies]
      for dep of deps
        try
          pkg = JSON.parse fs.readFileSync "node_modules/#{dep}/package.json"
          depPaths[dep] = upath.join "node_modules", dep, pkg.main
        catch err
          @build.handleError new UError "Error while getting local npm paths (using `package.json` information)", nested: err

    When depPaths

  # resolves to bower paths JSON object
  getBowerPaths: ->
    l.deb 30, "Getting local bower paths"
    When(
      if bower
        l.verbose "Getting offline bower paths from `require('bower')` module"
        When.promise (resolve, reject)->
          bcl = bower.commands.list {paths: true, offline:true}
          bcl.on 'end', (result)-> resolve result
          bcl.on 'error', (err)-> reject err
      else
        cmd = "bower list --paths --json --offline"
        l.verbose "Getting offline bower paths from CLI exec `#{cmd}`"
        execP(cmd).spread JSON.parse
    ).then (bowerPaths)->
      throw new UError "Bower returned empty - run `bower install`" if _.isEmpty bowerPaths
      bowerPaths

  # todo: `bower.commands.info dep, {offline:true}` is problematic https://github.com/bower/bower/issues/1601
  getShimDeps: ->
    l.verbose "Getting local bower shims using bower paths info"
    _.mapValues @dependencies.paths.bower, (paths, bowerPackage)=>
      path = if _.isArray paths then paths[0] else paths
      deps: _.keys JSON.parse(
          fs.readFileSync path[0..path.indexOf(bowerPackage)+bowerPackage.length] + '.bower.json', 'utf8'
        ).dependencies

  runAfterSaveConverters: ->
    changedFileResources = (file for fn, file of @fileResources when file.hasChanged and not file.hasErrors)
    if changedFileResources.length
      l.debug """ \n
        #####################################################################
        Running `runAt: 'afterSave'` ResourceConverters for #{changedFileResources.length} changed `FileResource`s.
        #####################################################################""" if l.deb 30
    When.each changedFileResources, (f)=>
      f.hasChanged = false # temporarilly
      f.runResourceConverters((rc)-> rc.runAt is 'afterSave').then ->
        f.save() if f.hasChanged
        f.hasChanged = true # revert always

  convertChangedModules:->
    changedModules = (mod for fn, mod of @modules when mod.hasChanged and not mod.hasErrors)
    if changedModules.length
      l.debug """ \n
        #####################################################################
        Converting #{changedModules.length} changed modules with template '#{@build.template.name}'
        #####################################################################""" if l.deb 30

    When.each changedModules, (mod)=> mod.convert @build # return promise

  # add template.banner to 'bundle.main', if it exists & has changed
  concatMainModuleBanner:->
    if @build.template.banner and (@build.template.name isnt 'combined')
      if @mainModule
        if @mainModule.hasChanged and not @mainModule.hasErrors
          l.debug 40, "Concating `bundle.template.banner` to `@bundle.main` module dstFilename = `#{@mainModule.dstFilename}`"
          @mainModule.converted = @build.template.banner + '\n' + @mainModule.converted
      else
        l.warn "Can't concat `build.template.banner` - no @mainModule - tried `bundle.main`, `bundle.name`, 'index', 'main'."
    null

  saveResources: (all)->
    resourcesToSave = (res for fn, res of @fileResources when (res.hasChanged or all) and not res.hasErrors)
    if resourcesToSave
      l.debug """ \n
        #####################################################################
        Saving #{_.size resourcesToSave} resource files #{if all then "(all)" else "(changed)"} that have a `converted` String and no errors.
        #####################################################################""" if l.deb 30

      for res in resourcesToSave
        if (not _.isEmpty res.converted) and _.isString(res.converted) # only non-empty Strings are written
          try
            if _.isFunction @build.out
              @build.out res.dstFilename, res.converted, res
            else
              res.save()
          catch err
            res.hasErrors = true
            @handleError new UError """
              Error while #{if _.isFunction(@build.out) then '`build.out()`-ing' else '`save()`-ing'} resource '#{res.dstFilename}'.""", nested: err
        else
          l.verbose "Not saving non-String: '#{res.srcFilename}' as '#{res.dstFilename}'."

    null

  # All @files (i.e bundle.filez) that ARE NOT `FileResource`s and below (i.e are plain `BundleFile`s)
  # are copied to build.dstPath.
  copyBundleFiles: (all)->
    # filtered for copy only # todo: allow all & then filter them
    bundleFilesToCopy = _.pick @files, (f, filename)=>
      not (f instanceof FileResource) and (umatch filename, @copy) and (f.hasChanged or all)

    if !_.isEmpty bundleFilesToCopy
      l.debug """ \n
        #####################################################################
        Copying #{_.size bundleFilesToCopy} BundleFiles files #{if all then "(all)" else "(changed)"} that match `bundle.copy`."
        #####################################################################""" if l.deb 30
      copiedCount = skippedCount = 0
      for fn, bundleFile of bundleFilesToCopy
        try
          if bundleFile.copy() then copiedCount++ else skippedCount++
        catch err
          bundleFile.hasErrors = true #todo : needed ?
          @handleError err

    @build._copied = [copiedCount, skippedCount]

  ensureMain: (force=true)->
    if @mainModule
      if not @main
        @main = @mainModule.path
        l.warn """
            `bundle.main` is defaulting to #{if @main is @name then '`bundle.name` = ' else ''}'#{@main
            }', as uRequire found #{if _.size(@modules) is 1 then "only one" else "a valid main"
            } module `#{@mainModule.srcFilename}` in `bundle.path` filtered with `bundle.filez`.
          """
      @main
    else
      combErr = "`bundle.main` should be your *entry-point module*, kicking off the bundle:\n" +
          (
            if @build.template.name is 'combined'
               '   * It is the return value of the `combined` template bundle factory, i.e. the value of the whole bundle. '+
               'Without it, ALL modules will be loaded (usefull if this bundle is just `specs`), but the value of the bundle as a module will be `undefined` on AMD.\n'
             else ''
          ) +  '   * various `ResourceConverter`s & `afterBuild`ers might need it.'

      error =
        if not @main
          """
            Missing `bundle.main` from config of bundle.name=`#{@name}`, build.target=`#{@build.target}`.
            #{combErr}
            Tried to infer it from `bundle.name` = '#{@name}', or as ['index', 'main'], but no suitable module was found in bundle.
          """
        else
          """
            Module `bundle.main` = '#{@main}' not found in bundle `#{@name}`, build.target=`#{@build.target}`.
            #{combErr}
            NOT trying to infer from `bundle.name` = '#{@name}', nor as ['index', 'main'] - `bundle.main` is always respected.
          """

      if force
        @handleError new UError error
      else
        l.warn error
        null

  Object.defineProperties @::,

    package: get:->
      try pkg = JSON.parse fs.readFileSync 'package.json', encoding:'utf8' catch #ignore
      pkg or {}

    bower: get: ->
      try bow = JSON.parse fs.readFileSync 'bower.json', encoding:'utf8' catch #ignore
      bow or {}

    mergedPreDefineIIFECode: get: ->
      l.debug "Merging pre-Define IIFE code from all #{_.size @modules} @modules" if l.deb 80
      cm = new CodeMerger
      for m, mod of @modules
        cm.add mod.AST_preDefineIIFENodes

      toCode cm.AST, format:indent:base: 1

    mergedCode: get: ->
      l.debug "Merging mergedCode code from all #{_.size @modules} @modules" if l.deb 80
      cm = new CodeMerger
      for m, mod of @modules
        cm.add mod.mergedCode

      toCode cm.AST, format:indent:base: 1

  handleError: (error)-> @build.handleError error

module.exports = Bundle

_.extend module.exports.prototype, {l, _, _B}