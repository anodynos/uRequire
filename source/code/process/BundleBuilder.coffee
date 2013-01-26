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

    # Create our 2 main config objects : 'bundle' & 'build'
    @bundleCfg = {}
    @buildCfg = {}

    @buildCfg.done = configs[0]?.done or -> # @todo: remove / test user configable

    ###
    Default-copy all configuration from all configs... that are passed.
    ###

    # @todo:(7 5 4) we need to trully 'recursivelly' process !
    for config in configs when config
      @storeCfgDefaults config

      # in each config, we might have nested configFiles
      # todo: read configFiles with the proper recursion above
      for cfgFilename in _B.arrayize config.configFiles when cfgFilename # no nulls/empty strings
        # assume bundlePath, if its empty, from the 1st configFile that comes along
        @bundleCfg.bundlePath or= upath.dirname cfgFilename
        # get deep defaults to current configuration
        @storeCfgDefaults require _fs.realpathSync cfgFilename
        # ? add configFile to exclude'd files ?
        #  (bundle.exclude ?= []).push upath.relative(options.bundlePath, configFile)

    ###
    We should now have our 'final' configs, @bundleCfg & @buildCfg

    Lets check they are ok & fix formats!

    @todo:(7 4 5) make part of the recursive fixation above
    @todo:(3 2 9) Make generic, for all kinds of schematization, transforamtion & validation of config data.
    ###

    # verbose / debug anyone ?
    if @buildCfg.debugLevel? then Logger::debugLevel = @buildCfg.debugLevel
    if not @buildCfg.verbose
      if Logger::debugLevel >= 50
        l.warn 'Enabling verbose, because debugLevel >= 50'
      else
        Logger::verbose = ->


    ###
    Lets check & fix different formats or quit if we have anomalies
    ###

    # Convert from
    #
    #     bundleExports: ['lodash', 'jquery']
    #
    # to the valid-internally
    #
    #     bundleExports: {
    #       'lodash':[],
    #       'jquery':[]
    #     }
    if be = @bundleCfg.dependencies?.bundleExports
      @bundleCfg.dependencies.bundleExports = _Bs.toObjectKeysWithArrayValues be # see toObjectKeysWithArrayValues
      if not _.isEmpty @bundleCfg.dependencies.bundleExports
        l.debug 20, "@bundleCfg.dependencies.bundleExports' = \n", l.prettify @bundleCfg.dependencies?.bundleExports

    # @todo:2 where to stick these ?
    _B.mutate varNames, _B.arrayize for varNames in [
      @bundleCfg?.dependencies?.variableNames or {}
      uRequireConfigMasterDefaults.bundle.dependencies._knownVariableNames
    ]

    l.debug 30, "user @bundleCfg :\n", l.prettify @bundleCfg
    l.debug 30, "user @buildCfg :\n", l.prettify @buildCfg

    if @isCheckAndFixPaths() and @isCheckAndFixTemplate() # Prepare for buildBundle() !
      @storeCfgDefaults uRequireConfigMasterDefaults
      # display full cfgs, after applied master defaults.
      l.debug 80, "final @bundleCfg :\n", l.prettify @bundleCfg
      l.debug 80, "final @buildCfg :\n", l.prettify @buildCfg

      @bundle = new Bundle @bundleCfg
      @build = new Build @buildCfg

    else # something went wrong with paths, template etc #@todo:2,4 add more fixes/checks ?
      @buildCfg.done false

  buildBundle: ->
    if not (!@build or !@bundle)
      @bundle.buildChangedModules @build
    else
      l.err "buildBundle(): I have !@build or !@bundle - can't build!"
      @buildCfg.done false

  ###
    Store cfg (without overwritting) in our @bundleCfg
    @todo: 1,1 store _.keys uRequireConfigMasterDefaults.bundle & build
  ###
  storeCfgDefaults: (cfg)->
    # read bundle keys from both a) simple/flat cfg and b) cfg.bundle
    @bundleCfg = _B.deepCloneDefaults @bundleCfg, _B.go cfg, fltr: _.keys uRequireConfigMasterDefaults.bundle
    @bundleCfg = _B.deepCloneDefaults @bundleCfg, cfg.bundle or {}

    # read build keys from both a) simple/flat cfg and b) cfg.build
    @buildCfg = _B.deepCloneDefaults @buildCfg, _B.go cfg, fltr: _.keys uRequireConfigMasterDefaults.build
    @buildCfg = _B.deepCloneDefaults @buildCfg, cfg.build or {}

  # @todo:6,6 watch build's folder & rebuild
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
      l.debug 1, "Before '#{match}' with config = ", l.prettify config