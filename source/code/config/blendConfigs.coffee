_ = require 'lodash'
_fs = require 'fs'
_B = require 'uberscore'
require('butter-require')() # no need to store it somewhere

uRequireConfigMasterDefaults = require './uRequireConfigMasterDefaults'

module.exports =
blendConfigs = (configs)->
  finalCfg = {}
  _blendConfigsInto finalCfg, configs

  #lastly, blend with uRequireConfigMasterDefaults
  bundleBlender.blend finalCfg, uRequireConfigMasterDefaults
  return finalCfg

# the recursive fn that also considers cfg.configFiles
_blendConfigsInto = (cfgFinal, cfgsArray)->
  for cfg in cfgsArray when cfg
    cfg = moveKeysBlender.blend cfg # move keys to their proper position (inside bundle or build)
    bundleBlender.blend cfgFinal, cfg

    # in each cfg, we might have nested configFiles - recurse for each of those

    cfgOfConfigFiles = (
      for cfgFilename in _B.arrayize cfg.configFiles when cfgFilename # no nulls/empty strings
        require _fs.realpathSync cfgFilename #require using butter-require
      )
    _blendConfigsInto cfgFinal, cfgOfConfigFiles

### Define the various Blenders used ###

# bundleBlender
#
# The top level Blender, it uses 'path' to make decisions on how to blend.
# It extends DeepDefaultsBlender, so if there's no path match,
# it works like _.defaults (but deeply).
bundleBlender = new _B.DeepDefaultsBlender([
  order: ['path', 'src']
  bundle:
    dependencies:

      bundleExports:
        '|': '*': (prop, src, dst)-> variableBindingsBlender.blend dst[prop], src[prop]

      variableNames:
        '|': '*': (prop, src, dst)-> variableBindingsBlender.blend dst[prop], src[prop]

], {isExactPath: true, debugLevel: 0})

# variableBindingsBlender
#
# Converts String, Array<String> or Object {variable:bindingsArrayOfStringsOrString
# to a proper variableBinding structure:
#
# * String 'lodash' ---> {lodash:[]}
# * Array<String> ['lodash', 'jquery'] ---> {lodash:[], jquery:[]}
# * Object {lodash:['_'], jquery: '$'} ---> as is
#
# The resulting array of bindings for each 'variable' is blended via arrayPusher to the existing?
# corresponding array on the destination
variableBindingsBlender = new _B.DeepDefaultsBlender([
  order: ['src']

  # our src[prop] (i.e. variableBindings eg bundleExports) is a String eg 'lodash'. Return an {'lodash':[]}
  'String': (prop, src, dst)-> arrayPusher.blend _B.okv({}, src[prop], [])

  #  our src[prop] (i.e. variableBindings eg bundleExports) is an Array, eg ['lodash', 'jquery']
  'Array': (prop, src, dst)->
    varBindings = {}
    _B.go src[prop], grab: (v,k)-> varBindings[v] or= [] #convert to {lodash:[], jquery:[]}
    arrayPusher.blend dst[prop], varBindings

  # our src[prop] (i.e. variableBindings eg bundleExports) is a Object eg {'lodash': ???, ...}
  'Object': (prop, src, dst)-> arrayPusher.blend dst[prop], src[prop]

], {isExactPath: true})

# Push all items of `src[prop]` array to the `dst[prop]` array (when these are not in dst[prop] already).
# If either src[prop] or dst[prop] aren't arrays, they are `arrayize`'d first.
arrayPusher = new _B.DeepDefaultsBlender([
    order: ['src']
    unique: true

    'Array': 'pushToArray'
    'String': 'pushToArray'

    pushToArray: (prop, src, dst, bl)->
      dst[prop] = _B.arrayize dst[prop]
      srcArray = _B.arrayize src[prop]

      if _.isEqual srcArray[0], [null]
        dst[prop] = []
        srcArray = srcArray[1..]

      itemsToPush =
        if bl.currentBlenderBehavior.unique
          (v for v in srcArray when v not in dst[prop]) # @todo: unique can be a fn: isEqual/isIqual/etc or any other equal fn.
        else
          srcArray

      dst[prop].push v for v in itemsToPush
      dst[prop] #_B.Blender.SKIP # no need to assign
])

# Copy all keys from the 'root' of src, to either `dst.bundle` or `dst.build` (the legitimate parts of a config),
# depending on where these keys appear in uRequireConfigMasterDefaults.
moveKeysBlender = new _B.DeepDefaultsBlender([
  order: ['path']
  '*': '|': do (partsKeys = {
                  bundle: _.keys uRequireConfigMasterDefaults.bundle # eg ['bundlePath', 'dependencies', ...]
                  build: _.keys uRequireConfigMasterDefaults.build   # eg ['outputPath', 'template', ...]
                })->
                  (prop, src, dst, bl)->
                    for confPart in ['bundle', 'build'] # or better _.keys partsKeys
                      if prop in partsKeys[confPart]
                        _B.setValueAtPath bl.dstRoot, "/#{confPart}/#{prop}", src[prop], true
                        break

                    _B.Blender.SKIP # no assign

  # just deepDefault our 'legitimate' parts
  bundle: '|': -> _B.Blender.NEXT
  build: '|': -> _B.Blender.NEXT
  configFiles: '|': -> _B.Blender.NEXT

], {isExactPath: true, debugLevel: 0})
