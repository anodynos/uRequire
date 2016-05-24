fs = require 'fs'
rimraf = require 'rimraf'
globExpand = require 'glob-expand'
moment = require 'moment'
url = require 'url'
upath = require 'upath'
umatch = require 'umatch'

# uRequire
When = require '../promises/whenFull'
isTrueOrFileMatch = require '../config/isTrueOrFileMatch'
BundleFile = require './../fileResources/BundleFile'
AlmondOptimizationTemplate = require '../templates/AlmondOptimizationTemplate'
DependenciesReporter = require './../utils/DependenciesReporter'
MasterDefaultsConfig = require '../config/MasterDefaultsConfig'

{shimBlender, dependenciesBindingsBlender} = require '../config/blendConfigs'

# circular dependencies, lazily loaded on constructor for testing
FileResource = null
Module = null

module.exports = class Build extends _B.CalcCachedProperties

  constructor: (buildCfg, @bundle) ->
    super
    _.extend @, buildCfg

    # circular dependencies, lazily loaded
    Module = require './../fileResources/Module'
    FileResource = require './../fileResources/FileResource'

    @count = 0
    @setupCombinedFile()
    @calcTemplateBanner()

  # setup the xxx___temp to output AMD-like templates & where the combined .js file
  setupCombinedFile: ->
    if (@template.name is 'combined')
      if not @template.combinedFile # assume '@dstPath' is valid
        @template.combinedFile = @dstPath
        @dstPath = upath.dirname @dstPath
        l.verbose """
            `build.template` is 'combined' and `build.template.combinedFile` is undefined:
            Setting `build.template.combinedFile` = '#{@template.combinedFile}' from `build.dstPath`
            and `build.dstPath` = '#{@dstPath}' (keeping only path.dirname)."""

      @template.combinedFile = upath.changeExt @template.combinedFile, '.js'
      @template._combinedTemp = "#{@template.combinedFile}___temp"

      if not @dstPath # only '@template.combinedFile' is defined
        @dstPath = upath.dirname @template.combinedFile
        l.verbose """
          `build.template` is 'combined' and `build.dstPath` is undefined:
           Setting `build.dstPath` = '#{@dstPath}' from `build.template.combinedFile` = '#{@template.combinedFile}'"""

      if @out
        l.warn "`build.out` is deleted due to `combined` template being used - r.js doesn't work in memory yet."
        delete @out

  calcTemplateBanner: ->
    if tb = @template.banner # updates only on instantiation, so mutate it!
      if _.isString tb
        return #leave as is
      else
        pkg = tb if _B.isHash tb

      if _.isEmpty(pkg) and _.isEmpty(pkg = @bundle.package)
        throw new UError """
          `bundle.package` is missing or empty (`package.json` not found or has errors),
           but `build.template.banner` = #{tb} requires it!
           Either set `build.template.banner` to false or a package-like `{}`
        """

      if (tb is true) or (tb is pkg)
        @template.banner = """
          /**
          * #{ pkg.name } #{ if pkg?.homepage and (pkg?.homepage isnt pkg?.repository?.url) then pkg?.homepage else ''}
          *
          * #{ pkg?.description }
          * Version #{ pkg?.version } - Compiled on #{ moment().format("YYYY-MM-DD HH:mm:ss") }
          * Repository #{ pkg?.repository?.url or pkg?.repository }
          * Copyright(c) #{ moment().format("YYYY") } #{
              if _.isString pkg.author
                pkg.author
              else
                if _B.isHash pkg.author
                  pkg.author.name + ' <' + pkg.author.email + '>' +
                    (if pkg.author.url then '(' + pkg.author.url +')' else '')
                else ''
            }
          * License #{
              pkg.license or
                if pkg.licenses
                  pkg.licenses[0]?.type + ' ' + pkg.licenses[0]?.url
                else ''
            }
          */\n"""
      else
        if _.isFunction tb
          @template.banner = tb pkg, @bundle.bower, @bundle, @
        else
          throw new Error "Unknown `build.template.banner` value type `#{_B.type tb}`."

  @templates = ['UMD', 'UMDplain', 'AMD', 'nodejs', 'combined'] # todo: move to Master config

  inspect: -> "Build:" + l.prettify { @dstPath, @template, @startDate, @count}

  Object.defineProperties @::,
    dstMainFilename: get: ->
      if @template.name is 'combined'
        upath.basename @template.combinedFile
      else
        @bundle.ensureMain().dstFilename # throws if not found

    dstMainFilepath: get: ->
      upath.join @dstPath, @dstMainFilename

    dstMainRealpath: get: ->
      upath.join process.cwd(), @dstMainFilepath

    dstRealpath: get: ->
      upath.join process.cwd(), @dstPath

    hasErrors: get: ->
      !_.isEmpty(@bundle.errorFiles) or !_.isEmpty(@errors)

  @calcProperties:

    changedModules: -> _.pick @_changed, (f) -> f instanceof Module

    changedResources: -> _.pick @_changed, (f) -> f instanceof FileResource

    changedErrorFiles: -> _.pick @_changed, (f) -> f.hasErrors

    changedFiles: -> @_changed

    hasChanged: -> not _.isEmpty @_changed

    dstPathToRoot: -> upath.relative upath.join(process.cwd(), @dstPath), process.cwd()

  calcRequireJsConfig: (toPath = @dstPath, blendWithCfg, strictDeps, ignoreDeps=[]) ->

    depPaths = dependenciesBindingsBlender.blend.apply null, [ # {dep1: [paths1...], dep2: [paths2...]}
      @bundle.dependencies.paths.override
      blendWithCfg?.paths # undefined is fine with dependenciesBindingsBlender
      @bundle.dependencies.locals
      @bundle.dependencies.paths.bower
      @rjs?.paths
      @bundle.dependencies.paths.npm
    ].reverse()          # higher in above [] means higher precedence

    if strictDeps # filter & return only needed ones, ie local non-node ones, blended & strictDeps
      strictDeps = [] if strictDeps is true

      localNonNodeDepFilter = (d) -> d.isLocal and !d.isNode
      neededDeps = _.keys(dependenciesBindingsBlender.blend {},
        @bundle.getImports_depsVars(localNonNodeDepFilter),
        @bundle.getModules_depsVars(localNonNodeDepFilter),
        blendWithCfg?.paths
      ).concat(strictDeps).map (dep) -> dep.split('/')[0] #cater for locals like 'when/callbacks'

      for dep in neededDeps
        if _.isEmpty(depPaths[dep]) and (dep not in ignoreDeps)
          throw new Error """\n
            `calcRequireJsConfig` error for build.target='#{@target}', bundle.name='#{@bundle.name}':
             Path for local non-node dependency `#{dep}` is undefined in `dependencies.paths.xxx`.

             * If you want to include this path you can either:
                 a) `$ bower install #{dep}` and set `dependencies: paths: bower: true` in your config.
                 b) `$ npm install #{dep}` and set `dependencies: paths: npm: true` in your config (but be careful cause some npm `node_modules` wont work on the browser/AMD).
                 c) manually set `dependencies: paths: override` to the `#{dep}.js` lib eg
                  `dependencies: paths: override: { '#{dep}': 'node_modules/#{dep}/path/to/#{dep}.js' }` (relative from project root, not `path`/`dstPath`)
               Then delete `urequire-local-deps-cache.json` and re-run uRequire.

             * If you want to ignore this dep add it to `ignoreDeps` (4rth param) of `calcRequireJsConfig()`

             All discovered paths (before duplicates removal) are:
            \n""" + l.prettify depPaths

    depPaths = _.pick depPaths, (p, dep) ->
      (not neededDeps or (dep in neededDeps)) and (dep not in ignoreDeps)

    pathToRoot = upath.relative upath.join(process.cwd(), toPath), process.cwd()
    depPaths =
      _.mapValues depPaths, (paths) ->
        _.uniq _.map paths, (path) ->
          if not url.parse(path).protocol
            path = upath.join pathToRoot, path
          upath.removeExt path, '.js'

    l.warn "calcRequireJsConfig: `@bundle.dependencies.shim` is not enabled - shim info will be incomplete." if not @bundle.dependencies.shim
    nonEmptyShims = _.pick(
      shimBlender.blend.apply(null, [{}, blendWithCfg?.shim, @rjs?.shim, @bundle.dependencies.shim].reverse()), # left ones have precedence
      (sh) -> (not _.isEmpty sh.deps) or (not _.isEmpty sh.exports)
    )

    rjsCfg = {
      baseUrl: if toPath is @dstPath then '.' else (
        upath.relative upath.join(process.cwd(), @dstPath),
                       upath.join(process.cwd(), toPath)
        ) or '.'

      paths: depPaths
      shim: nonEmptyShims
    }
    Object.defineProperties rjsCfg, shimSortedDeps: get:-> sortDepsByShim _.keys(depPaths), nonEmptyShims
    rjsCfg

  # Yeah, we DO need bubblesort for sort deps bu shim,
  # cause deps compare two-ways and it's the simplest n^2 way
  sortDepsByShim = (arr, shim) ->
    swap = (a, b) ->
      temp = arr[a]
      arr[a] = arr[b]
      arr[b] = temp

    for dep_i, i in arr
      for dep_j, j in arr
        if arr[i] in (shim?[arr[j]]?.deps or [])
          swap j, i
    arr

  newBuild:->
    @startDate = new Date();
    @errors = []
    @count++
    @current = {} # store user related stuff here for current build
    @_changed = {} # changed files/resources/modules
    @cleanProps()

  finishBuild:->
    if (not @hasErrors) and (not @current.isPartial)
      @bundle.hasFullBuild = @count
    @cleanUp()
    @report()

  # @todo: store all changed info in build (instead of bundle), to allow multiple builds with the same bundle!
  addChangedBundleFile: (filename, bundleFile) ->
    @_changed[filename] = bundleFile

  doClean: ->
    if @clean
      @deleteCombinedTemp() # always by default
      if _B.isTrue @clean
        if _B.isTrue (do => try fs.existsSync(@dstPath) catch er)
          if @template.name is 'combined'
            @deleteCombinedFile()
          else
            l.verbose "clean: deleting whole build.dstPath '#{@dstPath}'."
            try
              rimraf.sync @dstPath
            catch err
              l.warn "Can't delete build.dstPath dir '#{@dstPath}'.", err
        else
          l.verbose "clean: build.dstPath '#{@dstPath}' does not exist."
      else # filespecs - delete only files specified
        delFiles = _.filter(globExpand({cwd: @dstPath, filter: 'isFile'}, '**/*'), (f)=> umatch f, @clean)
        if not _.isEmpty delFiles
          l.verbose "clean: deleting #{delFiles.length} files matched with filespec", @clean
          for df in delFiles
            l.verbose "clean: deleting file '#{df = upath.join @dstPath, df}'."
            try
              fs.unlinkSync df
            catch err
              l.warn "Can't delete file '#{df}'.", err
        else
          l.verbose "clean: no files matched filespec", @clean

  deleteCombinedTemp: ->
    if @template.name is 'combined'
      if _B.isTrue (do => try fs.existsSync(@template._combinedTemp) catch er)
        l.debug 30, "Deleting temporary combined directory '#{@template._combinedTemp}'."
        try
          rimraf.sync @template._combinedTemp
        catch err
          l.warn "Can't delete temp dir '#{@template._combinedTemp}':", err

  deleteCombinedFile: ->
    if @template.name is 'combined'
      if _B.isTrue (do => try fs.existsSync(@template.combinedFile) catch er)
        l.verbose "Deleting combinedFile '#{@template.combinedFile}'."
        try
          fs.unlinkSync @template.combinedFile
        catch err
          l.warn "Can't delete combinedFile '#{@template.combinedFile}':", err

  cleanUp: ->
    if @template.name is 'combined' # delete _combinedTemp, with individual AMD modules
      if not (l.deb(skipDeleteLevel = 50) or @watch.enabled)
        @deleteCombinedTemp()
      else
        l.debug 10, "NOT Deleting temporary directory '#{@template._combinedTemp}', " +
                    "due to build.watch || debugLevel >= #{skipDeleteLevel}."

  grabAlmondJs: ->
    if not fs.existsSync almondJsDst = upath.join @template._combinedTemp, 'almond.js'
      try
        almondJsPath = require.resolve 'almond'
        BundleFile.copy almondJsPath, almondJsDst
      catch err
        @handleError new UError """
          uRequire: error copying almond.js from uRequire's installation `node_modules`.
          Tried: '#{almondJsPath}'
        """, nested:err

      @almondVersion or= JSON.parse(fs.readFileSync upath.dirname(almondJsPath)+ '/package.json').version

  ###
   Copy all bundle's webMap dependencies to build.template._combinedTemp
   @todo: use path.join
   @todo: should copy dep.plugin & dep.resourceName separatelly
  ###
  copyWebMapDeps: ->
    webRootDeps = _.keys @bundle.getModules_depsVars (dep) ->dep.isWebRootMap
    if not _.isEmpty webRootDeps
      l.verbose "Copying webRoot deps :\n", webRootDeps
      for depName in webRootDeps
#        BundleFile.copy     "#{@webRoot}#{depName}",         # from
#                            "#{@template._combinedTemp}#{depName}"    # to
        l.er "NOT IMPLEMENTED: copyWebMapDeps #{@webRoot}#{depName}, #{@template._combinedTemp}#{depName}"
    null

  requirejs: require 'requirejs'

  combine: ->
    When.promise (resolve, reject)=>
      # run only if we have changedFiles without errors
      if _.isEmpty @changedFiles # @todo: or (!_.isEmpty(@changedfiles) and build.template.{combined}.noModulesBuild)
        l.verbose "Not executing *'combined' template optimizing with r.js*: no @files changed in build ##{@count}."
        return resolve()
      else
        if errFiles = _.size(@bundle.errorFiles)
          if isTrueOrFileMatch @deleteErrored, @template.combinedFile
            @deleteCombinedFile()
            if @continue
              l.er "Executing *'combined' optimizing with r.js* although there are #{errFiles} error files in the bundle, due to `build.continue`."
            else
              l.er "Not executing *'combined' optimizing with r.js*: there are #{errFiles} error files the bundle."
              return resolve()

      l.debug """ \n
        #####################################################################
        'combined' template: optimizing with r.js & almond
        #####################################################################""" if l.deb 30

      if (not @bundle.main) and (@count is 1)
        l.warn """
          `combined` template warning: `bundle.main`, your *entry-point module* is missing from `bundle` config.
        """
        @bundle.ensureMain(false)

      combinedTemplate = new AlmondOptimizationTemplate @bundle
      for depfilename, genCode of combinedTemplate.dependencyFiles
        FileResource.save upath.join(@template._combinedTemp, depfilename+'.js'), genCode

      @grabAlmondJs()
      @copyWebMapDeps()

      rjsConfig =
        #findNestedDependencies: false # not respected - see https://github.com/jrburke/r.js/issues/747, worked around in ModuleGeneratorTemplates
        paths: combinedTemplate.paths
        wrap: combinedTemplate.wrap
        baseUrl: @template._combinedTemp
        include: if @bundle.main
                   [ @bundle.ensureMain().path ] # ensure its valid & return main, or throw
                 else
                   (upath.trimExt(mod.dstFilename) for k, mod of @bundle.modules)

        # include the 'fake' AMD files 'getExcluded_XXX',
        # `imports` deps &
        # @todo: why 'rjs.deps' and not 'rjs.include' ?
        deps: _.union _.keys(@bundle.local_node_depsVars),
                      _.keys(@bundle.imports_bundle_depsVars),
                      _.keys(@bundle.modules_node_depsVars)

        useStrict: if @useStrict or _.isUndefined(@useStrict) then true else false # any truthy or undefined instructs `true`

        name: 'almond'

        out: (text)=>
          text =
            (if @template.banner then @template.banner + '\n' else '') +
              combinedTemplate.uRequireBanner +
              "// Combined template optimized with RequireJS/r.js v#{@requirejs.version} & almond v#{@almondVersion}." + '\n' +
              text

          FileResource.save @template.combinedFile, text

      # todo: re-move this to blendConfigs
      if rjsConfig.optimize = @optimize     # set if we have build:optimize: 'uglify2',
        rjsConfig[@optimize] = @[@optimize] # copy { uglify2: {...uglify2 options...}}
      else
        rjsConfig.optimize = "none"

      rjsConfig.logLevel = 0 if l.deb 80

      #@todo: blend it !
      if not _.isEmpty @rjs
        _.defaults rjsConfig, _.clone(@rjs, true)

      # actually combine (r.js optimize)
      l.deb 40, "Executing requirejs.optimize (v#{@requirejs.version}) / almond (v#{@almondVersion}) with uRequire's 'build.js' = \n", _.omit(rjsConfig, ['wrap'])
      rjsStartDate = new Date()

      @requirejs.optimize rjsConfig,
        (buildResponse)=>
          l.debug 'requirejs.optimize rjsConfig, (buildResponse) -> = ', buildResponse if l.deb 40
          if fs.existsSync @template.combinedFile
            l.ok "Combined file '#{@template.combinedFile}' written successfully for build ##{@count}, rjs.optimize took #{(new Date() - rjsStartDate) / 1000 }secs ."

            if not _.isEmpty @bundle.modules_localNonNode_depsVars
              if (not @watch.enabled) or l.deb 50
                l.verbose "\nDependencies: make sure the following `local` depsVars bindinds:\n",
                  combinedTemplate.localDepsVars,
                          """\n
                  are available when combined script '#{@template.combinedFile}' is running on:
                    a) nodejs: they should exist as a local `nodes_modules`.
                    b) Web/AMD: they should be declared as `rjs.paths` (and/or `rjs.shim`)
                    c) Web/Script: the binded variables (eg '_' or '$') must be
                       globally loaded (i.e `window.$`) BEFORE loading '#{@template.combinedFile}'\n
                  """
            resolve()
          else
            reject new UError """
              Combined file '#{@template.combinedFile}' NOT written - this should NOT have happened,
              as requirejs reported success. Check requirejs's build response:""", nested: buildResponse

        (error)=>
          reject new UError """
            @requirejs.optimize error: Combined file '#{@template.combinedFile}' NOT written. Some remedy:
               a) Perhaps you have a missing dependeency ?
               b) Is your *bundle.main = '#{@bundle.main}'* properly defined ?
                  - 'main' is the name of your 'entry' module, that usually kicks off all other modules
                  - if not defined, it defaults to `bundle.name`, or 'index' or 'main' if any of those exist as files.
               c) Check the reported error
            """, nested: error

  report: -> # some build reporting
    l.verbose "Report for `#{@bundle.name || 'empty bundle.name'}` target `#{@target}` build ##{@count}:"
    if (@bundle.hasFullBuild is @count) or @verbose
      interestingDepTypes = null #all
    else
      interestingDepTypes = ['notFoundInBundle', 'untrusted'] if not @verbose

    if @template.name is 'nodejs'
        interestingDepTypes = ['notFoundInBundle']

    if not _.isEmpty report = @bundle.reporter.getReport(interestingDepTypes)
      l.warn "\n \nDependency types report for `#{@bundle.name or 'empty bundle.name'}` target `#{@target}` build ##{@count}:\n", report

    l.verbose "Changed: #{_.size @changedResources} file resources of which #{_.size @changedModules} were modules."
    l.verbose "Copied #{@_copied[0]} files, Skipped copying #{@_copied[1]} files." if @_copied?[0] or @_copied?[1]

    if @hasErrors
      if diffSize = _.size(@bundle.errorFiles) isnt _.size(@changedErrorFiles)
        l.er "#{_.size @changedErrorFiles} files with errors in this build."
      if _.size(@bundle.errorFiles)
        l.er "#{_.size @bundle.errorFiles} files with errors in bundle#{if diffSize then '' else '/build'}.\n", @bundle.errorFiles
      l.er "Build ##{@count} finished with #{_.size @errors} errors in #{(new Date() - @startDate) / 1000 }secs."
    else
      l.verbose "Build ##{@count} finished succesfully in #{(new Date() - @startDate) / 1000 }secs."

  printError: (error, nesting=0) ->
    if not error
      l.er "printError: NO ERROR (#{error})"
    else
      nested = error.nested
      delete error.nested
      if not error.printed
        l.er "#{if nesting then 'nested' else ''} ##{nesting}:", (error?.constructor?.name or "No error.constructor.name"),
          "\n #{_.repeat('    ', nesting)}",
          (if _.isFunction error.toString
             error.toString()
           else error)

        error.printed = true

        l.deb 100, '\n error.stack = \n', error.stack # dev only
        if nested
          @printError nested, nesting + 1

  handleError: (error) ->
    @printError error
    error or= new UError "Undefined or null error!"
    @errors.push error if error not in @errors

    if (@continue or @watch.enabled)
      l.warn "Continuing despite of error due to `build.continue` || `build.watch`"
    else
      throw error #'gracefully' quit: caught by bundleBuilder.buildBundle

_.extend module.exports.prototype, {l, _, _B}
