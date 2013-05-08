_ = require 'lodash'
_fs = require 'fs'
_B = require 'uberscore'

l = new _B.Logger 'urequire/BundleBuilder'

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

  constructor: (@configs, deriveLoader)->

    userCfg = blendConfigs configs, deriveLoader

    # we now have our 'final' USER config
    @bundleCfg = userCfg.bundle
    @buildCfg = userCfg.build
    @buildCfg.done = configs[0]?.done or -> # @todo: remove / test user configable

    # verbose / debug anyone ?
    if @buildCfg.debugLevel?
      _B.Logger.setDebugLevel @buildCfg.debugLevel, 'urequire'
      l.debug 0, "Setting userCfg _B.Logger.setDebugLevel(#{@buildCfg.debugLevel}, 'urequire')"


    if not @buildCfg.verbose
      if @buildCfg.debugLevel >= 50
        l.warn 'Enabling verbose, because debugLevel >= 50'
      else
        _B.Logger::verbose = ->

    l.debug("user @bundleCfg :\n", @bundleCfg) if l.deb 30
    l.debug("user @buildCfg :\n", @buildCfg) if l.deb 30

    ### Lets check & fix different formats or quit if we have anomalies ###
    # Why these here instead of top ? # Cause We need to have _B.Logging.debugLevel ready BEFORE YADC debug check
    # Why on @ ? Cause we need them outside constructor, below
    @Bundle = require './Bundle'
    @Build = require './Build'

    if @isCheckAndFixPaths() and @isCheckAndFixTemplate()

      finalCfg = blendConfigs [userCfg, uRequireConfigMasterDefaults], deriveLoader

      # Create our 2 main config objects : 'bundleCfg' & 'buildCfg'
      @bundleCfg = finalCfg.bundle
      @buildCfg = finalCfg.build
      @buildCfg.done = configs[0]?.done or -> # @todo: remove / test user configable

      # display full cfgs, after applied master defaults.
      l.debug("final @bundleCfg :\n", @bundleCfg) if l.deb 20
      l.debug("final @buildCfg :\n", @buildCfg) if l.deb 20

      # Create the implementation instance from these configs @todo: refactor / redesign this / better practice ?
      @bundle = new @Bundle @bundleCfg
      @build = new @Build @buildCfg


    else # something went wrong with paths, template etc # @todo:2,4 add more fixes/checks ?
      l.debug(0, "@bundleCfg :\n", @bundleCfg)
      l.debug(0, "@buildCfg :\n", @buildCfg)
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
  # @todo: make this a blender
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
    if not @bundleCfg?.bundlePath?
      # assume bundlePath, from the 1st configFile that came along
      if cfgFile = @configs[0]?.derive?[0]
        if dirName = upath.dirname cfgFile
          l.warn "Assuming bundlePath = '#{dirName}' from 1st configFile: '#{cfgFile}'"
          @bundleCfg.bundlePath = dirName
          return true
        else
          l.err "Assuming bundlePath = '#{upath.dirname cfgFile}' from 1st configFile: '#{cfgFile}'"
          return false
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

if l.deb > 10 or true
  YADC = require('YouAreDaChef').YouAreDaChef

  YADC(BundleBuilder)
    .before /_constructor/, (match, config)->
      l.debug(1, "Before '#{match}' with config = ", config)