_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
require('butter-require')() # no need to store it somewhere
l = new _B.Logger 'urequire/blendConfigs'

uRequireConfigMasterDefaults = require './uRequireConfigMasterDefaults'

### Define the various Blenders used ###

arrayizeUniquePusher = new _B.ArrayizePushBlender [], unique: true
arrayizePusher = new _B.ArrayizePushBlender

# Copy/clone all keys from the 'root' of src,
# to either `dst.bundle` or `dst.build` (the legitimate parts of the config),
# depending on where these keys appear in uRequireConfigMasterDefaults.
#
# NOTE: it simply ignores unknown keys (i.e keys not in uRequireConfigMasterDefaults .build or .bundle)
#       including 'derive'

moveKeysBlender = new _B.DeepCloneBlender [
  {
    order: ['path']
    '*': '|':
      do (partsKeys = {
        bundle: _.keys uRequireConfigMasterDefaults.bundle # eg ['path', 'dependencies', ...]
        build: _.keys uRequireConfigMasterDefaults.build   # eg ['dstPath', 'template', ...]
      })->
        (prop, src, dst, bl)->
          for confPart in _.keys partsKeys # partKeys = ['bundle', 'build'] 
            if prop in partsKeys[confPart]
              _B.setp bl.dstRoot, "/#{confPart}/#{prop}", src[prop], overwrite:true
              break

          _B.Blender.SKIP # no assign

    # just DeepClone our 'legitimate' parts
    bundle: '|': -> _B.Blender.NEXT
    build: '|': -> _B.Blender.NEXT
  }
#  compilers: '|': -> _B.Blender.NEXT # @todo: how do we blend this ?
]
#
#rootLevelKeys =
#    name: 'myBundle'
#    main: 'myMainLib'
#    bundle: # 'bundle' and 'build' hashes have precedence over root items
#      main: 'myLib'
#    path: "/some/path"
#    webRootMap: "."
#    dependencies:
#      depsVars: {}
#      exports: bundle: {}
#
#    dstPath: ""
#    forceOverwriteSources: false
#    template: name: "UMD"
#    watch: false
#    noRootExports: false
#    scanAllow: false
#    allNodeRequires: false
#    verbose: false
#    debugLevel: 0
#    done:->
#
#l.log a = moveKeysBlender.blend rootLevelKeys
#l.log rootLevelKeys.done is a.done

# Backwards compatibility:
# rename DEPRACATED keys to their new ones
renameKeys =
  $:
    bundle:
       bundlePath: 'path'
       bundleName: 'name'
       copyNonResources: 'copy'
       filespecs: 'filez'
       dependencies:
         noWeb: 'node'
         bundleExports: 'exports.bundle'
         variableNames: 'depsVars'
         _knownVariableNames: '_knownDepsVars'
    build:
      outputPath: 'dstPath'

_.extend renameKeys.$, renameKeys.$.bundle # copy $.bundle.* to $.*
_.extend renameKeys.$, renameKeys.$.build # copy $.build.* to $.*

renameKeysBlender = new _B.DeepDefaultsBlender [
  order:['src']
  '*': (prop, src, dst, bl)->
    renameTo = _B.getp renameKeys, bl.path
    if  _.isString renameTo
      l.warn "DEPRACATED key '#{_.last bl.path}' found @ config path '#{bl.path.join '.'}' - rename to '#{renameTo}'"
      _B.setp bl.dstRoot, bl.path.slice(1,-1).join('.')+'.'+renameTo, src[prop], {overwrite:true, separator:'.'}
      return _B.Blender.SKIP

    return _B.Blender.NEXT
]

addIgnoreToFilezAsExclude = (cfg)->
  ignore = _B.arrayize(cfg.bundle?.ignore || cfg.ignore)

  if not _.isEmpty ignore
    l.warn "DEPRACATED key 'ignore' found @ config - adding them as exclude '!' to 'bundle.filez'"
    filez = _B.arrayize(cfg.bundle?.filez || cfg.filez || ['**/*.*'])
    for ignoreSpec in ignore
      filez.push '!'
      filez.push ignoreSpec
    delete cfg.ignore
    delete cfg.bundle.ignore
    _B.setp cfg, ['bundle', 'filez'], filez, {overwrite:true}

  cfg


# bundleBuildBlender
#
# The top level Blender, it uses 'path' to make decisions on how to blend `bundle`.
#
# It extends DeepCloneBlender, so if there's no path match,
# it works like _.clone (deeply).
{_optimizers} = uRequireConfigMasterDefaults.build

bundleBuildBlender = new _B.DeepCloneBlender [
  {
    order: ['path', 'src']

    bundle:

      filez: '|' : '*': (prop, src, dst)-> arrayizePusher.blend dst[prop], src[prop]

      resources: '|' : '*': (prop, src, dst)->
        arrayizePusher.blend dst[prop], resourcesBlender.blend([], src[prop])

      dependencies:
        node: '|': '*': (prop, src, dst)-> arrayizeUniquePusher.blend dst[prop], src[prop]

        exports:
          bundle: '|': '*': 'dependenciesBindings'
          #root: NOT IMPLEMENTED
        depsVars: '|': '*': 'dependenciesBindings'
        _knownDepsVars: '|': '*': 'dependenciesBindings'

    dependenciesBindings: (prop, src, dst)->
      dependenciesBindingsBlender.blend dst[prop], src[prop]

    build:

      copy: '|' : '*': (prop, src, dst)-> arrayizePusher.blend dst[prop], src[prop]

      template: '|': '*': (prop, src, dst)->
        templateBlender.blend dst[prop], src[prop]

      # 'optimize' ? in 3 different ways
      # todo: spec it
      optimize: '|':
        # enable 'uglify2' for true
        Boolean: (prop, src, dst)-> _optimizers[0] if src[prop]

        # find if proper optimizer, default 'ulgify2''
        String: (prop, src, dst)->
          if not optimizer = (_.find _optimizers, (v)-> v is src[prop])
            l.err "Unknown optimize '#{src[prop]}' - using 'uglify2' as default"
            _optimizers[0]
          else
            optimizer

        # eg optimize: { uglify2: {...uglify2 options...}}
        Object: (prop, src, dst)->
          # find a key that's an optimizer, eg 'uglify2'
          if not optimizer = (_.find _optimizers, (v)-> v in _.keys src[prop])
            l.err "Unknown optimize object", src[prop], " - using 'uglify2' as default"
            _optimizers[0]
          else 
            dst[optimizer] = src[prop][optimizer] # if optimizer is 'uglify2', copy { uglify2: {...uglify2 options...}} to dst ('ie build')
            optimizer
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
  order: ['src']                                                     # our src[prop] (i.e. depsVars eg exports.bundle) is either a:

  'String': (prop, src, dst)->                                       # * String eg  'lodash'.
    arrayizeUniquePusher.blend dst[prop], _B.okv({}, src[prop], [])  #   convert to {'lodash':[]}

  'Array': (prop, src, dst)->                                        # * Array, eg  `['lodash', 'jquery']`
    varBindings = {}
    _B.go src[prop], grab: (v)-> varBindings[v] or= []               #   convert to `{lodash:[], jquery:[]}`
    arrayizeUniquePusher.blend dst[prop], varBindings

  'Object': (prop, src, dst)->                                       # * Object eg {'lodash': '???', ...}
    arrayizeUniquePusher.blend dst[prop], src[prop]                  #   convert to    `{lodash:['???'], ...}`
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
          l.debug "Loading config file: '#{derive}'"
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
_blendDerivedConfigs = (cfgDest, cfgsArray, deriveLoader)->
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
      _blendDerivedConfigs cfgDest, derivedObjects, deriveLoader

    # blend this cfg into cfgDest using the top level blender
    # first moveKeys for each config for configsArray items
    # @todo: (2, 7, 5) rewrite more functional, decoration/declarative/flow style ?
    bundleBuildBlender.blend cfgDest, moveKeysBlender.blend addIgnoreToFilezAsExclude renameKeysBlender.blend cfg
  null

module.exports = blendConfigs

# expose blender instances to module.exports/blendConfigs, just for testing
_.extend blendConfigs, {
  moveKeysBlender
  renameKeysBlender
  templateBlender
  resourcesBlender
  dependenciesBindingsBlender
  bundleBuildBlender
}

