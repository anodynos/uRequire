_ = require 'lodash'
_fs = require 'fs'
_B = require 'uberscore'
require('butter-require')() # no need to store it somewhere
l = new _B.Logger 'urequire/blendConfigs'

uRequireConfigMasterDefaults = require './uRequireConfigMasterDefaults'

### Define the various Blenders used ###

# Copy all keys from the 'root' of src, to either `dst.bundle` or `dst.build` (the legitimate parts of a config),
# depending on where these keys appear in uRequireConfigMasterDefaults.
#
# NOTE: it simply ignores unknown keys (i.e keys not in uRequireConfigMasterDefaults .build or .bundle)
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
  derive: '|': -> _B.Blender.NEXT

], {isExactPath: true, debugLevel: 0})

# bundleBlender
#
# The top level Blender, it uses 'path' to make decisions on how to blend `bundle`.
#
# It extends DeepDefaultsBlender, so if there's no path match,
# it works like _.defaults (but deeply).
bundleBlender = new _B.DeepDefaultsBlender([
  order: ['path', 'src']
  bundle:
    dependencies:

      bundleExports:
        '|': '*': (prop, src, dst)-> dependenciesBindingsBlender.blend dst[prop], src[prop]

      variableNames:
        '|': '*': (prop, src, dst)-> dependenciesBindingsBlender.blend dst[prop], src[prop]

], {isExactPath: true, debugLevel: 0})


###
*dependenciesBindingsBlender*

Converts String, Array<String> or Object {variable:bindingsArrayOfStringsOrString
to the 'proper' dependenciesBinding structure ({dependency1:ArrayOfDep1Bindings, dependency2:ArrayOfDep2Bindings, ...}

So with    *source*                 is converted to proper      *destination*
* String : `'lodash'`                       --->                `{lodash:[]}`

* Array<String>: `['lodash', 'jquery']`     --->            `{lodash:[], jquery:[]}`

* Object: `{lodash:['_'], jquery: '$'}`     --->          as is @todo: convert '$' to proper ['$'], i.e `{lodash:['_'], jquery: ['$']}`

The resulting array of bindings for each 'variable' is blended via arrayPusher
to the existing? corresponding array on the destination
###
dependenciesBindingsBlender = new _B.DeepCloneBlender([
  order: ['src']

  # our src[prop] (i.e. variableBindings eg bundleExports) is a String eg 'lodash'. Return an {'lodash':[]}
  'String': (prop, src, dst)-> arrayPusher.blend dst[prop], _B.okv({}, src[prop], [])

  #  our src[prop] (i.e. variableBindings eg bundleExports) is an Array, eg `['lodash', 'jquery']`
  'Array': (prop, src, dst)->
    varBindings = {}
    _B.go src[prop], grab: (v,k)-> varBindings[v] or= [] #    convert to    `{lodash:[], jquery:[]}`
    arrayPusher.blend dst[prop], varBindings

  # our src[prop] (i.e. variableBindings eg bundleExports) is a Object eg {'lodash': ???, ...}
  'Object': (prop, src, dst)-> arrayPusher.blend dst[prop], src[prop]

], {isExactPath: true})

# Push all items of `src[prop]` array to the `dst[prop]` array (when these are not in dst[prop] already).
# If either src[prop] or dst[prop] aren't arrays, they are `arrayize`'d first.
arrayPusher = new _B.DeepDefaultsBlender([
    order: ['src']
    unique: true

    #todo: make this default (but define a custome uRequire_ArrayPusher that deals only with `String` & `Array<String>`, throwing error otherwise.
    # '*': 'pushToArray'
    # 'Undefined': ->_B.Blender.SKIP
    # 'Null': ->_B.Blender.SKIP

    'Array': 'pushToArray'
    'String': 'pushToArray'
    'Number': 'pushToArray'

    pushToArray: (prop, src, dst, bl)->
      dst[prop] = _B.arrayize dst[prop]
      srcArray = _B.arrayize src[prop]

      if _.isEqual srcArray[0], [null] # `[null]` is a signpost for 'reset array'.
        dst[prop] = []
        srcArray = srcArray[1..] # The remaining items of the array are the 'real' items to push.

      itemsToPush =
        if bl.currentBlenderBehavior.unique             # @todo: does unique belong to blenderBehavior ?
          (v for v in srcArray when v not in dst[prop]) # @todo: unique can be a fn: isEqual/isIqual/etc or any other equal fn.
        else
          srcArray                                      # add 'em all

      dst[prop].push v for v in itemsToPush
      dst[prop]
      #_B.Blender.SKIP # no need to assign, we mutated dst[prop] #todo: needed or not ?
])

#todo: get rid of this one - keep only the recursive
blendConfigs = (configsArray, deriveLoader)->

  deriveLoader =
    if _.isFunction deriveLoader
      deriveLoader
    else
      (derive)-> #default derive loader
        if _.isString derive
          l.verbose "Loading config file: '#{derive}'"
          if cfgObject = require _fs.realpathSync derive # @todo: test require using butter-require within uRequire :-)
            return cfgObject
        else
          if _.isObject derive
            return derive

        # if its hasnt returned, we're in error
        l.err """
          Error loading configuration files:
            derive """, derive, """ is a not a valid filename
            while processing derive array ['#{config.derive.join "', '"}']"
          """
        config.done false

  finalCfg = bundle: {}, build: {} #just be sure these exist
  _blendDerivedConfigs finalCfg, configsArray, deriveLoader
  finalCfg

# the recursive fn that also considers cfg.derive
_blendDerivedConfigs = (cfgFinal, cfgsArray, deriveLoader)->
  for cfg in cfgsArray when cfg
    # blend cfg into cfgFinal using the top level blender

    bundleBlender.blend cfgFinal, moveKeysBlender.blend cfg # first moveKeys for each config for configsArray items
                                                            # @todo: (2, 7, 5) rewrite more functional, decoration/declarative/flow style ?
    # in each cfg, we might have nested `derive`s - recurse for each of those
    derivedObjects = (
      for drv in _B.arrayize cfg.derive when drv # no nulls/empty strings
        deriveLoader drv
      )

    if !_.isEmpty derivedObjects
      _blendDerivedConfigs cfgFinal, derivedObjects, deriveLoader

module.exports = blendConfigs

# expose blender instances to module.exports/blendConfigs, just for testing
_.extend blendConfigs, {moveKeysBlender, arrayPusher, dependenciesBindingsBlender, bundleBlender}