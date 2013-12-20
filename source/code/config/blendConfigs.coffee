_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/blendConfigs'
fs = require 'fs'
require('butter-require')() # no need to store it somewhere

upath = require '../paths/upath'
MasterDefaultsConfig = require './MasterDefaultsConfig'
ResourceConverter = require './ResourceConverter'

UError = require '../utils/UError'

arrayizeUniquePusher = new _B.ArrayizePushBlender [], unique: true
arrayizePusher = new _B.ArrayizePushBlender

# Copy/clone all keys from the 'root' of src,
# to either `dst.bundle` or `dst.build` (the legitimate parts of the config),
# depending on where these keys appear in MasterDefaultsConfig.
#
# NOTE: it simply ignores unknown keys (i.e keys not in MasterDefaultsConfig .build or .bundle)
#       including 'derive'

moveKeysBlender = new _B.Blender [
  {
    order: ['path']
    '*': '|':
      do (partsKeys = {
        bundle: _.keys MasterDefaultsConfig.bundle # eg ['path', 'dependencies', ...]
        build: _.keys MasterDefaultsConfig.build   # eg ['dstPath', 'template', ...]
      })->
        (prop, src, dst)->
          for confPart in _.keys partsKeys # partKeys = ['bundle', 'build'] 
            if prop in partsKeys[confPart]
              _B.setp @dstRoot, "/#{confPart}/#{prop}", src[prop], overwrite:true
              break

          @SKIP # no assign

    # just DeepClone our 'legitimate' parts
    bundle: '|': -> _B.Blender.NEXT
    build: '|': -> _B.Blender.NEXT
  }
#  compilers: '|': -> _B.Blender.NEXT # @todo: how do we blend this ?
]

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

depracatedKeysBlender = new _B.DeepDefaultsBlender [
  order:['src']
  '*': (prop, src, dst)->
    renameTo = _B.getp renameKeys, @path
    if  _.isString renameTo
      l.warn "DEPRACATED key '#{_.last @path}' found @ config path '#{@path.join '.'}' - rename to '#{renameTo}'"
      _B.setp @dstRoot, @path.slice(1,-1).join('.')+'.'+renameTo, src[prop], {overwrite:true, separator:'.'}
      return @SKIP

    @NEXT
]

addIgnoreToFilezAsExclude = (cfg)->
  ignore = _B.arrayize(cfg.bundle?.ignore || cfg.ignore)

  if not _.isEmpty ignore
    l.warn "DEPRACATED key 'ignore' found @ config - adding them as exclude '!' to 'bundle.filez'"
    filez = _B.arrayize(cfg.bundle?.filez || cfg.filez || ['**/*'])
    for ignoreSpec in ignore
      filez.push '!'
      filez.push ignoreSpec
    delete cfg.ignore
    delete cfg.bundle.ignore
    _B.setp cfg, ['bundle', 'filez'], filez, {overwrite:true}

  cfg

# The top level Blender, it uses 'path' to make decisions on how to blend `bundle`.
#
# It extends DeepCloneBlender, so if there's no path match,
# it works like _.clone (deeply).
{_optimizers} = MasterDefaultsConfig.build

bundleBuildBlender = new _B.DeepCloneBlender [
  {
    order: ['path', 'src', 'dst']

    arrayizeConcat: (prop, src, dst)->
      if _.isFunction src[prop]
        src[prop] _.clone(_B.arrayize dst[prop]), dst, prop  #todo: move -> functionality to arrayizePusher
      else
        arrayizePusher.blend dst[prop], _.clone(src[prop])

    arraysConcatOrOverwrite: (prop, src, dst)->
      if _.isFunction src[prop]
        src[prop] _.clone(_B.arrayize dst[prop]), dst, prop
      else
        if _.isArray(dst[prop]) and _.isArray(src[prop])
          arrayizePusher.blend _.clone(dst[prop]), src[prop] #takes care of 'parent reset'
        else
          src[prop] # just copy src[prop] over to dst[prop]

    dependenciesBindings: (prop, src, dst)->
      dependenciesBindingsBlender.blend dst[prop], src[prop]

    bundle:

      filez: '|': '*': 'arrayizeConcat'

      copy: '|': '*': 'arrayizeConcat'

      resources: '|':
        '*': (prop, src)->
          throw new Error "`bundle.resources` must be an array - was : ", src[prop]
        '[]': (prop, src, dst)->
          rcs = []
          for rc in src[prop]
            if _.isEqual rc, [null] # cater for [null] reset array signpost for arrayizePusher
              rcs.push rc
            else
              rc = ResourceConverter.searchRegisterUpdate rc
              if rc and !_.isEmpty(rc)
                rcs.push rc

          arrayizePusher.blend dst[prop], rcs

      dependencies:

        node: '|': '*': 'arrayizeConcat'

        exports:

          bundle: '|': '*': 'dependenciesBindings'

          root: '|': '*': 'dependenciesBindings'

        replace: '|': '*': 'dependenciesBindings' # paradoxically, its compatible albeit a different meaning!

        locals: '|': '*': 'dependenciesBindings' # paradoxically, its compatible albeit a different meaning!

        depsVars: '|': '*': 'dependenciesBindings'

        _knownDepsVars: '|': '*': 'dependenciesBindings'

    build:
      # todo: generalize this :
      useStrict: '|': 'arraysConcatOrOverwrite'
      bare: '|': 'arraysConcatOrOverwrite'
      globalWindow: '|': 'arraysConcatOrOverwrite'
      runtimeInfo: '|': 'arraysConcatOrOverwrite'
      allNodeRequires: '|': 'arraysConcatOrOverwrite'
      dummyParams: '|': 'arraysConcatOrOverwrite'
      injectExportsModule: '|': 'arraysConcatOrOverwrite'
      noRootExports: '|': 'arraysConcatOrOverwrite'
      scanAllow: '|': 'arraysConcatOrOverwrite'

      template: '|': '*': (prop, src, dst)->
        templateBlender.blend dst[prop], src[prop]

      debugLevel: '|': '*': (prop, src)->
        dl = src[prop] * 1
        if _.isNumber(dl) and not _.isNaN(dl)
          dl
        else
          l.warn 'Not a Number debugLevel: ', src[prop], ' - defaulting to 1.'
          1

      # 'optimize' ? in 3 different ways
      # todo: spec it
      optimize: '|':
        # enable 'uglify2' for true
        Boolean: (prop, src, dst)-> _optimizers[0] if src[prop]

        # find if proper optimizer, default 'ulgify2''
        String: (prop, src, dst)->
          if not optimizer = (_.find _optimizers, (v)-> v is src[prop])
            l.er "Unknown optimize '#{src[prop]}' - using 'uglify2' as default"
            _optimizers[0]
          else
            optimizer

        # eg optimize: { uglify2: {...uglify2 options...}}
        Object: (prop, src, dst)->
          # find a key that's an optimizer, eg 'uglify2'
          if not optimizer = (_.find _optimizers, (v)-> v in _.keys src[prop])
            l.er "Unknown optimize object", src[prop], " - using 'uglify2' as default"
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

  'String': (prop, src, dst)->                                       # String eg  'lodash', convert to {'lodash':[]}
    dst[prop] or= {}
    dst[prop][src[prop]] or= []                                      # set a 'lodash' key with `[]` as value on our dst
    dst[prop]

  '[]': (prop, src, dst)->                                        # Array, eg  `['lodash', 'jquery']`, convert to `{lodash:[], jquery:[]}`
    if not _B.isHash dst[prop]
      dst[prop] = {}
    else
      dst[prop] = _B.mutate _.clone(dst[prop], true), _B.arrayize

    for dep in src[prop]
      dst[prop][dep] = _B.arrayize dst[prop][dep]

    dst[prop]

  '{}': (prop, src, dst)->                                       # * Object eg {'lodash': '???', ...}, convert to    `{lodash:['???'], ...}`
    if not _B.isHash dst[prop]
      dst[prop] = {}
    else
      dst[prop] = _B.mutate _.clone(dst[prop], true), _B.arrayize

    for dep, depVars of src[prop]
      dst[prop][dep] = arrayizeUniquePusher.blend dst[prop][dep], depVars

    dst[prop]

  '->': (prop, src, dst)->
    if not _B.isHash dst[prop]
      dst[prop] = {}
    else
      dst[prop] = _B.mutate _.clone(dst[prop], true), _B.arrayize

    src[prop] dst[prop], dst, prop
]

deepCloneBlender = new _B.DeepCloneBlender #@todo: why deepCloneBlender need this instead of @

templateBlender = new _B.DeepCloneBlender [
  order: ['src']

  # our src[prop] template is a String eg 'UMD'.
  # blend as {name:'UMD'}
  'String': (prop, src, dst)->
    #dst[prop] = {} if src[prop] isnt dst[prop]?.name # REMOVED
    deepCloneBlender.blend dst[prop], {name: src[prop]}

  # our src[prop] template is an Object - should be {name: 'UMD', '...': '...'}
  '{}': (prop, src, dst)->
    # blend as is but reset dst object if template has changed! REMOVED
    #dst[prop] = {} if (src[prop].name isnt dst[prop]?.name) and not _.isUndefined(src[prop].name)
    deepCloneBlender.blend dst[prop], src[prop]
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
          l.debug 5, "Loading config file: '#{derive}'"
          try
            if cfgObject = require fs.realpathSync derive # @todo: test require using butter-require within uRequire :-)
              return cfgObject
          catch err
            l.er errMsg = "Error loading configuration: Can't load '#{derive}'.", err
            throw new UError errMsg, nested: err
        else
          if _.isObject derive
            return derive

  _blendDerivedConfigs finalCfg, configsArray, deriveLoader
  finalCfg

# the recursive fn that also considers cfg.derive
_blendDerivedConfigs = (cfgDest, cfgsArray, deriveLoader)->
  # We always blend in reverse order: start copying all items in the most base config
  # (usually 'MasterDefaultsConfig') and continue overwritting/blending backwards
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
    bundleBuildBlender.blend cfgDest, moveKeysBlender.blend addIgnoreToFilezAsExclude depracatedKeysBlender.blend cfg
  null

# expose blender instances to module.exports/blendConfigs, mainly for testing
_.extend blendConfigs, {
  moveKeysBlender
  depracatedKeysBlender
  templateBlender
  dependenciesBindingsBlender
  bundleBuildBlender
}

module.exports = blendConfigs

urequire:
 rootExports: '_B'
 noConflict: true