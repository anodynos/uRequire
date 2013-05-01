if chai?
  assert = chai.assert
  expect = chai.expect

### FAKE mocha/chai style tests START###
if not chai?
  #todo: (3 4 2) Find a way to run real specs with 'run', no full build!
  errorCount = 0; hasError = false; level = 0; indent = ->("   " for i in [0..level]).join('')
  describe = (msg, fn)->
    l.verbose indent() + msg;
    level++; fn(msg); level--
    if errorCount and level is 0
      l.warn 'Error count:' + errorCount

  it = (msg, expectedFn)->
    hasError = false; expectedFn();
    if hasError
      errorCount++
      l.warn(indent() + msg + ' - false')
    else
      l.ok(indent() + msg + ' - OK')
  expect = (v)-> hasError = true if not v
  ### fake mocha/chai style tests ###

  _ = require 'lodash'
  _B  = require 'uberscore'
  l = new _B.Logger 'BlenderDRAFT'
#### FAKE mocha/chai style tests END###

_ = require 'lodash'
blendConfigs = require '../../code/config/blendConfigs'
uRequireConfigMasterDefaults = require '../../code/config/uRequireConfigMasterDefaults'


describe 'bundle: dependencies: bundleExports variables', ->
  cfg1 = bundle: dependencies: bundleExports: 'dep0AsString'
  cfg2 = bundle: dependencies: bundleExports: ['dep1inArray<String>', 'dep2inArray<String>']
  cfg3 = bundle: dependencies: bundleExports:
    'dep0AsString' : 'dep0 binding1 as String'
    'dep3AsKey': 'dep3 binding1 as String',
    'dep4AsKey': ['dep4 binding1 as Array<String>', 'dep4 binding2 as Array<String>', 'dep4 binding1 as String']

  cfg4 = bundle: dependencies: bundleExports:
    'dep0AsString' : ['dep0 binding2 as Array<String>', 'dep0 binding1 as String']
    'dep3AsKey': ['dep3 binding2 as Array<String>', 'dep3 binding3 as Array<String>', 'dep3 binding1 as String', 'dep3 binding4 as Array<String>']
    'dep4AsKey': 'dep4 binding1 as String'

#  it 'just works', ->
#
#    result = bundleBlender.blend {}, cfg1, cfg2, cfg3, cfg4
#
#    expect _.isEqual result, {
#      bundle: dependencies: bundleExports:
#        dep0AsString: ["dep0 binding1 as String", "dep0 binding2 as Array<String>"]
#        "dep1inArray<String>": []
#        "dep2inArray<String>": []
#        dep3AsKey: ["dep3 binding1 as String", "dep3 binding2 as Array<String>", "dep3 binding3 as Array<String>", "dep3 binding4 as Array<String>"]
#        dep4AsKey: ["dep4 binding1 as Array<String>", "dep4 binding2 as Array<String>", "dep4 binding1 as String"]
#    }


  it 'reseting an array', ->
    cfgResetArray = bundle: dependencies: bundleExports:
      'dep3AsKey': [[null], 'dep3 only binding, after reset']

#    result = bundleBlender.blend {}, cfg4, cfgResetArray
#
#    expect _.isEqual result, {
#      bundle: dependencies: bundleExports:
#        'dep0AsString' : ['dep0 binding2 as Array<String>', 'dep0 binding1 as String']
#        'dep3AsKey': ['dep3 only binding, after reset']
#        'dep4AsKey': ['dep4 binding1 as String']
#    }

    aConf =
        bundlePath: "sourceSpecDir"
        main: 'index' # not needed:
                      # if `bundle.main` is undefined,
                      #   it defaults to `bundle.bundleName` or 'index' or 'main'
                      #   with the price of a warning!
        dependencies:
          variableNames: uberscore: '_B'#, 'uberscore']
          bundleExports: # '<%= options.urequire.spec.dependencies.bundleExports %>' #@todo: why not working ? Missing something in grunt-urequire ?
            chai: 'chai'
            lodash: '_'
            uberscore: '_B'
            'spec-data': 'data'
        outputPath: "buildSpecDir_combined/index-combined.js"
        template: 'combined'

    realConfs = [
          dependencies:
            bundleExports:
              lodash: "_"
              "agreement/isAgree": "isAgree"

          outputPath: "build/code"
          done: [Function]
        ,
          bundle:
            bundlePath: "source/code"
            ignore: [/^draft/]
            dependencies:
              noWeb: ["util"]

          build:
            verbose: false
            debugLevel: 90
        ,
          bundle:
            bundleName: "uberscoreUMD"

      ]


    conf = blendConfigs.apply @, realConfs
    l.log '\n', conf
