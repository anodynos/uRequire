chai = require 'chai'
assert = chai.assert
expect = chai.expect

_ = require 'lodash'

blendConfigs = require '../../code/config/blendConfigs'
uRequireConfigMasterDefaults = require '../../code/config/uRequireConfigMasterDefaults'
{
  moveKeysBlender
  renameKeysBlender
  resourcesBlender
  templateBlender
  arrayizeUniquePusher
  dependenciesBindingsBlender
  bundleBuildBlender
} = blendConfigs

resources =  [
  [
    'Coffeescript' # a title of the resource
    [
      '**/*.coffee'
      /.*\.(coffee\.md|litcoffee)$/i
      '!**/*.amd.coffee'
    ]
    (source)-> source
    (filename)-> filename.replace '.coffee', '.js' # dummy filename converter
  ]

  [
    'Streamline' # a title of the resource
    '**/*._*'
    (source)-> source
    (filename)-> filename.replace '._js', '.js' # dummy filename converter
  ]

  {
    name: '#NonModule' #a non-module (starting with '#')
    filez: '**/*.nonmodule'
    convert: ->
  }

  [
    '#*NonModule-NonTerminal resource' #a non-module & non-terminal (starting with '#' & '*')
    '**/*.ext'
    (source)-> source
  ]

  {
    name: '#IamAModule' #a module (although starting with '#')
    isModule: true      # this is respected over starting with '#'
    filez: '**/*.module'
    convert: ->
  }
]

expectedResources = [
  {
    name: 'Coffeescript'
    isModule: true
    isTerminal: true
    filez: [
       '**/*.coffee'
       /.*\.(coffee\.md|litcoffee)$/i
       '!**/*.amd.coffee'
     ]
    convert: resources[0][2]
    dstFilename: resources[0][3]
  }

  {
    name: 'Streamline'
    isModule: true
    isTerminal: true
    filez: '**/*._*'
    convert: resources[1][2]
    dstFilename: resources[1][3]
  }

  {
    name: 'NonModule'
    isModule: false
    isTerminal: true
    filez: '**/*.nonmodule'
    convert: resources[2].convert
    #dstFilename: undefined # not added as undefined in objs
  }

  {
    name: 'NonModule-NonTerminal resource'
    isModule: false
    isTerminal: false
    filez: '**/*.ext'
    convert: resources[3][2]
    dstFilename: resources[3][3]
  }

  {
    name: 'IamAModule'
    isModule: true
    isTerminal: true
    filez: '**/*.module'
    convert: resources[4].convert
  }

]

describe '`uRequireConfigMasterDefaults` consistency', ->
  it "No same name keys in bundle & build ", ->
    expect(_B.isDisjoint _.keys(uRequireConfigMasterDefaults.bundle),
                         _.keys(uRequireConfigMasterDefaults.build)
    ).to.be.true

describe 'blendConfigs & its Blenders', ->

  describe 'moveKeysBlender', ->
    it "Copies keys from the 'root' of src, to either `dst.bundle` or `dst.build`, depending on where they are on `uRequireConfigMasterDefaults`", ->
      expect(
        moveKeysBlender.blend(
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
        )
      ).to.deep.equal
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

  describe "renameKeysBlender:", ->
    it "renames DEPRACATED keys to their new name", ->

      oldCfg =
        bundle:
          bundlePath: "source/code"
          main: "index"
          filespecs: '*.*'
          ignore: [/^draft/] # ignore not handled in renameKeysBlender
          dependencies:
            bundleExports: {lodash:'_'}
            _knownVariableNames: {jquery:'$'}

      expect(renameKeysBlender.blend oldCfg).to.be.deep.equal
        bundle:
          path: 'source/code'
          main: 'index'
          filez: '*.*',
          ignore: [ /^draft/ ]
          dependencies:
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

  describe "resourcesBlender:", ->
    it "converts array of array resources into array of object resources", ->
      expect(resourcesBlender.blend resources).to.deep.equal expectedResources

  describe "arrayizeUniquePusher:", ->
    it "pushes source array items into destination array", ->
      expect(
        arrayizeUniquePusher.blend [1, 2, 3], [4, 5, 6, '7']
      ).to.deep.equal [1, 2, 3, 4, 5, 6, '7']

    it "pushes only === unique items", ->
      expect(
        arrayizeUniquePusher.blend [1, 4, 2, 3], [1, 2, 4, 5, 6, '7']
      ).to.deep.equal [1, 4, 2, 3, 5, 6, '7']

    it "pushes source array items into non-array destination, arrayize'ing it first", ->
      expect(
        arrayizeUniquePusher.blend 123, [4, 5, 6]
      ).to.deep.equal [123, 4, 5, 6]

    it "pushes source non-array (but a String) item into array destination", ->
      expect(
        arrayizeUniquePusher.blend ['1', '2', '3'], '456'
      ).to.deep.equal ['1', '2', '3', '456']

    it "pushes non-array (but Strings) items onto each other", ->
      expect(
        arrayizeUniquePusher.blend '123', '456'
      ).to.deep.equal ['123', '456']

    it "resets destination array & then pushes - using signpost `[null]` as 1st src item", ->
      expect(
        arrayizeUniquePusher.blend ['items', 'to', 'remove'], [[null], 11, 22, 33]
      ).to.deep.equal [11, 22, 33]

  describe """
           `dependenciesBindingsBlender` converts to proper dependenciesBinding structure
           {dependency1:ArrayOfDep1Bindings, dependency2:ArrayOfDep2Bindings, ...}
           i.e `{lodash:['_'], jquery: ['$']}` :
  """, ->
    it "converts String: `'lodash'`  --->   `{lodash:[]}`", ->
      expect(
        dependenciesBindingsBlender.blend 'lodash'
      ).to.deep.equal {lodash:[]}


    it "converts Array<String>: `['lodash', 'jquery']` ---> `{lodash:[], jquery:[]}`", ->
      expect(
        dependenciesBindingsBlender.blend ['lodash', 'jquery']
      ).to.deep.equal {lodash: [], jquery: []}


    it "converts Object {lodash:['_'], jquery: '$'}` ---> {lodash:['_'], jquery: ['$']}`", ->
      expect(
        dependenciesBindingsBlender.blend
          lodash: ['_'] #as is
          jquery: '$'   #arrayized
      ).to.deep.equal
        lodash:['_']
        jquery: ['$']

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
      it "noWeb is `arrayize`d", ->
        expect(
          blendConfigs [ dependencies: noWeb: 'noWebForMe' ]
        ).to.deep.equal
          bundle: dependencies: noWeb: ['noWebForMe']

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
            exports: bundle:
              lodash: "_"

          dstPath: "build/code"
          template: 'UMD'
        ,
          bundle:
            path: "source/code"
            ignore: [/^draft/]
            dependencies:
              exports: bundle:
                uberscore: [[null], '_B'] #reseting existing (derived/inherited) array, allowing only '_B'
              noWeb: "noWebForMe"

          verbose: true

          derive:
            debugLevel: 90
        ,
          {}
        , # DEPRACATED keys
          bundlePath: "sourceSpecDir"
          main: 'index'
          resources: resources[2..]
          dependencies:
            variableNames:
              uberscore: '_B'

            bundleExports:
              chai: 'chai'
              uberscore: ['uberscore', 'B', 'B_']
              'spec-data': 'data'

          dstPath: "some/useless/default/path"
        ,
          {}
        ,
          derive: [
              dependencies:
                noWeb: "noWebInDerive1"
                exports: bundle: 'spec-data': 'dataInDerive1'
            ,
              derive:
                derive:
                  resources: resources[0..1]
                  derive:
                    template:
                      name: 'combined'
                      dummyOption: 'dummy'
              dependencies:
                noWeb: "noWebInDerive2"
                exports: bundle: 'spec-data': 'dataInDerive2'
              verbose: false
          ]
      ]

      configsClone = _.clone configs, true
      blended = blendConfigs(configs)

      it "blending doesn't mutate source configs:", ->
        expect(configs).to.deep.equal configsClone

      it "correctly derives from many & nested user configs:", ->
        expect(blended).to.be.deep.equal
          bundle:
            path: "source/code"
            main: "index"
            filez: ['**/*.*', '!', /^draft/] # from DEPRACATED ignore: [/^draft/]
            resources: expectedResources
            dependencies:
              noWeb: ['noWebInDerive2', 'noWebInDerive1', 'noWebForMe']
              exports: bundle:
                'spec-data': ['dataInDerive2', 'dataInDerive1', 'data' ]
                chai: ['chai']
                uberscore: ['_B']
                lodash: ['_']
              depsVars:
                uberscore: ['_B']
          build:
            verbose: true
            dstPath: "build/code"
            debugLevel: 90
            template: name: "UMD"