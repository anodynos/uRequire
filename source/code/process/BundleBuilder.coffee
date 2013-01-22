_ = require 'lodash'
_fs = require 'fs'
_B = require 'uberscore'
upath = require '../paths/upath'
# logging
Logger = require '../utils/Logger'
l = new Logger 'BundleBuilder'

# urequire
uRequireConfigMasterDefaults = require '../config/uRequireConfigMasterDefaults'
Bundle = require './Bundle'
Build = require './Build'

_Bs = require '../utils/uBerscoreShortcuts'

require('butter-require')() # no need to store it somewhere

###
  Load config :
    * check options
    * Load (a) bundle(s) and (a) build(s)
    * Build & watch for changes
###
class BundleBuilder
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor: -> @_constructor.apply @, arguments

  _constructor: (configs...)->
    @bundleCfg = {}
    @buildCfg = {}

    for config in configs when config
      @storeCfgDefaults config

      for cfgFilename in _B.arrayize config.configFiles when cfgFilename # no nulls/empty strings
        # assume bundlePath, if its empty, from the 1st configFile that comes along
        @bundleCfg.bundlePath or= upath.dirname cfgFilename
        # get deep defaults to current configuration
        @storeCfgDefaults require _fs.realpathSync cfgFilename
        # ? add configFile to exclude'd files ?
        #  (bundle.exclude ?= []).push upath.relative(options.bundlePath, configFile)

    ###
    # We now have our 'final' configs, @bundleCfg & @buildCfg
    ###

    # verbose / debug anyone ?
    if @buildCfg.debugLevel? then Logger::debugLevel = @buildCfg.debugLevel
    if not @buildCfg.verbose then Logger::verbose = ->

    # Lets check & fix different formats or quit if we have anomalies

    if be = @bundleCfg.dependencies?.bundleExports
      @bundleCfg.dependencies.bundleExports = _Bs.toObjectKeysWithArrayValues be # see toObjectKeysWithArrayValues
      l.debug 20, "@bundleCfg.dependencies.bundleExports' = \n", JSON.stringify @bundleCfg.dependencies?.bundleExports, null, ' '

    if @isCheckAndFixPaths() and @isCheckAndFixTemplate()
      l.debug 30, "@bundleCfg :\n", JSON.stringify @bundleCfg, null, ' '
      l.debug 30, "@buildCfg :\n", JSON.stringify @buildCfg, null, ' '

      @storeCfgDefaults uRequireConfigMasterDefaults
      # display full cfgs, after applied master defaults.
      l.debug 99, "@buildCfg :\n", JSON.stringify @buildCfg, null, ' '
      l.debug 99, "@buildCfg :\n", JSON.stringify @buildCfg, null, ' '

       # Prepare for buildBundle() !
      @bundle = new Bundle @bundleCfg
      @build = new Build @buildCfg
    else
      if _.isFunction configs[0].done
        configs[0].done false

  # @param done A callback promise (eg. grunt's @async()) that is called when its finished
  buildBundle: (done)->
    if not (!@build or !@bundle)
      @build.done = done or ->
      @bundle.buildChangedModules @build
    else
      l.err "buildBundle(): I have !@build or !@bundle - can't build!"
      done(false) if _.isFunction done

  storeCfgDefaults: (cfg)->
    # read bundle keys from both a) simple/flat cfg and b) cfg.bundle
    @bundleCfg = _B.deepCloneDefaults @bundleCfg, cfg.bundle or {}
    @bundleCfg = _B.deepCloneDefaults @bundleCfg, _B.go cfg, fltr: _.keys uRequireConfigMasterDefaults.bundle

    # read build keys from both a) simple/flat cfg and b) cfg.build
    @buildCfg = _B.deepCloneDefaults @buildCfg, cfg.build or {}
    @buildCfg = _B.deepCloneDefaults @buildCfg, _B.go cfg, fltr: _.keys uRequireConfigMasterDefaults.build


  # @todo:6 watch build's folder & rebuild
  # @watchDirectory @cfg.bundle.bundlePath
  #  register something to watch events
  #  watchDirectory:->
  #    onFilesChange: (filesChanged)->
  #      bundle.loadModules filesChanged #:[]<String>

  # fix & check if template is Ok.
  isCheckAndFixTemplate: ->

    if not @buildCfg.template
      @buildCfg.template = {name: 'UMD'} # default

    if _.isString @buildCfg.template
      @buildCfg.template = {name: @buildCfg.template} # default

    if @buildCfg.template.name not in Build.templates
      l.err """
        Quitting build, invalid template '#{@buildCfg.template.name}' specified.
        Use -h for help"""
      return false

    return true

  isCheckAndFixPaths: ->

    if not @bundleCfg.bundlePath
      l.err """
        Quitting build, no bundlePath specified.
        Use -h for help"""
      return false
    else
      if @buildCfg.forceOverwriteSources
        @buildCfg.outputPath = @bundleCfg.bundlePath
        l.verbose "Forced output to '#{@buildCfg.outputPath}'"
        return true
      else
        if not @buildCfg.outputPath
          l.err """
            Quitting build, no --outputPath specified.
            Use -f *with caution* to overwrite sources."""
          return false
        else
          if @buildCfg.outputPath is @bundleCfg.bundlePath # @todo: check normalized ?
            l.err """
              Quitting build, outputPath === bundlePath.
              Use -f *with caution* to overwrite sources (no need to specify --outputPath).
              """
            return false

    return true

module.exports = BundleBuilder

### Debug information ###

if Logger::debugLevel > 10 or true
  YADC = require('YouAreDaChef').YouAreDaChef

  YADC(BundleBuilder)
    .before /_constructor/, (match, config)->
      l.debug 1, "Before '#{match}' with config = ", JSON.stringify(config, null, ' ')