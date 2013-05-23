chai = require 'chai'
assert = chai.assert
expect = chai.expect

_ = require 'lodash'

blendConfigs = require '../../code/config/blendConfigs'
uRequireConfigMasterDefaults = require '../../code/config/uRequireConfigMasterDefaults'
{moveKeysBlender, templateBlender, arrayizeUniquePusher, dependenciesBindingsBlender, bundleBuildBlender} = blendConfigs

describe 'blendConfigs & its Blenders', ->
  describe 'moveKeysBlender', ->
    it "Copies keys from the 'root' of src, to either `dst.bundle` or `dst.build`, depending on where they are on `uRequireConfigMasterDefaults`", ->
      expect(
        moveKeysBlender.blend(
          bundleName: 'myBundle'
          main: 'myMainLib'
          bundle: # 'bundle' and 'build' hashes have precedence over root items
            main: 'myLib'
          bundlePath: "/some/path"
          webRootMap: "."
          dependencies:
            variableNames: {}
            bundleExports: {}

          outputPath: ""
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
            bundleName: 'myBundle'
            main: 'myLib'
            bundlePath: "/some/path"
            webRootMap: "."
            dependencies:
              variableNames: {}
              bundleExports: {}

          build:
            outputPath: ""
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

          outputPath: "/some/OTHER/path"
          build: # 'bundle' and 'build' hashes have precedence over root items
            outputPath: "/some/path"
        )
      ).to.deep.equal
          bundle:
            main: 'myLib'
          build:
            outputPath: "/some/path"

    it "ignores root keys deemed irrelevant (not exist on `uRequireConfigMasterDefaults`'s `.build` or `.bundle`.)", ->
      expect(
        moveKeysBlender.blend(
          iRReLeVaNt_key_is_Ignored: true
          bundleName: 'myBundle'
          bundle: # root items have precedence over 'bundle' and 'build' hashes.
            bundle_iRReLeVaNt_key_is_NOT_Ignored: true
            bundlePath: "/some/path"

        )
      ).to.deep.equal
          bundle:
            bundle_iRReLeVaNt_key_is_NOT_Ignored: true
            bundleName: 'myBundle'
            bundlePath: "/some/path"

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
        ) .to.deep.equal name: 'combined'

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

      it "bundleExports String depBindings is turned to {dep:[]}", ->
        expect(
          blendConfigs [ dependencies: bundleExports: 'lodash']
        ).to.deep.equal
          bundle: dependencies: bundleExports: 'lodash': []

      it "bundleExports Array<String> depBindings is turned to {dep1:[], dep2:[]}", ->
        expect(
          a = blendConfigs [ dependencies: bundleExports: ['lodash', 'jquery']]
        ).to.deep.equal
          bundle: dependencies: bundleExports:
            'lodash': []
            'jquery': []


      it "bundleExports {} - depBindings is `arrayize`d", ->
        expect(
          a = blendConfigs [ dependencies: bundleExports: {'lodash': '_'} ]
        ).to.deep.equal
          bundle: dependencies: bundleExports: {'lodash': ['_']}


      it "bundleExports {} - depBinding reseting its array", ->
        expect(
          blendConfigs [
            {}
            {dependencies: bundleExports: {'uberscore': [[null], '_B']}}
            {}
            {dependencies: bundleExports: {'uberscore': ['uberscore', 'uuuuB']}}
          ]
        ).to.deep.equal
          bundle: dependencies: bundleExports: {'uberscore': ['_B']}

    describe "Nested & derived configs:", ->
      configs = [
          {}
        ,
          dependencies:
            bundleExports:
              lodash: "_"

          outputPath: "build/code"
          template: 'UMD'
        ,
          bundle:
            bundlePath: "source/code"
            ignore: [/^draft/]
            dependencies:
              bundleExports:
                uberscore: [[null], '_B'] #reseting existing (derived/inherited) array, allowing only '_B'
              noWeb: "noWebForMe"

          verbose: true

          derive:
            debugLevel: 90
        ,
          {}
        ,
          bundlePath: "sourceSpecDir"
          main: 'index'
          dependencies:
            variableNames:
              uberscore: '_B'

            bundleExports:
              chai: 'chai'
              uberscore: ['uberscore', 'B', 'B_']
              'spec-data': 'data'
          outputPath: "some/useless/default/path"
        ,
          {}
        ,
          derive: [
              dependencies:
                noWeb: "noWebInDerive1"
                bundleExports: 'spec-data': 'dataInDerive1'
            ,
              derive:
                derive:
                  template:
                    name: 'combined'
                    dummyOption: 'dummy'
              dependencies:
                noWeb: "noWebInDerive2"
                bundleExports: 'spec-data': 'dataInDerive2'
              verbose: false
          ]
      ]

      configsClone = _.clone configs, true
      blended = blendConfigs(configs)

      it "bledning doesn't mutate source configs:", ->
        expect(configs).to.deep.equal configsClone

      it "correctly derives from many & nested user configs:", ->
        expect(blended).to.deep.equal
          bundle:
            bundlePath: "source/code"
            main: "index"
            ignore: [/^draft/]
            dependencies:
              noWeb: ['noWebInDerive2', 'noWebInDerive1', 'noWebForMe']
              bundleExports:
                'spec-data': ['dataInDerive2', 'dataInDerive1', 'data' ]
                chai: ['chai']
                uberscore: ['_B']
                lodash: ['_']
              variableNames:
                uberscore: ['_B']
          build:
            verbose: true
            outputPath: "build/code"
            debugLevel: 90
            template: name: "UMD"