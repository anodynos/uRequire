_ = require 'lodash'
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

###
  Load Config:
    * check options
    * Load (a) bundle(s) and (a) build(s)
    * Build & watch for changes
###

class BundleBuilder
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor: -> @_constructor.apply @, arguments

  _constructor: (config)->
    bundleCfg = {}
    buildCfg = {}

    require('better-require')()

    if config.configFile
      config.configFile = _B.arraize config.configFile
      # assume bundlePath, if its empty
      config.bundlePath or= upath.dirname config.configFile
      # ? add configFile to exclude'd files ?
      #  (bundle.exclude ?= []).push upath.relative(options.bundlePath, configFile)


      cfgFile = require config.configFile #_fs.realpathSync configFile
      delete config.configFile
      config = _B.deepCloneDefaults config, cfgFile

    # read both simple/flat cfg and cfg.bundle
    _.extend bundleCfg, config.bundle
    _.extend bundleCfg, _B.go config, fltr: _.keys uRequireConfigMasterDefaults.bundle

    _.extend buildCfg, config.build
    _.extend buildCfg, _B.go config, fltr: _.keys uRequireConfigMasterDefaults.build

    if not buildCfg.verbose then Logger::verbose = ->
    if buildCfg.debugLevel? then Logger::debugLevel = buildCfg.debugLevel

    if be = bundleCfg.dependencies?.bundleExports
      bundleCfg.dependencies.bundleExports = _Bs.toObjectKeysWithArrayValues be # see toObjectKeysWithArrayValues
      l.debug 50, "bundleCfg.dependencies.bundleExports' = \n", JSON.stringify bundleCfg.dependencies?.bundleExports, null, ' '

    # check & build config / options
    if @isPathsOK(bundleCfg, buildCfg) and
       @isTemplateOk(buildCfg)
          l.verbose "bundleCfg :\n", JSON.stringify bundleCfg, null, ' '
          l.verbose "buildCfg :\n", JSON.stringify buildCfg, null, ' '

#          @bundle = new Bundle bundleCfg
#          @build = new Build buildCfg
#
#          # Build bundle against the build setup (@todo: or builds ?)
#          l.debug 50, 'buildChangedModules() with build = \n', @build
#          @bundle.buildChangedModules @build

          # @todo: & watch build's folder
          # @watchDirectory @cfg.bundle.bundlePath
          #  register something to watch events
          #  watchDirectory:->
          #    onFilesChange: (filesChanged)->
          #      bundle.loadModules filesChanged #:[]<String>

  # fix & check if template is Ok.
  isTemplateOk: (buildCfg)->

    if not buildCfg.template
      buildCfg.template = {name: 'UMD'} # default

    if _.isString buildCfg.template
      buildCfg.template = {name: buildCfg.template} # default

    if not buildCfg.template.name? in Build.templates
      l.err """
        Quitting build, no valid template specified.
        Use -h for help"""
      return false

    return true

  isPathsOK: (bundleCfg, buildCfg)->
    if not bundleCfg.bundlePath
      l.err """
        Quitting build, no bundlePath specified.
        Use -h for help"""
      return false
    else
      if buildCfg.forceOverwriteSources
        buildCfg.outputPath = bundleCfg.bundlePath
        l.verbose "Forced output to '#{buildCfg.outputPath}'"
        return true
      else
        if not buildCfg.outputPath
          l.err """
            Quitting build, no --outputPath specified.
            Use -f *with caution* to overwrite sources."""
          return false
        else
          if buildCfg.outputPath is bundleCfg.bundlePath #@todo: check normalized
            l.err """
              Quitting build, outputPath === bundlePath.
              Use -f *with caution* to overwrite sources (no need to specify --outputPath).
              """
            return false

    return true

module.exports = BundleBuilder

### Debug information ###

if l.debugLevel > 10 #or true
  YADC = require('YouAreDaChef').YouAreDaChef

  YADC(BundleBuilder)
    .before /_constructor/, (match, config)->
      l.debug 1, "Before '#{match}' with config = ", JSON.stringify(config, null, ' ')


# Tests
#b = new BundleBuilder {
# "bundle": {
#  "bundlePath": "blabla"
# },
# "build": {
#  "template": "AMD"
# },
# "forceOverwriteSources": true
#}


