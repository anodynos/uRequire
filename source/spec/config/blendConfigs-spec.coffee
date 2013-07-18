chai = require 'chai'
assert = chai.assert
expect = chai.expect

_B = require 'uberscore'
l = new _B.Logger 'urequire/blendConfigs-spec'

_ = require 'lodash'

blendConfigs = require '../../code/config/blendConfigs'
uRequireConfigMasterDefaults = require '../../code/config/uRequireConfigMasterDefaults'
{
  moveKeysBlender
  depracatedKeysBlender
  templateBlender
  dependenciesBindingsBlender
  bundleBuildBlender
} = blendConfigs

arrayizePushBlender = new _B.ArrayizePushBlender

resourceConverterBlender = (require '../../code/config/resourceConverters').resourceConverterBlender

resources =  [
  [
    '$Coffeescript' # a title of the resource (a module since its not starting with #)
    [
      '**/*.coffee'
      /.*\.(coffee\.md|litcoffee)$/i
      '!**/*.amd.coffee'
    ]
    (source)-> source
    (filename)-> filename.replace '.coffee', '.js' # dummy filename converter
  ]

  [
    '!Streamline' # a title of the resource (without type since its not in [@ # $], but with isAfterTemplate:true due to '!' (runs only on Modules)
    'I am the Streamline description' # a description (String) at pos 1
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
    '@~FileResource' #a FileResource (@) isMatchSrcFilename:true (~)
    '**/*.ext'       # this is a `filez`, not a description if pos 1 isString & pos 2 not a String|Array|RegExp
    (source)-> source
  ]

  {
    name: '#IamAModule' # A TextResource (starting with '#')
    type: 'module'      # this is NOT respected cause its starting with '#'
    filez: '**/*.module'
    convert: ->
  }
]

expectedResources = [
  {
    name: 'Coffeescript'
    description: undefined
    filez: [
       '**/*.coffee'
       /.*\.(coffee\.md|litcoffee)$/i
       '!**/*.amd.coffee'
     ]
    isMatchSrcFilename: false
    convert: resources[0][2]
    convFilename: resources[0][3]
    type: 'module'
    isTerminal: false
    isAfterTemplate: false
  }

  {
    name: 'Streamline'
    description: 'I am the Streamline description'
    filez: '**/*._*'
    isMatchSrcFilename: false
    convert: resources[1][3]
    convFilename: resources[1][4]
    type: undefined
    isTerminal: false
    isAfterTemplate: true
  }

  {
    name: 'NonModule'
    description: undefined
    filez: '**/*.nonmodule'
    isMatchSrcFilename: false
    convert: resources[2].convert
    convFilename: undefined
    type: 'text'
    isTerminal: true
    isAfterTemplate: false
  }

  {
    name: 'FileResource'
    description: undefined
    filez: '**/*.ext'
    isMatchSrcFilename:true
    convert: resources[3][2]
    convFilename: resources[3][3]
    type: 'file'
    isTerminal: false
    isAfterTemplate: false
  }

  {
    name: 'IamAModule'
    description: undefined
    filez: '**/*.module'
    convert: resources[4].convert
    convFilename: undefined
    type: 'text'
    isTerminal: false
    isAfterTemplate: false
    isMatchSrcFilename: false
  }
]

describe '`uRequireConfigMasterDefaults` consistency', ->
  it "No same name keys in bundle & build ", ->
    expect(
      _B.isDisjoint _.keys(uRequireConfigMasterDefaults.bundle),
                    _.keys(uRequireConfigMasterDefaults.build)
    ).to.be.true

describe 'blendConfigs & its Blenders: ', ->

  describe 'moveKeysBlender:', ->
    it "Copies keys from the 'root' of src, to either `dst.bundle` or `dst.build`, depending on where they are on `uRequireConfigMasterDefaults`", ->
      rootLevelKeys =
          name: 'myBundle'
          main: 'myMainLib'
          bundle: # 'bundle' and 'build' hashes have precedence over root items
            main: 'myLib'
          path: "/some/path"
          webRootMap: "."
          dependencies:
            depsVars: {}
            exports: bundle: {}

          dstPath: ""
          forceOverwriteSources: false
          template: name: "UMD"
          watch: false
          noRootExports: false
          scanAllow: false
          allNodeRequires: false
          verbose: false
          debugLevel: 0
          done:->

      expected = moveKeysBlender.blend rootLevelKeys
      expect(expected).to.deep.equal
          bundle:
            name: 'myBundle'
            main: 'myLib'
            path: "/some/path"
            webRootMap: "."
            dependencies:
              depsVars: {}
              exports: bundle: {}

          build:
            dstPath: ""
            forceOverwriteSources: false
            template: name: "UMD"
            watch: false
            noRootExports: false
            scanAllow: false
            allNodeRequires: false
            verbose: false
            debugLevel: 0
            done: rootLevelKeys.done


    it "it gives precedence to items in 'bundle' and 'build' hashes, over root items.", ->
      expect(
        moveKeysBlender.blend(
          main: 'myMainLib'
          bundle: # 'bundle' and 'build' hashes have precedence over root items
            main: 'myLib'

          dstPath: "/some/OTHER/path"
          build: # 'bundle' and 'build' hashes have precedence over root items
            dstPath: "/some/path"
        )
      ).to.deep.equal
          bundle:
            main: 'myLib'
          build:
            dstPath: "/some/path"

    it "ignores root keys deemed irrelevant (not exist on `uRequireConfigMasterDefaults`'s `.build` or `.bundle`.)", ->
      expect(
        moveKeysBlender.blend(
          iRReLeVaNt_key_is_Ignored: true
          name: 'myBundle'
          bundle: # root items have precedence over 'bundle' and 'build' hashes.
            bundle_iRReLeVaNt_key_is_NOT_Ignored: true
            path: "/some/path"

        )
      ).to.deep.equal
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

      expect(depracatedKeysBlender.blend oldCfg).to.be.deep.equal
        bundle:
          path: 'source/code'
          main: 'index'
          filez: '*.*',
          ignore: [ /^draft/ ]
          dependencies:
            node: 'util'
            exports: bundle: { lodash: '_' }
            _knownDepsVars: { jquery: '$'}


  describe "templateBlender:", ->
    describe "template is a String:", ->

      it "converts to {name:'TheString'} ", ->
        expect(templateBlender.blend 'UMD').to.deep.equal {name: 'UMD'}

      it "converts & blends to {name:'TheString'} ", ->
        expect(
          templateBlender.blend(
            {} # useless
            {name:'UMD', otherRandomOption: 'someRandomValue'}
            {}
            'UMD'
          )
        ).to.deep.equal
          name: 'UMD'
          otherRandomOption: 'someRandomValue'

      it "resets dest Object if src name is changed", ->
        expect(
          templateBlender.blend(
            {}
            {name: 'UMD', otherRandomOption: 'someRandomValue'}
            {}
            'combined'
          )
        ).to.deep.equal name: 'combined'

    describe "template is {}:", ->
      it "blends to existing ", ->
        expect(
          templateBlender.blend(
            {}
            {name: 'UMD', otherRandomOption: 'someRandomValue'}
            {}
            {name: 'UMD'}
          )
        ).to.deep.equal {name: 'UMD', otherRandomOption: 'someRandomValue'}

      it "resets dest Object if template.name is changed", ->
        expect(
          templateBlender.blend(
            {}
            {name: 'UMD', otherRandomOption: 'someRandomValue'}
            {}
            {name: 'combined'}
          )
        ).to.deep.equal {name: 'combined'}

  describe "resourceConverterBlender:", ->
    it "converts array of array resources into array of object resources", ->
      result = []
      result.push(resourceConverterBlender.blend resource) for resource in resources
      expect(result).to.deep.equal expectedResources

  describe """
           `dependenciesBindingsBlender` converts to proper dependenciesBinding structure
           {dependency1:ArrayOfDep1Bindings, dependency2:ArrayOfDep2Bindings, ...}
           i.e `{lodash:['_'], jquery: ['$']}` :
  """, ->
    it "converts String: `'lodash'`  --->   `{lodash:[]}`", ->
      expect(
        dependenciesBindingsBlender.blend 'lodash'
      ).to.deep.equal {lodash:[]}

      expect(
        dependenciesBindingsBlender.blend undefined, 'lodash', 'jquery'
      ).to.deep.equal {lodash:[], jquery:[]}

      expect(
        dependenciesBindingsBlender.blend {knockout:['ko']}, 'lodash', 'jquery'
      ).to.deep.equal {knockout:['ko'], lodash:[], jquery:[]}



    it "converts Array<String>: `['lodash', 'jquery']` ---> `{lodash:[], jquery:[]}`", ->
      expect(
        dependenciesBindingsBlender.blend ['lodash', 'jquery']
      ).to.deep.equal {lodash: [], jquery: []}

      expect(
        dependenciesBindingsBlender.blend {lodash: '_', knockout:['ko']}, ['lodash', 'jquery']
      ).to.deep.equal {lodash: ['_'], knockout:['ko'], jquery: []}


    it "converts Object {lodash:['_'], jquery: '$'}` = {lodash:['_'], jquery: ['$']}`", ->
      expect(
        dependenciesBindingsBlender.blend
          lodash: ['_'] #as is
          jquery: '$'   #arrayized
      ).to.deep.equal
        lodash:['_']
        jquery: ['$']

    it "blends {lodash:['_'], jquery: ['$']} <-- {knockout:['ko'], jquery: ['jQuery']}`", ->
      expect(
        dependenciesBindingsBlender.blend {lodash:'_', jquery: ['$', 'jquery']},
                                          {knockout:['ko', 'Knockout'], jquery: 'jQuery'}
      ).to.deep.equal {
        lodash: ['_']
        knockout: ['ko', 'Knockout']
        jquery: ['$', 'jquery', 'jQuery']
      }

    it "converts from all in chain ", ->
      expect(
        dependenciesBindingsBlender.blend(
          {},
          'myLib',
          {lodash:['_'], jquery: '$'}
          ['uberscore', 'uderive']
          jquery: 'jQuery'
          'urequire'
          'uberscore': ['rules']
        )
      ).to.deep.equal
          myLib: []
          lodash: ['_']
          jquery: ['$', 'jQuery']
          uberscore: ['rules']
          uderive: []
          urequire: []


  describe "`blendConfigs`:", ->

    describe "`bundle: dependencies`:", ->

      it "exports.bundle String depBindings is turned to {dep:[]}", ->
        expect(
          blendConfigs [ dependencies: exports: bundle: 'lodash']
        ).to.deep.equal
          bundle: dependencies: exports: bundle: 'lodash': []

      it "exports: bundle Array<String> depBindings is turned to {dep1:[], dep2:[]}", ->
        expect(
          a = blendConfigs [ dependencies: exports: bundle: ['lodash', 'jquery']]
        ).to.deep.equal
          bundle: dependencies: exports: bundle:
            'lodash': []
            'jquery': []


      it "exports: bundle {} - depBindings is `arrayize`d", ->
        expect(
          a = blendConfigs [ dependencies: exports: bundle: {'lodash': '_'} ]
        ).to.deep.equal
          bundle: dependencies: exports: bundle: {'lodash': ['_']}


      it "exports: bundle {} - depBinding reseting its array", ->
        expect(
          blendConfigs [
            {}
            {dependencies: exports: bundle: {'uberscore': [[null], '_B']}}
            {}
            {dependencies: exports: bundle: {'uberscore': ['uberscore', 'uuuuB']}}
          ]
        ).to.deep.equal
          bundle: dependencies: exports: bundle: {'uberscore': ['_B']}

    describe "Nested & derived configs:", ->
      configs = [
          {}
        ,
          dependencies:
            node: ['fs']
            exports: bundle:
              lodash: "_"
              backbone: ['Backbone', 'BB']
          filez: [
            '**/*.coffee.md'
            '**/*.ls'
          ]
          copy: /./
          dstPath: "build/code"
          template: 'UMD'
        ,
          bundle:
            path: "source/code"
            filez: ['**/*.litcoffee'] # added at pos 1
            copy: ['**/*.html']
            ignore: [/^draft/]        # negated with '!' and added at pos 2 & 3
            dependencies:
              node: 'util'
              exports: bundle:
                uberscore: [[null], '_B'] #reseting existing (derived/inherited) array, allowing only '_B'

          verbose: true

          derive:
            debugLevel: 90
        ,
          {}
        , # DEPRACATED keys
          bundlePath: "sourceSpecDir"
          main: 'index'
          filez: '**/*.*' # arrayized and added at pos 0
          resources: resources[2..]
          dependencies:
            variableNames:
              uberscore: '_B'

            bundleExports:
              chai: 'chai'
              uberscore: ['uberscore', 'B', 'B_'] # reset above
              'spec-data': 'data'

          dstPath: "some/useless/default/path"
        ,
          {dependencies:bundleExports: ['backbone', 'unusedDep']}
        ,
          {dependencies:bundleExports: 'dummyDep'}
        ,
          {}
        ,
          derive: [
              dependencies:
                exports: bundle: 'spec-data': 'dataInDerive1'
            ,
              derive:
                derive:
                  resources: resources[0..1]
                  derive:
                    copy: ['!**/*.*']
                    template:
                      name: 'combined'
                      dummyOption: 'dummy'
              dependencies:
                exports: bundle: 'spec-data': 'dataInDerive2'
              verbose: false
          ]
      ]

      configsClone = _.clone configs, true
      blended = blendConfigs(configs)
      l.log blended
      it "blending doesn't mutate source configs:", ->
        expect(configs).to.deep.equal configsClone

      it "correctly derives from many & nested user configs:", ->
        expect(blended).to.be.deep.equal
          bundle:
            path: "source/code"
            main: "index"
            filez: [
              '**/*.*'            # comes from last config with filez
              '**/*.litcoffee'
              '!', /^draft/       # comes from DEPRACATED ignore: [/^draft/]
              '**/*.coffee.md'    # comes from first (highest precedence) config
              '**/*.ls'           # as above
            ]
            copy: ['!**/*.*', '**/*.html', /./]
            resources: expectedResources
            dependencies:
              node: ['util', 'fs']
              exports: bundle:
                'spec-data': ['dataInDerive2', 'dataInDerive1', 'data' ]
                chai: ['chai']
                uberscore: ['_B']
                lodash: ['_']
                backbone: ['Backbone', 'BB']
                unusedDep: []
                dummyDep: []
              depsVars:
                uberscore: ['_B']

          build:
            verbose: true
            dstPath: "build/code"
            debugLevel: 90
            template: name: "UMD"