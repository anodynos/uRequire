_ = require 'lodash'
_fs = require 'fs'
_B = require 'uberscore'

l = new _B.Logger 'BundleBuilder'

# urequire
upath = require '../paths/upath'
uRequireConfigMasterDefaults = require '../config/uRequireConfigMasterDefaults'

blendConfigs = require '../config/blendConfigs'
_Bs = require '../utils/uBerscoreShortcuts'

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

  _constructor: (@configs...)->

    # blend all configuration from all configs passed (including nested .configFiles)
    finalCfg = blendConfigs configs

    # Create our 2 main config objects : 'bundle' & 'build'
    @bundleCfg = finalCfg.bundle
    @buildCfg = finalCfg.build
    @buildCfg.done = configs[0]?.done or -> # @todo: remove / test user configable

    ###
    We should now have our 'final' configs, @bundleCfg & @buildCfg
    Lets check they are ok & fix formats!
    ###

    # verbose / debug anyone ?
    if @buildCfg.debugLevel?
      _B.Logger.debugLevel = @buildCfg.debugLevel
      l.debug 0, 'Setting _B.Logger.debugLevel =', _B.Logger.debugLevel

    if not @buildCfg.verbose
      if _B.Logger.debugLevel >= 50
        l.warn 'Enabling verbose, because debugLevel >= 50'
      else
        _B.Logger::verbose = ->

    # @todo: why here? Why @ ? We need to have _B.Logging.debugLevel ready for YADC check
    @Bundle = require './Bundle'
    @Build = require './Build'

    ###
    Lets check & fix different formats or quit if we have anomalies
    ###

    l.debug("user @bundleCfg :\n", @bundleCfg) if l.deb 30
    l.debug("user @buildCfg :\n", @buildCfg) if l.deb 30

    if @isCheckAndFixPaths() and @isCheckAndFixTemplate() # Prepare for buildBundle() !
      # display full cfgs, after applied master defaults.
      l.debug("final @bundleCfg :\n", @bundleCfg) if l.deb 20
      l.debug("final @buildCfg :\n", @buildCfg) if l.deb 20

      @bundle = new @Bundle @bundleCfg
      @build = new @Build @buildCfg

    else # something went wrong with paths, template etc # @todo:2,4 add more fixes/checks ?
      @buildCfg.done false

  buildBundle: ->
    if not (!@build or !@bundle)
      @bundle.buildChangedModules @build
    else
      l.err "buildBundle(): I have !@build or !@bundle - can't build!"
      @buildCfg.done false

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

    if @buildCfg.template.name not in @Build.templates
      l.err """
        Quitting build, invalid template '#{@buildCfg.template.name}' specified.
        Use -h for help"""
      return false

    return true

  isCheckAndFixPaths: ->
    if not @bundleCfg.bundlePath
      # assume bundlePath, from the 1st configFile that come along
      if cfgFile = @configs[0]?.configFiles?[0]?
        l.debug("Assuming bundlePath = '#{upath.dirname cfgFile}' from 1st configFile: '#{cfgFile}'") if l.deb(40)
        @bundleCfg.bundlePath = upath.dirname cfgFile
        return true
      else
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

if _B.Logger.debugLevel > 10 or true
  YADC = require('YouAreDaChef').YouAreDaChef

  YADC(BundleBuilder)
    .before /_constructor/, (match, config)->
      l.debug(1, "Before '#{match}' with config = ", config)