_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
require('butter-require')() # no need to store it somewhere
l = new _B.Logger 'urequire/blendConfigs'

uRequireConfigMasterDefaults = require './uRequireConfigMasterDefaults'

### Define the various Blenders used ###

# Copy/clone all keys from the 'root' of src,
# to either `dst.bundle` or `dst.build` (the legitimate parts of the config),
# depending on where these keys appear in uRequireConfigMasterDefaults.
#
# NOTE: it simply ignores unknown keys (i.e keys not in uRequireConfigMasterDefaults .build or .bundle)
#       including 'derive'
functionCopyBB =
  order:['src']
  'Function': (prop, src)-> src[prop] #just copy function ref

moveKeysBlender = new _B.DeepCloneBlender [
  functionCopyBB,
  {
    order: ['path']
    '*': '|':
      do (partsKeys = {
        bundle: _.keys uRequireConfigMasterDefaults.bundle # eg ['path', 'dependencies', ...]
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
  }
#  compilers: '|': -> _B.Blender.NEXT # @todo: how do we blend this ?
]

# bundleBuildBlender
#
# The top level Blender, it uses 'path' to make decisions on how to blend `bundle`.
#
# It extends DeepCloneBlender, so if there's no path match,
# it works like _.clone (deeply).
bundleBuildBlender = new _B.DeepCloneBlender [
  functionCopyBB,
  {
    order: ['path', 'src']

    bundle:
      dependencies:
        noWeb: '|': '*': (prop, src, dst)->
          arrayizeUniquePusher.blend dst[prop], src[prop]

        bundleExports: '|': '*': (prop, src, dst)->
          dependenciesBindingsBlender.blend dst[prop], src[prop]

        variableNames: '|': '*': (prop, src, dst)->
          dependenciesBindingsBlender.blend dst[prop], src[prop]

        _knownVariableNames: '|': '*': (prop, src, dst)->
          dependenciesBindingsBlender.blend dst[prop], src[prop]

      resources: '|' : '*': (prop, src, dst)->
        arrayizeUniquePusher.blend dst[prop], resourcesBlender.blend([], src[prop])

    build:
      template: '|': '*': (prop, src, dst)->
        templateBlender.blend dst[prop], src[prop]
  }
]


###
*dependenciesBindingsBlender*

Converts String, Array<String> or Object {variable:bindingsArrayOfStringsOrString
to the 'proper' dependenciesBinding structure ({dependency1:ArrayOfDep1Bindings, dependency2:ArrayOfDep2Bindings, ...}

So with    *source*                 is converted to proper      *destination*
* String : `'lodash'`                       --->                `{lodash:[]}`

* Array<String>: `['lodash', 'jquery']`     --->            `{lodash:[], jquery:[]}`

* Object: `{lodash:['_'], jquery: '$'}`     --->          as is @todo: convert '$' to proper ['$'], i.e `{lodash:['_'], jquery: ['$']}`

The resulting array of bindings for each 'variable' is blended via arrayizeUniquePusher
to the existing? corresponding array on the destination
###
dependenciesBindingsBlender = new _B.DeepCloneBlender [
  order: ['src']

  # our src[prop] (i.e. variableBindings eg bundleExports) is a String eg 'lodash'. Return an {'lodash':[]}
  'String': (prop, src, dst)->
    arrayizeUniquePusher.blend dst[prop], _B.okv({}, src[prop], [])

  #  our src[prop] (i.e. variableBindings eg bundleExports) is an Array, eg `['lodash', 'jquery']`
  'Array': (prop, src, dst)->
    varBindings = {}
    _B.go src[prop], grab: (v)-> varBindings[v] or= [] #    convert to    `{lodash:[], jquery:[]}`
    arrayizeUniquePusher.blend dst[prop], varBindings

  # our src[prop] (i.e. variableBindings eg bundleExports) is a Object eg {'lodash': ???, ...}
  'Object': (prop, src, dst)->
    arrayizeUniquePusher.blend dst[prop], src[prop]
]

deepCloneBlender = new _B.DeepCloneBlender

templateBlender = new _B.DeepCloneBlender [
  order: ['src']

  # our src[prop] template is a String eg 'UMD'.
  # blend as {name:'UMD'}
  'String': (prop, src, dst)->
    dst[prop] = {} if src[prop] isnt dst[prop]?.name
    deepCloneBlender.blend dst[prop], {name: src[prop]}

  # our src[prop] template is an Object - should be {name: 'UMD', '...': '...'}
  # blend as is but reset dst object if template has changed!
  'Object': 'templateSetter'

  templateSetter: (prop, src, dst)->
    dst[prop] = {} if src[prop].name isnt dst[prop]?.name and
                    not _.isUndefined src[prop].name
    deepCloneBlender.blend dst[prop], src[prop]
]


# Push all items of `src[prop]` array to the `dst[prop]` array (when these are not in dst[prop] already).
# If either src[prop] or dst[prop] aren't arrays, they are `arrayize`'d first.
arrayizeUniquePusher = new _B.DeepCloneBlender [
    order: ['src']
    unique: true

    #todo: make this default (but define a custome uRequire_ArrayPusher that deals only with `String` & `Array<String>`, throwing error otherwise.
#    '*': 'pushToArray'
#    'Undefined': ->_B.Blender.SKIP
#    'Null': ->_B.Blender.SKIP

    'Array': 'pushToArray'
    'String': 'pushToArray'
    'Number': 'pushToArray'
    'Undefined': 'pushToArray'

    pushToArray: (prop, src, dst, bl)->
      #l.log "pushToArray #{prop} = #{src[prop]}"
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
]

#convert an array of resources, each of which might be an array it self
#to an array of 'proper' resources
# For example
#    [
#      [
#        '*#Name of a non-module(#), non-terminal resource (*)'
#        [
#          '**/*.someext'
#        ]
#        ->
#      ]

#    ]
# to
#    [
#      {
#        name: 'Name of a non-module(#), non-terminal resource (*)'
#        isModule: false
#        isTerminal: false
#        filez: '**/*.someext'
#        convert: ->
#      }
#    ]

resourcesBlender = new _B.DeepCloneBlender [
  order:['path', 'src']

  '*': '|' :
    '[]': (prop, src)->
      resource = src[prop]
      name = resource[0]
      while name[0] in ['#', '*']
        switch name[0]
          when '#' then isModule = false
          when '*' then isTerminal = false
        name = name[1..] # remove 1st char

      isModule ?= true #default
      isTerminal ?= true #default
      filez = resource[1]
      convert = resource[2]
      dstFilename = resource[3]

      {name, isModule, isTerminal, filez, convert, dstFilename}

    # also combine incomplete Object
    # @todo: 4 3 2 - Combine [] & {} into one
    '{}': (prop, src)->
      resource = _.clone src[prop], true
      while resource.name[0] in ['#', '*']
        switch resource.name[0]
          when '#' then resource.isModule ?= false
          when '*' then resource.isTerminal ?= false
        resource.name = resource.name[1..] # remove 1st char

      # defaults
      resource.isModule ?= true
      resource.isTerminal ?= true

      resource

]


#create a finalCfg object & a default deriveLoader
# and call the recursive _blendDerivedConfigs
blendConfigs = (configsArray, deriveLoader)->
  finalCfg = {}

  deriveLoader = # default deriveLoader
    if _.isFunction deriveLoader
      deriveLoader
    else
      (derive)-> #default deriveLoader
        if _.isString derive
          l.verbose "Loading config file: '#{derive}'"
          if cfgObject = require fs.realpathSync derive # @todo: test require using butter-require within uRequire :-)
            return cfgObject
        else
          if _.isObject derive
            return derive

        # if its hasnt returned, we're in error
        l.err """
          Error loading configuration files:
            derive """, derive, """ is a not a valid filename
            while processing derive array ['#{derive.join "', '"}']"
          """

  _blendDerivedConfigs finalCfg, configsArray, deriveLoader
  finalCfg

# the recursive fn that also considers cfg.derive
_blendDerivedConfigs = (cfgFinal, cfgsArray, deriveLoader)->
  # We always blend in reverse order: start copying all items in the most base config
  # (usually 'uRequireConfigMasterDefaults') and continue overwritting/blending backwards
  # from most general to the more specific. Hence the 1st item in configsArray is blended last.
  for cfg in cfgsArray by -1 when cfg

    # in each cfg, we might have nested `derive`s
    # recurse for each of those, depth first style - i.e we apply current cfg LAST
    # (and AFTER we have visited the furthest `derive`d config which has been applied first)
    derivedObjects =
      (for drv in _B.arrayize cfg.derive when drv # no nulls/empty strings
        deriveLoader drv)
    if not _.isEmpty derivedObjects
      _blendDerivedConfigs cfgFinal, derivedObjects, deriveLoader

    # blend this cfg into cfgFinal using the top level blender
    # first moveKeys for each config for configsArray items
    # @todo: (2, 7, 5) rewrite more functional, decoration/declarative/flow style ?
    bundleBuildBlender.blend cfgFinal, moveKeysBlender.blend cfg
  null

module.exports = blendConfigs

# expose blender instances to module.exports/blendConfigs, just for testing
_.extend blendConfigs, {
  moveKeysBlender
  templateBlender
  resourcesBlender
  arrayizeUniquePusher
  dependenciesBindingsBlender
  bundleBuildBlender
}

