fs = require 'fs'
upath = require 'upath'
When = require 'when'

{VERSION} = urequire = require '../urequire'

module.exports = class BundleBuilder

  constructor: (configs, deriveLoader)->
    @configs = configs = _B.arrayize configs

    # provide to outsiders
    @l = l
    @urequire = urequire

    # lazy, to solve circular dep problems
    @Build = require './Build'
    @Bundle = require './Bundle'
    @blendConfigs = require '../config/blendConfigs'

    # oops, debugLevel not really established before configs are blended :-(
    # l.deb 5, 'uRequire v' + VERSION + ' loading config files...'
    # l.deb('User configs (not blended with Master config)', blendConfigs _.flatten(configs), deriveLoader) if l.deb 90

    @config = @blendConfigs _.flatten(configs), deriveLoader, true    # our 'final' @config withMaster
    _.defaults @config.bundle, {filez: ['**/*']}  # the only(!) hard coded default

    @setDebugVerbose()
    l.debug "Final config (with master defaults):\n", @config if l.deb 10

    # check & fix paths/template or quit if we have anomalies
    @checkAndFixPaths()
    @checkTemplate()

    try
      @bundle = new @Bundle @config.bundle
      @build = new @Build @config.build, @bundle
    catch err
      l.er uerr = "Generic error while initializing @bundle or @build \n", err
      throw new UError uerr, nested:err

  inspect: -> "BundleBuilder:\n" + l.prettify(@bundle) + '\n' + l.prettify(@build)

  # experimental, not really refreshing the whole @bundle & @build
#  addConfigs: (configs, deriveLoader)->
#    configs = _B.arrayize configs
#    configs.unshift @config
#    @blendConfigs configs, deriveLoader
#    configs[1..].unshift {@bundle, @build}
#    @blendConfigs configs, deriveLoader

  verboseRef = _B.Logger::verbose # hack & travestry
  setDebugVerbose: ->
    _B.Logger.addDebugPathLevel 'uRequire', @config.build.debugLevel
    if @config.build.verbose
      _B.Logger::verbose = verboseRef
    else
      if @config.build.debugLevel >= 50
        _B.Logger::verbose = verboseRef
        l.warn 'Enabling verbose, because debugLevel >= 50' if @build?.count is undefined
      else
        _B.Logger::verbose = -> #todo: travesty! 'verbose' should be like _B.Logger's debugLevel ?

  buildBundle: When.lift (filenames)->
    if @build and @bundle

      if urequire.targets # throw if old grunt-urequire
        return When.reject new Error "urequire >= v0.7.0 requires grunt-urequire >= 0.7.0"

      @setDebugVerbose()
      urequire.addBBExecuted @

      bcr = @bundle.buildChangedResources(@build, filenames)
        .catch (err)=>
            @build.handleError err #log and add to `build.errors`
        .finally =>
          @runAfterBuildTasks() # never throws, each one handled while loopo

      bcr.then =>
        if not @build.hasErrors
          @
        else
          When.reject @build.errors # reject with the whole array, is this good practice ?
    else
      l.er err = "buildBundle(): I have !@build or !@bundle - can't build anything!"
      throw new UError err # no `runAfterBuildTasks` in this case

  runAfterBuildTasks: ->
    When.each _B.arrayize(@build.afterBuild), (task, idx)=>

      l.deb 30, "Running `build.afterBuild()` task ##{idx}" +
        if l.deb(70) then task.toString()[0..100] + '...more...' else ''

      errors = if _.isEmpty(@build.errors) then null else @build.errors
      When().then( => #idiomatic handling of simple exceptions
        # depending on args, call with callback / promise/ simple call
        if task.length is 3 # nodejs style callback is 3rd arg, but also retrieves promise (When.race)
          callbackPromise = (deferred = When.defer()).promise
          fnPromise = task errors, @, When.node.createCallback deferred.resolver # also deals with promises, which ever resolves 1st!
          When.race(_.filter [callbackPromise, fnPromise], (it)-> When.isPromiseLike it)
        else
          if task.length is 2 # sync OR promise
            task errors, @
          else
            if task.length is 1 # deprecated `done(true/false)` for urequire < 0.7.0-beta4
              task(if errors is null then true else errors)
            else # be strict about it!
              throw new UError "Unknown number of arguments for `afterBuild()`: \n #{task.toString()[0..100]}"
      ).catch (er)=>
        @build.printError er # dont use handleError cause it might throw, but all ab's need to run
        @build.errors.push er

  watch: (options=@build.watch)=>
    options = @build.watch if _.isNumber options #remedy for older urequire-cli
    options.debounceDelay = 1000 if not _.isNumber options.debounceDelay
    l.ok "Watching started... (with `_.debounce delay` #{options.debounceDelay}ms)"

    bundleBuilder = @

    @build.afterBuild.push (errors, res)=>
      msg = "Watched build ##{@build.count} took #{(new Date() - @build.startDate) / 1000}secs - "
      if not err
        l.ok msg +  "Watching again..."
      else
        l.err msg + "it has #{_.size(errors)} - Watching again..."

    watchFiles = []
    gaze = require 'gaze'
    path = require 'path'
    fs = require 'fs'

    gaze bundleBuilder.bundle.path + '/**/*', (err, watcher)->
      watcher.on 'all', (event, filepath)->
        if event isnt 'deleted'
          try
            filepathStat = fs.statSync filepath # i.e '/mnt/dir/mybundle/myfile.js'
          catch err

        filepath = path.relative process.cwd(), filepath # i.e 'mybundle/myfile.js'

        if filepathStat?.isDirectory()
          l.warn "Adding '#{filepath}' as new watch directory is NOT SUPPORTED by gaze."
        else
          l.verbose "Watched file '#{filepath}' has '#{event}'. \u001b[33m (waiting watch events for #{options.debounceDelay}ms)"
          watchFiles.push path.relative bundleBuilder.bundle.path, filepath

          runBuildBundleDebounced()

    runBuildBundleDebounced = _.debounce( #todo: use gaze's debounceDelay instead of lodash
      ->
        if not _.isEmpty watchFiles = _.unique watchFiles
          l.ok "Starting build ##{bundleBuilder.build.count + 1} for #{l.prettify watchFiles}"
          bundleBuilder.buildBundle(watchFiles).finally -> watchFiles = []
        else
          l.warn 'Ignoring EMPTY watchFiles = ', watchFiles

      options.debounceDelay
    )

  # check if template is Ok - @todo: (2,3,3) embed checks in blenders ?
  checkTemplate: ->
    if @config.build.template.name not in @Build.templates
      throw new UError """
        Quitting build, invalid template '#{@config.build.template.name}' specified.
        Use -h for help"""

  checkAndFixPaths: ->
    if not @config.bundle?.path?
      if cfgFile = @configs[0]?.derive?[0] # assume path, from the 1st configFile that came along
        if dirName = upath.dirname cfgFile
          l.warn "Assuming path = '#{dirName}' from 1st configFile: '#{cfgFile}'"
          @config.bundle.path = dirName
        else
          throw new UError "Quitting build, cant assume `bundle.path` from 1st configFile: '#{cfgFile}'"
      else
        throw new UError "Quitting build, no `path` / `bundle.path` specified. Use -h for help."

    if not fs.existsSync @config.bundle.path
      throw new UError "Quitting build, `bundle.path` '#{@config.bundle.path}' not fs.exists. \nprocess.cwd()= #{process.cwd()}"
    else
      if @config.build.forceOverwriteSources
        @config.build.dstPath = @config.bundle.path
        l.verbose "forceOverwriteSources: `build.dstPath` set to `bundle.path` '#{@config.build.dstPath}'"
      else
        if not (@config.build.dstPath or ((@config.build.template.name is 'combined') and @config.build.template.combinedFile))
          throw new UError """
            Quitting build cause:
              * no `--dstPath` / `build.dstPath` specified.
              #{if @config.build.template.name is 'combined' then "* no `build.template.combinedFile` specified" else ''}
            Use -f *with caution* to overwrite sources (no need to specify & ignored --dstPath)."""

        if @config.build.dstPath and upath.normalize(@config.build.dstPath) is upath.normalize(@config.bundle.path)
          throw new UError """
            Quitting build, dstPath === path.
            Use -f *with caution* to overwrite sources (no need to specify & ignored `--dstPath` / `build.dstPath`).
            """