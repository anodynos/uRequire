
chai = require 'chai'
assert = chai.assert
expect = chai.expect

_ = require 'lodash'

### FAKE mocha/chai style tests START###
#if not chai?
#  #todo: (3 4 2) Find a way to run real specs with 'run', no full build!
#  errorCount = 0; hasError = false; level = 0; indent = ->("   " for i in [0..level]).join('')
#  describe = (msg, fn)->
#    l.verbose indent() + msg;
#    level++; fn(msg); level--
#    if errorCount and level is 0
#      l.warn 'Error count:' + errorCount
#
#  it = (msg, expectedFn)->
#    hasError = false; expectedFn();
#    if hasError
#      errorCount++
#      l.warn(indent() + msg + ' - false')
#    else
#      l.ok(indent() + msg + ' - OK')
#  expect = (v)-> hasError = true if not v
#  ### fake mocha/chai style tests ###
#
#  _ = require 'lodash'
#  _B  = require 'uberscore'
#  l = new _B.Logger 'BlenderDRAFT'
#### FAKE mocha/chai style tests END###

blendConfigs = require '../../code/config/blendConfigs'
uRequireConfigMasterDefaults = require '../../code/config/uRequireConfigMasterDefaults'
{moveKeysBlender, arrayPusher, dependenciesBindingsBlender, bundleBlender} = blendConfigs

describe 'moveKeysBlender', ->
  it "Copies keys from the 'root' of src, to either `dst.bundle` or `dst.build`, depending on where they are on `uRequireConfigMasterDefaults`", ->
    expect _.isEqual(
      moveKeysBlender.blend(
        bundleName: 'myBundle'
        main: 'myLib'
        bundle: # root items have precedence over 'bundle' and 'build' hashes.
          main: 'myMainLib'
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
      ),
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
    )

  it "it gives precedence to root items over items in 'bundle' and 'build' hashes.", ->
    expect _.isEqual(
      moveKeysBlender.blend(
        main: 'myLib'
        bundle: # root items have precedence over 'bundle' and 'build' hashes.
          main: 'myMainLib'

        outputPath: "/some/path"
        build: # root items have precedence over 'bundle' and 'build' hashes.
          outputPath: "/some/OTHER/path"
      ),
        bundle:
          main: 'myLib'
        build:
          outputPath: "/some/path"
    )

  it "ignores root keys deemed irrelevant (those not existing on on `uRequireConfigMasterDefaults`'s `build` or `bundle`.)", ->
    expect _.isEqual(
      moveKeysBlender.blend(
        iRReLeVaNt_key_is_Ignored: true
        bundleName: 'myBundle'
        bundle: # root items have precedence over 'bundle' and 'build' hashes.
          bundle_iRReLeVaNt_key_is_NOT_Ignored: true
          bundlePath: "/some/path"

      ),
        bundle:
          bundle_iRReLeVaNt_key_is_NOT_Ignored: true
          bundleName: 'myBundle'
          bundlePath: "/some/path"
    )

describe "arrayPusher:", ->
  it "pushes source array items into destination array", ->
    expect _.isEqual(
      arrayPusher.blend([1, 2, 3], [4, 5, 6, '7']),
      [1, 2, 3, 4, 5, 6, '7']
    )

  it "pushes only === unique items", ->
    expect _.isEqual(
      arrayPusher.blend([1, 4, 2, 3], [1, 2, 4, 5, 6, '7']),
      [1, 4, 2, 3, 5, 6, '7']
    )

  it "pushes source array items into non-array destination, arrayize'ing it first", ->
    expect _.isEqual(
      arrayPusher.blend(123, [4, 5, 6]),
      [123, 4, 5, 6]
    )

  it "pushes source non-array (but a String) item into array destination", ->
    expect _.isEqual(
      arrayPusher.blend(['1', '2', '3'], '456'),
      ['1', '2', '3', '456']
    )

  it "pushes non-array (but Strings) items onto each other", ->
    expect _.isEqual(
      arrayPusher.blend('123', '456'),
      ['123', '456']
    )

  it "resets destination array, using signpost [null] as first item of src", ->
    expect _.isEqual(
      arrayPusher.blend([1, 4, 2, 3], [[null], 11, 22, 33]),
      [11, 22, 33]
    )



describe """`dependenciesBindingsBlender` converts to proper dependenciesBinding structure
                {dependency1:ArrayOfDep1Bindings, dependency2:ArrayOfDep2Bindings, ...}
                i.e `{lodash:['_'], jquery: ['$']}`
            :
         """, ->
  it "converts String: `'lodash'`  --->   `{lodash:[]}`", ->
    expect _.isEqual(
      dependenciesBindingsBlender.blend('lodash'),
      {lodash:[]}
    )

  it "converts Array<String>: `['lodash', 'jquery']` ---> `{lodash:[], jquery:[]}`", ->
    expect _.isEqual(
      dependenciesBindingsBlender.blend(
      ['lodash', 'jquery']),
      {lodash:[], jquery:[]}
    )

  it "converts Object {lodash:['_'], jquery: '$'}` ---> {lodash:['_'], jquery: ['$']}`", ->
    expect _.isEqual(
      dependenciesBindingsBlender.blend(
      {lodash:['_'], jquery: '$'}),
      {lodash:['_'], jquery: ['$']}
    )

  it "converts from all in chain ", ->
    expect _.isEqual(
      dependenciesBindingsBlender.blend(
        {},
        'myLib',
        {lodash:['_'], jquery: '$'}
        ['uberscore', 'uderive']
        jquery: 'jQuery'
        'urequire'
      ),
        myLib: []
        lodash: ['_']
        jquery: ['$', 'jQuery']
        uberscore: []
        uderive: []
        urequire: []
    )
#
describe """`blendConfigs` correctly derives user configs:""", ->
  it "works....", ->
    expect _.isEqual(
      blendConfigs(
        [
          dependencies:            # must move to bundle
            bundleExports:
              lodash: "_"

          outputPath: "build/code" # must move to build
        ,
          bundle:
            bundlePath: "source/code"
            ignore: [/^draft/]
            dependencies:
              bundleExports:
                uberscore: ['uberscore', 'B', 'B_']
              noWeb: ["util"]

          verbose: false                      # must move to build

          derive:
            debugLevel: 90                      # must load derive & move to build
        ,
          bundlePath: "sourceSpecDir"         # must move to bundle
          main: 'index'                       # must move to bundle
          dependencies:                       # must move to bundle
            variableNames:
              uberscore: '_B'

            bundleExports:
              chai: 'chai'
              uberscore: [[null], '_B'] #reseting existing array, pushing only '_B'
              'spec-data': 'data'
          outputPath: "some/useless/default/path"  # must not overwrite, ignored
          template: 'UMD'

          derive:
            dependencies: bundleExports: 'spec-data': 'data2'
        ]
      ),
        bundle:
          bundlePath: "source/code"
          main: 'index'
          ignore: [/^draft/]
          dependencies:
            variableNames:
              uberscore: ['_B']

            bundleExports:
              lodash: ["_"]
              chai: ['chai']
              uberscore: ['_B']
              'spec-data': ['data', 'data2']
            noWeb: ["util"]

        build:
          outputPath: "build/code"
          verbose: false
          debugLevel: 90
          template: 'UMD'
    )