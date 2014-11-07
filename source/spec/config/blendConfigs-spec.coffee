_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/config/blendConfigs-spec'

chai = require 'chai'
expect = chai.expect
{ equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
  ixact, notIxact, like, notLike, likeBA, notLikeBA, equalSet, notEqualSet } = require '../specHelpers'

blendConfigs = require '../../code/config/blendConfigs'
MasterDefaultsConfig = require '../../code/config/MasterDefaultsConfig'
{
  moveKeysBlender
  depracatedKeysBlender
  templateBlender
  dependenciesBindingsBlender
  bundleBuildBlender
} = blendConfigs

arrayizePushBlender = new _B.ArrayizeBlender

ResourceConverter = require '../../code/config/ResourceConverter'

resources =  [
  [
    '$+cofreescript' # a title of the resource (a module since its starting with '$', running after adjusting module info cause of '+')
    [
      '**/*.coffee'
      /.*\.(coffee\.md|litcoffee)$/i
      '!**/*.amd.coffee'
    ]
    (source)-> source
    (filename)-> filename.replace '.coffee', '.js' # dummy filename converter
    {some: coffee: 'options'}
  ]

  [
    '~Streamline' # a title of the resource (without type since its not in [@ # $], but with isAfterTemplate:true due to '!' (runs only on Modules)
    'I am the Streamline descr' # a descr (String) at pos 1
    '**/*._*'                         # even if we have a String as an implied `filez` array
    (source)-> source
    (filename)-> filename.replace '._js', '.js' # dummy filename converter
  ]

  {
    name: '#|NonModule' #a non-module TextResource (starting with '#'), isTerminal:true (starting with '|')
    filez: '**/*.nonmodule'
    convert: ->
  }

  [
    '@~AFileResource' #a FileResource (@) isMatchSrcFilename:true (~)
    '**/*.ext'        # this is a `filez`, not a descr if pos 1 isString & pos 2 not a String|Array|RegExp
    ->
    { some: options: after: 'convert' }
  ]

  {
    name: '#IamAFalseModule' # A TextResource (starting with '#')
    #type: 'module'            # this is not respected, over flag starting with '#'
    filez: '**/*.module'
    convert: ->
  }

  ->
    rc = @ 'cofreescript'    # retrieve a registered RC
    rc.name = 'coffeescript' # change its name
    rc                       # add it to 'resources' at this point, but remove it from where it was
]

expectedResources = [
  # coff(r)eescript is removed from here, since only the last one instance declared remains

  {
    ' name': 'Streamline'
    descr: 'I am the Streamline descr'
    filez: '**/*._*'
    convert: resources[1][3]
    ' convFilename': resources[1][4]
    _convFilename: resources[1][4]
    isTerminal: false
    isMatchSrcFilename: true
    runAt: ''
    enabled: true
    options: {}
  }

  {
    ' name': 'NonModule'
    descr: 'No descr for ResourceConverter \'NonModule\''
    filez: '**/*.nonmodule'
    convert: resources[2].convert
    ' type': 'text'
    isTerminal: true
    isMatchSrcFilename: false
    runAt: ''
    enabled: true
    options: {}
  }

  {
    ' name': 'AFileResource'
    descr: 'No descr for ResourceConverter \'AFileResource\''
    filez: '**/*.ext'
    convert: resources[3][2]
    ' type': 'file'
    isTerminal: false
    isMatchSrcFilename:true
    runAt: ''
    enabled: true
    options: { some: options: after: 'convert' }
  }

  {
    ' name': 'IamAFalseModule'
    descr: 'No descr for ResourceConverter \'IamAFalseModule\''
    filez: '**/*.module'
    convert: resources[4].convert
    ' type': 'text'
    isTerminal: false
    isMatchSrcFilename: false
    runAt: ''
    enabled: true
    options: {}
  }

  {
    ' name': 'coffeescript'      # name is changed
    descr: 'No descr for ResourceConverter \'cofreescript\'',
    filez: [
      '**/*.coffee'
      /.*\.(coffee\.md|litcoffee)$/i
      '!**/*.amd.coffee'
    ]
    convert: resources[0][2]
    ' convFilename': resources[0][3]
    _convFilename: resources[0][3]
    ' type': 'module'
    isTerminal: false
    isMatchSrcFilename: false
    runAt: 'beforeTemplate'
    enabled: true
    options: {some: coffee: 'options'}
  }
]

describe "blendConfigs handles all config nesting / blending / derivation, moving & depracted keys", ->

  describe '`MasterDefaultsConfig` consistency', ->
    it "No same name keys in bundle & build ", ->
      ok _B.isDisjoint _.keys(MasterDefaultsConfig.bundle),
                      _.keys(MasterDefaultsConfig.build)

  describe 'blendConfigs & its Blenders: ', ->

    describe 'moveKeysBlender:', ->
      rootLevelKeys =
        name: 'myBundle'
        main: 'myMainLib'
        bundle: # 'bundle' and 'build' hashes have precedence over root items
          main: 'myLib'
        path: "/some/path"
        webRootMap: "."
        dependencies:
          depsVars: {'dep': 'var'}
          imports: {'importdep': 'importDepVar'}

        dstPath: ""
        forceOverwriteSources: false
        template: name: "UMD"
        watch: false
        rootExports:
          ignore: false
        scanAllow: false
        allNodeRequires: false
        verbose: false
        debugLevel: 10
        afterBuild:->

      result = moveKeysBlender.blend rootLevelKeys

      it "result is NOT the srcObject", ->
        notEqual result, rootLevelKeys

      it "Copies keys from the 'root' of src, to either `dst.bundle` or `dst.build`, depending on where keys are on `MasterDefaultsConfig`", ->
        deepEqual result,
            bundle:
              name: 'myBundle'
              main: 'myLib'
              path: "/some/path"
              webRootMap: "."
              dependencies:
                depsVars: {'dep': 'var'}
                imports: {'importdep': 'importDepVar'}

            build:
              dstPath: ""
              forceOverwriteSources: false
              template: name: "UMD"
              watch: false
              rootExports:
                ignore: false
              scanAllow: false
              allNodeRequires: false
              verbose: false
              debugLevel: 10
              afterBuild: rootLevelKeys.afterBuild


      it "it gives precedence to items in 'bundle' and 'build' hashes, over root items.", ->
        deepEqual moveKeysBlender.blend(
            main: 'myMainLib'
            bundle: # 'bundle' and 'build' hashes have precedence over root items
              main: 'myLib'

            dstPath: "/some/OTHER/path"
            build: # 'bundle' and 'build' hashes have precedence over root items
              dstPath: "/some/path"
            )
          ,
            bundle:
              main: 'myLib'
            build:
              dstPath: "/some/path"

      it "ignores root keys deemed irrelevant (not exist on `MasterDefaultsConfig`'s `.build` or `.bundle`.)", ->
        deepEqual moveKeysBlender.blend(
              iRReLeVaNt_key_is_Ignored: true
              name: 'myBundle'
              bundle: # root items have precedence over 'bundle' and 'build' hashes.
                bundle_iRReLeVaNt_key_is_NOT_Ignored: true
                path: "/some/path"
            )
          ,
            bundle:
              bundle_iRReLeVaNt_key_is_NOT_Ignored: true
              name: 'myBundle'
              path: "/some/path"

    describe "depracatedKeysBlender:", ->
      it "renames DEPRACATED keys to their new name", ->

        oldCfg =
          bundle:
            bundlePath: "source/code"
            main: "index"
            filespecs: '*.*'
            ignore: [/^draft/] # ignore not handled in depracatedKeysBlender
            dependencies:
              noWeb: 'util'
              bundleExports: {lodash:'_'}
              _knownVariableNames: {jquery:'$'}

          build:
            noRootExports: true
            exportsRoot: ['script', 'AMD']

        deepEqual depracatedKeysBlender.blend(oldCfg),
          bundle:
            path: 'source/code'
            main: 'index'
            filez: '*.*',
            ignore: [ /^draft/ ]
            dependencies:
              node: 'util'
              imports: { lodash: '_' }
              _knownDepsVars: { jquery: '$'}

          build:
            rootExports:
              ignore: true
              runtimes: ['script', 'AMD']


    describe "templateBlender:", ->
      describe "template is a String:", ->

        it "converts to {name:'TheString'} ", ->
          deepEqual templateBlender.blend('UMD'), {name: 'UMD'}

        it "converts & blends to {name:'TheString'} ", ->
          deepEqual templateBlender.blend(
              {} # useless
              {name:'UMD', otherRandomOption: 'someRandomValue'}
              {}
              'UMD'
              )
            ,
              name: 'UMD'
              otherRandomOption: 'someRandomValue'
  # functionality surpressed
  #      it "resets dest Object if src name is changed", ->
  #        deepEqual templateBlender.blend(
  #            {}
  #            {name: 'UMD', otherRandomOption: 'someRandomValue'}
  #            {}
  #            'combined'
  #            )
  #          ,
  #            name: 'combined'

      describe "template is {}:", ->
        it "blends to existing ", ->
          deepEqual templateBlender.blend(
              {}
              {name: 'UMD', otherRandomOption: 'someRandomValue'}
              {}
              {name: 'UMD'}
            )
          ,
            name: 'UMD'
            otherRandomOption: 'someRandomValue'

  # functionality surpressed
  #      it "resets dest Object if template.name is changed", ->
  #        deepEqual templateBlender.blend(
  #            {}
  #            {name: 'UMD', otherRandomOption: 'someRandomValue'}
  #            {}
  #            {name: 'combined'}
  #          )
  #        ,
  #          name: 'combined'

    describe "blending config with ResourceConverters :", ->
      resultRCsCfg = null
      rcNames = null

      before ->
        resultRCsCfg = blendConfigs [{resources}]
        rcNames = _.map resultRCsCfg.bundle.resources, (rc)-> rc[' name']

      it "converts array of RC-specs' into array of RC-instances:", ->
        deepEqual resultRCsCfg.bundle.resources, expectedResources

      it "array of RC-specs can be an array of (registered) RC-names:", ->
        resultRCsCfg = blendConfigs [{resources:rcNames}]
        deepEqual resultRCsCfg.bundle.resources, expectedResources

      it "array of RC-names reversed results to reversed RC-instances:", ->
        reversedRCs = blendConfigs [{resources: _(rcNames).clone().reverse()}]
        deepEqual reversedRCs.bundle.resources, _(expectedResources).clone().reverse()

  describe "dependenciesBindingsBlender converts to proper dependenciesBinding structure:", ->

      it "converts undefined to an empty {}", ->
        deepEqual dependenciesBindingsBlender.blend(undefined), {}

      it "converts String: `'lodash'`  --->   `{lodash:[]}`", ->
        deepEqual dependenciesBindingsBlender.blend('lodash'), {lodash:[]}

      it "converts Strings, ignoring all other non {}, []: ", ->

        deepEqual dependenciesBindingsBlender.blend(
          {knockout:['ko']}, 'lodash', 'jquery', undefined, /./, 123, true, false, null
        ),
          knockout:['ko'], lodash:[], jquery:[]

      it "converts Array<String>: `['lodash', 'jquery']` ---> `{lodash:[], jquery:[]}`", ->
        deepEqual dependenciesBindingsBlender.blend(
          ['lodash', 'jquery']
        ),
          {lodash: [], jquery: []}

        deepEqual dependenciesBindingsBlender.blend(
          {lodash: '_', knockout:['ko']}, ['lodash', 'jquery']
        ),
          lodash: ['_'], knockout:['ko'], jquery: []

      it "converts Object {lodash:['_'], jquery: '$'}` = {lodash:['_'], jquery: ['$']}`", ->
        deepEqual dependenciesBindingsBlender.blend(
          lodash: ['_'] #as is
          jquery: '$'   #arrayized
        ),
          lodash:['_']
          jquery: ['$']

      it "blends {lodash:['_'], jquery: ['$']} <-- {knockout:['ko'], jquery: ['jQuery']}`", ->
        deepEqual dependenciesBindingsBlender.blend(
          {lodash:'_', jquery: ['jQuery', 'jquery']},
          {knockout:['ko', 'Knockout'], jquery: '$'}
        ),
          lodash: ['_']
          knockout: ['ko', 'Knockout']
          jquery: ['$', 'jQuery', 'jquery']

      it "converts from all in chain ", ->
        deepEqual dependenciesBindingsBlender.blend(
            {},
            'myLib',
            {lodash:['_'], jquery: 'jQuery'}
            ['uberscore', 'uderive']
            jquery: '$'
            'urequire'
            'uberscore': ['rules']
          ),
            myLib: []
            lodash: ['_']
            jquery: ['$', 'jQuery']
            uberscore: ['rules']
            uderive: []
            urequire: []


    describe "`blendConfigs`:", ->

      describe "`bundle: dependencies`:", ->

        it "imports String depBindings is turned to {dep:[]}", ->
          deepEqual blendConfigs(
            [ dependencies: exports: bundle: 'lodash' ]
          ),
              bundle: dependencies:
                imports: 'lodash': []
                exports: {} #todo: omit

        it "exports: bundle Array<String> depBindings is turned to {dep1:[], dep2:[]}", ->
          deepEqual blendConfigs(
            [ dependencies: exports: bundle: ['lodash', 'jquery']]
          ),
            bundle: dependencies:
              imports:
                'lodash': []
                'jquery': []
              exports: {} #todo: omit

        it "exports: bundle {} - depBindings is `arrayize`d", ->
          deepEqual blendConfigs(
            [ dependencies: exports: bundle: {'lodash': '_'} ]
          ),
            bundle: dependencies:
              imports: {'lodash': ['_']}
              exports: {} #todo: omit

        it "exports: bundle {} - depBinding reseting its array", ->
          deepEqual blendConfigs([
              {}
              {dependencies: exports: bundle: {'uberscore': [[null], '_B']}}
              {}
              {dependencies: exports: bundle: {'uberscore': ['uberscore', 'uuuuB']}}
            ]
          ),
            bundle: dependencies:
              imports: {'uberscore': ['_B']}
              exports: {} #todo: omit

      describe "`build: watch`:", ->

        describe "as a Number:", ->
          it "becomes debounceDelay", ->
            deepEqual blendConfigs( [ {build: watch: 123} ]),
              build: watch:
                debounceDelay: 123
                enabled: true

        describe "as a String:", ->
          it "parsed as a Number, becomes debounceDelay", ->
            deepEqual blendConfigs( [ {build: watch: '123'} ]),
              build: watch:
                debounceDelay: 123
                enabled: true

          it "parsed as a Number/String, overwrite debounceDelay", ->
            deepEqual blendConfigs( [ {build: watch: '123'}, {build: watch: 456} ]),
              build: watch:
                debounceDelay: 123
                enabled: true

          describe "not parsed as a Number:", ->
            it "becomes info", ->
              deepEqual blendConfigs( [ {build: watch: 'not number'} ]),
                build: watch:
                  info: 'not number'
                  enabled: true

            it "becomes info, blended into existing watch {}", ->
              deepEqual blendConfigs( [ {build: watch: '123'}, {build: watch: 'not number'} ]),
                build: watch:
                  debounceDelay: 123
                  info: 'not number'
                  enabled: true

        describe "as boolean:", ->
          it "overwrites enabled", ->
            deepEqual blendConfigs( [{ build: watch: false }]),
              build: watch:
                enabled: false

          it "overwrites enabled, keeps other keys", ->
            deepEqual blendConfigs( [{ build: watch: false }, {build: watch: '123'}, {build: watch: 'not number'}]),
              build: watch:
                enabled: false
                debounceDelay: 123
                info: 'not number'

        describe "as Object:", ->
          it "shallow copies / overwrites keys", ->
            anObj =
              rootKey: {
                some:nested:key:
                  someValue: 'someValue'
                  aFn: ->
              }

            deepEqual blendConfigs( [
                {build: watch: anObj},
                {build: watch: false },
                {build: watch: '123'},
                {build: watch: 'not number'}
              ]),
                build: watch:
                  rootKey: anObj.rootKey
                  enabled: false
                  debounceDelay: 123
                  info: 'not number'

      describe "Nested & derived configs:", ->
        configs = [
            {}
          ,
            dependencies:
              node: ['fs']
              exports: bundle: (parent)->
                parent.lodash = ["_"]
                parent.backbone = ['Backbone', 'BB']
                parent

            filez: (parentArray)-> #      [ '**/*.coffee.md', '**/*.ls']
              parentArray.push p for p in [ '**/*.coffee.md', '**/*.ls']
              parentArray
            copy: /./
            dstPath: "build/code"
            template: 'UMD'

            # test arraysConcatOrOverwrite
            useStrict: false
            globalWindow: ['globalWindow-child.js']
            bare: true
            runtimeInfo: ['runtimeInfo-child.js']
            done: ->
          ,
            bundle:
              path: "source/code"
              filez: ['**/*.litcoffee'] # added at pos 1
              copy: ['**/*.html']
              ignore: [/^draft/]        # negated with '!' and added at pos 2 & 3
              dependencies:
                node: 'util'
                paths: override:
                    lodash: ['bower_components/lodash/dist/lodash.compat.js'
                             'bower_components/lodash/dist/lodash.js'] # unshifted, not pushed!
                imports:
                  uberscore: [[null], '_B'] #reseting existing (derived/inherited) array, allowing only '_B'
                rootExports:
                  'index': 'globalVal'
            verbose: true
            afterBuild: ->
            derive:
              debugLevel: 90
          ,
            {}

          , # DEPRACATED keys
            bundlePath: "sourceSpecDir"
            main: 'index'
            filespecs: '**/*' # arrayized and added at pos 0
            resources: resources[2..]
            dependencies:
              variableNames:
                uberscore: '_B'

              bundleExports:
                chai: 'chai'
            build:
              noRootExports: ['some/module/path'] # renamed to `rootExports: ignore`
              rootExports: runtimes: ['script', 'AMD']
          ,
            dependencies: # `exports: bundle:` & `bundleExports:` can't appear together!
              exports: bundle:
                uberscore: ['uberscore', 'B', 'B_'] # reset above
                'spec-data': 'data'

            build:
              rootExports:
                ignore: ['some/other/module/path']  # preceding the above (deprecated) `noRootExports`
                runtimes: ['node']                  # overwritten above

            dstPath: "some/useless/default/path"
          ,
            {dependencies: bundleExports: ['backbone', 'unusedDep']}
          ,
            {dependencies: imports: 'dummyDep': 'dummyDepVar'}
          ,
            template: 'AMD'

            # test arraysConcatOrOverwrite
            useStrict: true
            globalWindow: [[null], 'globalWindow-inherited.js']
            bare: ['bare-inherited-and-ignored2.js']
            runtimeInfo: ['runtimeInfo-inherited.js']
          ,
            derive: [
              dependencies:
                exports: bundle:
                  'spec-data': ['dataInDerive1', 'dataInDerive1-1']
            ,
              derive:
                derive:
                  resources: resources[0..1]
                  derive:
                    copy: (pa)-> pa.push '!**/*'; pa
                    template:
                      name: 'combined'
                      someOption: 'someOption' # value is preserved, even if name changes.
              dependencies:
                exports: bundle: 'spec-data': 'dataInDerive2'
                paths: override:
                  lodash: 'node_modules/lodash/lodash.js'
              verbose: false

              # test arraysConcatOrOverwrite
              globalWindow: ['globalWindow-reseted.js']
              bare: ['bare-inherited-and-ignored.js']
              runtimeInfo: false
            ]
        ]

        configsClone = _.clone configs, true
        blended = blendConfigs configs

        it "blending doesn't mutate source configs:", ->
          deepEqual configs, configsClone

        it "correctly derives from many & nested user configs:", ->
          deepEqual blended,
            bundle:
              path: "source/code"
              main: "index"
              filez: [
                '**/*'            # comes from last config with filez
                '**/*.litcoffee'
                '!', /^draft/       # comes from DEPRACATED ignore: [/^draft/]
                '**/*.coffee.md'    # comes from first (highest precedence) config
                '**/*.ls'           # as above
              ]
              copy: ['!**/*', '**/*.html', /./]
              resources: expectedResources
              dependencies:
                paths:
                  override:
                    lodash: ['bower_components/lodash/dist/lodash.compat.js'
                             'bower_components/lodash/dist/lodash.js'
                             'node_modules/lodash/lodash.js']
                node: ['util', 'fs']

                rootExports:
                  'index': ['globalVal']
                imports:
                  'spec-data': ['data', 'dataInDerive1', 'dataInDerive1-1', 'dataInDerive2']
                  chai: ['chai']
                  uberscore: ['_B']
                  lodash: ['_']
                  backbone: ['Backbone', 'BB']
                  unusedDep: []
                  dummyDep: ['dummyDepVar']

                exports: {} #todo: omit

                depsVars:
                  uberscore: ['_B']

            build:
              verbose: true
              dstPath: "build/code"
              debugLevel: 90
              template:
                name: "UMD"
                someOption: 'someOption'

              rootExports:
                ignore: ['some/other/module/path', 'some/module/path']
                runtimes: ['script', 'AMD'] # overwrites ['node']

              # test arraysConcatOrOverwrite
              useStrict: false
              globalWindow: ['globalWindow-inherited.js', 'globalWindow-child.js']
              bare: true
              runtimeInfo: ['runtimeInfo-inherited.js', 'runtimeInfo-child.js']
              afterBuild: [configs[2].afterBuild, configs[1].done]

        it "all {} in bundle.resources are instanceof ResourceConverter :", ->
          for resConv in blended.bundle.resources
            ok resConv instanceof ResourceConverter

        it "`bundle.resources` are reset with [null] as 1st item", ->
          freshResources = blendConfigs [{resources:[ [null], expectedResources[0]]}, blended]
          blended.bundle.resources = [expectedResources[0]]
          deepEqual freshResources, blended