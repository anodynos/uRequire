fs = require 'fs'
upath = require 'upath'
require('butter-require')() # no need to store it somewhere

MasterDefaultsConfig = require './MasterDefaultsConfig'
ResourceConverter = require './ResourceConverter'

arrayizeUniqueReversingUnshifter = new _B.ArrayizeBlender [], {unique: true, reverse:true, addMethod: 'unshift'}
arrayizeUniquePusher = new _B.ArrayizeBlender [], {unique: true}
arrayizeBlender = new _B.ArrayizeBlender

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
      }) ->
        (prop, src, dst) ->
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

# Backwards compatibility: rename DEPRACATED keys to their new ones
renameKeys =
  $:
    bundle:
      bundlePath: 'path'
      bundleName: 'name'
      copyNonResources: 'copy'
      filespecs: 'filez'
      dependencies:
        noWeb: 'node'
        bundleExports: 'imports'
        exports:
          bundle: '../imports'
          root: '../rootExports'
        variableNames: 'depsVars'
        _knownVariableNames: '_knownDepsVars'
    build:
      outputPath: 'dstPath'
      done: 'afterBuild'
      exportsRoot: 'rootExports/runtimes'
      noRootExports: 'rootExports/ignore'

_.extend renameKeys.$, renameKeys.$.bundle # copy $.bundle.* to $.*
_.extend renameKeys.$, renameKeys.$.build # copy $.build.* to $.*

depracatedKeysBlender = new _B.DeepDefaultsBlender [
  order:['src']
  '*': (prop, src, dst) ->
    renameTo = _B.getp renameKeys, @path
    if  _.isString renameTo
      renameToPath = upath.normalizeSafe upath.join @path.slice(1,-1).join('/'), renameTo
      l.warn "DEPRACATED config path found '#{@path.slice(1).join '/'}' - rename to '#{renameToPath}'"
      _B.setp @dstRoot, renameToPath, src[prop], {overwrite:true, separator:'/'}
      #todo: delete empty parents - eg `dependencies/exports`: {}
      return @SKIP

    @NEXT
]

addIgnoreToFilezAsExclude = (cfg) ->
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

    arrayizeConcat: (prop, src, dst) ->
      if _.isFunction src[prop]
        src[prop] _.clone(_B.arrayize dst[prop]), dst, prop  #todo: move -> functionality to arrayizeBlender
      else
        arrayizeBlender.blend dst[prop], _.clone(src[prop])

    arraysConcatOrOverwrite: (prop, src, dst) ->
      if _.isFunction src[prop]
        src[prop] _.clone(_B.arrayize dst[prop]), dst, prop
      else
        if _.isArray(dst[prop]) and _.isArray(src[prop])
          arrayizeBlender.blend _.clone(dst[prop]), src[prop] #takes care of 'parent reset'
        else
          src[prop] # just copy src[prop] over to dst[prop]

    dependenciesBindings: (prop, src, dst) ->
      dependenciesBindingsBlender.blend dst[prop], src[prop]

    bundle:

      filez: '|': '*': 'arrayizeConcat'

      copy: '|': '*': 'arrayizeConcat'

      resources: '|': '*': 'arrayizeConcat'

      dependencies:

        node: '|': '*': 'arrayizeConcat'

        imports: '|': '*': 'dependenciesBindings'

        rootExports: '|': '*': 'dependenciesBindings'

        replace: '|': '*': 'dependenciesBindings' # paradoxically, its compatible albeit a different meaning!

        locals: '|': '*': 'dependenciesBindings' # paradoxically, its compatible albeit a different meaning!

        depsVars: '|': '*': 'dependenciesBindings'

        _knownDepsVars: '|': '*': 'dependenciesBindings'

        paths: override: '|': '*': 'dependenciesBindings'

        # @todo: throw on unknown keys eg:
        #"*": "|" : '*': (prop, src, dst) ->
        #   throw new Error "unknown key #{prop} in #{@path.join('/')}"
        # needs to
        # a) delete old/empty parents in `depracatedKeysBlender`
        #    so we need a _B.delp like _B.setp / _B.getp
        # b) generalize with a customized Blender

    build:
      # todo: generalize this :
      useStrict: '|': 'arraysConcatOrOverwrite'
      bare: '|': 'arraysConcatOrOverwrite'
      globalWindow: '|': 'arraysConcatOrOverwrite'
      runtimeInfo: '|': 'arraysConcatOrOverwrite'
      allNodeRequires: '|': 'arraysConcatOrOverwrite'
      dummyParams: '|': 'arraysConcatOrOverwrite'
      injectExportsModule: '|': 'arraysConcatOrOverwrite'
      scanAllow: '|': 'arraysConcatOrOverwrite'
      noLoaderUMD: '|': 'arraysConcatOrOverwrite'
      warnNoLoaderUMD: '|': 'arraysConcatOrOverwrite'
      deleteErrored: '|': 'arraysConcatOrOverwrite'

      rootExports:
        runtimes: '|': 'overwrite'
        ignore: '|': 'arraysConcatOrOverwrite'      # renamed from `noRootExports`
        noConflict: '|': 'arraysConcatOrOverwrite'

      watch: '|': (prop, src, dst) ->
        watchBlender.blend dst[prop], src[prop]

      template: '|': '*': (prop, src, dst) ->
        templateBlender.blend dst[prop], src[prop]

      debugLevel: '|': '*': (prop, src) ->
        dl = src[prop] * 1
        if _.isNumber(dl) and not _.isNaN(dl)
          dl
        else
          l.warn 'Not a Number debugLevel: ', src[prop], ' - defaulting to 1.'
          1

      afterBuild: '|': (prop, src, dst) ->
        arrayizeBlender.blend dst[prop], src[prop] # no function array blending, cause we deal with functions

      # cant seperate cause it writes on dst
      optimize: '|':
        # enable 'uglify2' for true
        Boolean: (prop, src, dst) -> _optimizers[0] if src[prop]

        # find if proper optimizer, default 'ulgify2''
        String: (prop, src, dst) ->
          if not optimizer = (_.find _optimizers, (v) -> v is src[prop])
            l.er "Unknown optimize '#{src[prop]}' - using 'uglify2' as default"
            _optimizers[0]
          else
            optimizer

        # eg optimize: { uglify2: {...uglify2 options...}}
        '{}': (prop, src, dst) ->
          # find a key that's an optimizer, eg 'uglify2'
          if not optimizer = (_.find _optimizers, (v) -> v in _.keys src[prop])
            l.warn "Unknown optimize object", src[prop], " - using 'uglify2' as default"
            _optimizers[0]
          else
            dst[optimizer] = src[prop][optimizer] # if optimizer is 'uglify2', copy { uglify2: {...uglify2 options...}} to dst ('ie build')
            optimizer

      rjs: shim: '|': (prop, src, dst) ->
        shimBlender.blend dst[prop], src[prop]
  }
]

# blend these
# { 'jquery.colorize': { deps: ['jquery'], exports: 'jQuery.fn.colorize'},
#       or
# { 'jquery.colorize': ['jquery'] }
shimBlender = new _B.DeepCloneBlender [
  order: ['src']

  '{}': (prop, src, dst) ->
    dst[prop] = {} if !_B.isHash dst[prop]
    for mod, modShim of src[prop]
      depsArray = if _.isArray modShim then modShim else modShim.deps

      if dst[prop][mod]
        depsArray = arrayizeUniquePusher.blend([], depsArray, dst[prop][mod].deps)
      else
        dst[prop][mod] = {}

      if _B.isHash modShim
        _.extend dst[prop][mod], modShim

      dst[prop][mod].deps = depsArray

    @SKIP

  'Undefined': -> @SKIP
  'Boolean': -> @SKIP
  '*': (prop, src) ->
    throw new UError "Unknown shim: `#{l.prettify src[prop]}`."
    # todo: throw FatalError - shouldn't continue when config has errors
]

watchBlender = new _B.DeepCloneBlender [

    order: ['path', 'src']

    arrayizeUniquePusherSplitStrings: (prop, src, dst) ->
      srcVal =
        if _.isString src[prop]
          src[prop].split(/\s/).filter((t) ->!!t)
        else
          src[prop]

      arrayizeUniquePusher.blend [], dst[prop], srcVal

    after: '|': '*': 'arrayizeUniquePusherSplitStrings'
    before: '|': '*': 'arrayizeUniquePusherSplitStrings'
    files: '|': '*': (prop, src, dst) ->
      arrayizeUniquePusher.blend dst[prop], src[prop]

    '|':
      String: (prop, src, dst) ->
        num = parseInt src[prop]
        w = if not _.isNaN num # cast to number, store as `debounceDelay`
              debounceDelay: num
              enabled: true
            else
              info: src[prop]       # store the string as `info`
              enabled: true

        deepCloneBlender.blend dst[prop], w

      Number: (prop, src, dst) -> deepCloneBlender.blend dst[prop], {enabled: true, debounceDelay: src[prop]}

      Boolean: (prop, src, dst) -> deepCloneBlender.blend dst[prop], enabled: src[prop]

      '{}': (prop, src, dst) -> watchBlender.blend {}, dst[prop], enabled: true, src[prop]

      '*': (prop, src) -> throw new UError "Invalid watch value #{l.prettify src[prop]}"

      'Undefined': -> @SKIP

]#, debugLevel: 90

###
*dependenciesBindingsBlender*

Converts String, Array<String> or Object {variable:bindingsArrayOfStringsOrString
to the 'proper' dependenciesBinding structure ({dependency1:ArrayOfDep1Bindings, dependency2:ArrayOfDep2Bindings, ...}

So with    *source*                 is converted to proper      *destination*
* String : `'lodash'`                       --->                `{lodash:[]}`

* Array<String>: `['lodash', 'jquery']`     --->            `{lodash:[], jquery:[]}`

* Object: `{lodash:['_'], jquery: '$'}`     --->          as is @todo: convert '$' to proper ['$'], i.e `{lodash:['_'], jquery: ['$']}`

The resulting array of bindings for each 'variable' is blended via arrayizeUniqueReversingUnshifter
to the existing? corresponding array on the destination
###
dependenciesBindingsBlender = new _B.DeepCloneBlender [
  order: ['src']                                                     # our src[prop] (i.e. depsVars eg imports) is either a:

  'String': (prop, src, dst) ->                                       # String eg  'lodash', convert to {'lodash':[]}
    dst[prop] or= {}
    dst[prop][src[prop]] or= []                                      # set a 'lodash' key with `[]` as value on our dst
    dst[prop]

  '[]': (prop, src, dst) ->                                        # Array, eg  `['lodash', 'jquery']`, convert to `{lodash:[], jquery:[]}`
    if not _B.isHash dst[prop]
      dst[prop] = {}
    else
      dst[prop] = _B.mutate _.clone(dst[prop], true), _B.arrayize

    for dep in src[prop]
      dst[prop][dep] = _B.arrayize dst[prop][dep]

    dst[prop]

  '{}': (prop, src, dst) ->                                       # * Object eg {'lodash': '???', ...}, convert to    `{lodash:['???'], ...}`
    if not _B.isHash dst[prop]
      dst[prop] = {}
    else
      dst[prop] = _B.mutate _.clone(dst[prop], true), _B.arrayize

    for dep, depVars of src[prop]
      dst[prop][dep] = arrayizeUniqueReversingUnshifter.blend dst[prop][dep], depVars

    dst[prop]

  '->': (prop, src, dst) ->
    if not _B.isHash dst[prop]
      dst[prop] = {}
    else
      dst[prop] = _B.mutate _.clone(dst[prop], true), _B.arrayize

    src[prop] dst[prop], dst, prop

  '*': -> _B.Blender.SKIP
]

deepCloneBlender = new _B.DeepCloneBlender #@todo: why deepCloneBlender need this instead of @

templateBlender = new _B.DeepCloneBlender [
  order: ['src']

  # our src[prop] template is a String eg 'UMD'.
  # blend as {name:'UMD'}
  'String': (prop, src, dst) ->
    #dst[prop] = {} if src[prop] isnt dst[prop]?.name # REMOVED
    deepCloneBlender.blend dst[prop], {name: src[prop]}

  # our src[prop] template is an Object - should be {name: 'UMD', '...': '...'}
  '{}': (prop, src, dst) ->
    # blend as is but reset dst object if template has changed! REMOVED
    #dst[prop] = {} if (src[prop].name isnt dst[prop]?.name) and not _.isUndefined(src[prop].name)
    deepCloneBlender.blend dst[prop], src[prop]
]

defaultDeriveLoader = (derive) ->
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

# keep track of which cfgs have been added,
# to filter out duplicates due to multiple inheritance
# only the higher level same cfg is blended
# as in diamond style multiple inheritance
addedCfgs = null

inArrayWithEquals = (item, array) ->
  for arItem in array
    if _.isEqual item, arItem
      return true
  false

# create a finalCfg object & a default deriveLoader
# and call the recursive _blendDerivedConfigs
blendConfigs = (configsArray, deriveLoader, withMaster = false) ->
  configsArray.push MasterDefaultsConfig if withMaster
  deriveLoader = defaultDeriveLoader if not _.isFunction deriveLoader
  addedCfgs = []

  _blendDerivedConfigs finalCfg = {}, configsArray, deriveLoader

  if !_.isEmpty finalCfg.bundle?.resources
    resources = []
    for resourceConverter, idx in finalCfg.bundle.resources
      resources.push rc if not _.isEmpty rc = ResourceConverter.searchRegisterUpdate resourceConverter
    finalCfg.bundle.resources = _(resources).reverse().unique().reverse().value() # keep only last RC encountered.

  finalCfg

# the recursive fn that also considers cfg.derive
_blendDerivedConfigs = (cfgDest, cfgsArray, deriveLoader) ->
  # We always blend in reverse order: start copying all items in the most base config
  # (usually 'MasterDefaultsConfig') and continue overwritting/blending backwards
  # from most general to the more specific. Hence the 1st item in configsArray is blended last.
  for cfg in cfgsArray by -1 when cfg and not inArrayWithEquals(cfg, addedCfgs)
    addedCfgs.push cfg
    # in each cfg, we might have nested `derive`s
    # recurse for each of those, depth first style - i.e we apply current cfg LAST
    # (and AFTER we have visited the furthest `derive`d config which has been applied first)
    derivedObjects =
      (for drv in _B.arrayize cfg.derive when drv # no nulls/empty strings
        deriveLoader drv)

    if not _.isEmpty derivedObjects
      _blendDerivedConfigs cfgDest, _.flatten(derivedObjects), deriveLoader

    # blend this cfg into cfgDest using the top level blender
    # first moveKeys for each config for configsArray items
    # @todo: (2, 7, 5) rewrite more functional, decoration/declarative/flow style ?
    bundleBuildBlender.blend cfgDest, moveKeysBlender.blend addIgnoreToFilezAsExclude depracatedKeysBlender.blend cfg
  null

# expose blender instances to module.exports/blendConfigs, mainly for testing
_.extend blendConfigs, {
  moveKeysBlender
  depracatedKeysBlender
  bundleBuildBlender
  dependenciesBindingsBlender
  templateBlender
  shimBlender
  watchBlender
}

module.exports = blendConfigs
