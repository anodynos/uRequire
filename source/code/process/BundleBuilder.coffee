_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/process/BundleBuilder'

fs = require 'fs'

When = require 'when'

# urequire
upath = require '../paths/upath'

UError = require '../utils/UError'


{VERSION} = require('../urequire')
###
  Load config :
    * check options
    * Load (a) bundle(s) and (a) build(s)
    * Build & watch for changes
###
class BundleBuilder
  constructor: (@configs, deriveLoader)->
    #l.verbose 'uRequire v' + VERSION + ' BundleBuilder constructed.'

    @Build = require './Build' # lazy, to solve circular dep problem
    @Bundle = require './Bundle'
    blendConfigs = require '../config/blendConfigs'

    l.deb 5, 'uRequire v' + VERSION + ' loading config files...'
    if l.deb 90 # @todo: debugLevel not established before configs are blended
      l.deb 'User configs (not blended / not flatten)', blendConfigs _.flatten(configs), deriveLoader

    @config = blendConfigs _.flatten(configs), deriveLoader, true    # our 'final' @config withMaster
    _.defaults @config.bundle, {filez: ['**/*']}  # the only(!) hard coded default

    @setDebugVerbose()
    l.debug "Final config (with master defaults):\n", @config if l.deb 10

    # check & fix different formats or quit if we have anomalies
    if @isCheckAndFixPaths() and @isCheckTemplate()
      try
        @bundle = new @Bundle @config.bundle
        @build = new @Build @config.build
      catch err
        l.er uerr = "Generic error while initializing @bundle or @build", err
        throw new UError uerr, nested:err

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
        _B.Logger::verbose = -> #todo: travesty! 'verbose' should be like debugLevel ?

  buildBundle: When.lift (filenames)->
    if @build and @bundle
      @setDebugVerbose()
      @build.newBuild()
      @bundle.buildChangedResources(@build, filenames).then(
        (res)=>
          if res is false
            l.err "@bundle.buildChangedResources promise returned false" #throw new Error?
          else
            l.debug 40, "@bundle.buildChangedResources result is :", res
          @build.done res
      ).catch (err)=>
          @build.done false
          @bundle.handleError err
          l.er 'Uncaught exception @ bundle.buildChangedResources'
          throw err
    else
      l.er err = "buildBundle(): I have !@build or !@bundle - can't build!"
      @config.build.done false
      throw err

  watch: =>
    bundleBuilder = @
    buildDone = @build.done
    @build.done = (doneValue)->
      buildDone doneValue
      l.ok "Watched build ##{bundleBuilder.build.count} took #{(new Date() - bundleBuilder.build.startDate) / 1000 }secs - Watching again..."
    watchFiles = []
    gaze = require 'gaze'
    path = require 'path'
    fs = require 'fs'

    # @todo build this according to watch.filez || bundle.filez
    gaze bundleBuilder.bundle.path + '/**/*', (err, watcher)->
      watcher.on 'all', (event, filepath)->
        if event isnt 'deleted'
          try
            filepathStat = fs.statSync filepath # i.e '/mnt/dir/mybundle/myfile.js'
          catch err

        filepath = path.relative process.cwd(), filepath # i.e 'mybundle/myfile.js'

        if filepathStat?.isDirectory()
          l.log "Adding '#{filepath}' as new watch directory is NOT SUPPORTED by gaze."
        else
          l.log "Watched file '#{filepath}' has '#{event}'."
          watchFiles.push path.relative bundleBuilder.bundle.path, filepath
          runBuildBundleDebounced()

    runBuildBundle = ->
      if not _.isEmpty watchFiles
        bundleBuilder.buildBundle watchFiles
        watchFiles = []
        runBuildBundleDebounced = _.debounce runBuildBundle, 100
      else
        l.warn 'EMPTY watchFiles = ', watchFiles

    runBuildBundleDebounced = _.debounce runBuildBundle, 100

  # check if template is Ok - @todo: (2,3,3) embed checks in blenders ?
  isCheckTemplate: ->
    if @config.build.template.name not in @Build.templates
      l.er """
        Quitting build, invalid template '#{@config.build.template.name}' specified.
        Use -h for help"""
      return false

    true

  isCheckAndFixPaths: ->
    pathsOk = true

    if not @config.bundle?.path?
      # assume path, from the 1st configFile that came along
      if cfgFile = @configs[0]?.derive?[0]
        if dirName = upath.dirname cfgFile
          l.warn "Assuming path = '#{dirName}' from 1st configFile: '#{cfgFile}'"
          @config.bundle.path = dirName
        else
          l.er "Quitting build, cant assume path from 1st configFile: '#{cfgFile}'"
          pathsOk = false
      else
        l.er "Quitting build, no path specified. Use -h for help."
        pathsOk = false

    if pathsOk
      if not fs.existsSync @config.bundle.path
        l.er "Quitting build, `bundle.path` '#{@config.bundle.path}' not fs.exists. \nprocess.cwd()= #{process.cwd()}"
        pathsOk = false
      else
        if @config.build.forceOverwriteSources
          @config.build.dstPath = @config.bundle.path
          l.verbose "forceOverwriteSources: dstPath set to '#{@config.build.dstPath}'"
        else
          if not (@config.build.dstPath or
            ((@config.build.template.name is 'combined') and @config.build.template.combinedFile)
          )
            l.er """
              Quitting build:
                * no --dstPath / `build.dstPath` specified.
                #{if @config.build.template.name is 'combined' then "* no `build.template.combinedFile` specified" else ''}
              Use -f *with caution* to overwrite sources (no need to specify & ignored --dstPath)."""
            pathsOk = false

          if @config.build.dstPath and upath.normalize(@config.build.dstPath) is upath.normalize(@config.bundle.path)
            l.er """
              Quitting build, dstPath === path.
              Use -f *with caution* to overwrite sources (no need to specify & ignored --dstPath).
              """
            pathsOk = false

    pathsOk

module.exports = BundleBuilder
