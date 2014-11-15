AlmondOptimizationTemplate = require "../../code/templates/AlmondOptimizationTemplate"

describe "AlmondOptimizationTemplate:", ->

  it "handles *empty* locals & imports", ->
    bundle =
      modules_localNonNode_depsVars: {}
      modules_node_depsVars: {}
      imports_depsVars:{}

    aot = new AlmondOptimizationTemplate bundle

    likeBA aot,
      bundle: bundle
      local_nonNode_deps: []
      local_nonNode_params: []
      local_nonNode_args: []


  describe "handling of locals & imports & nodeonly deps.", ->

    bundle =
      dstFilenames: ['agreement/isAgree.js']

      local_nonNode_depsVars:
        lodash: [ '__lodash' ] # a local dep, under a funny name
        uberscore: ['_uB']     # another local dep, under a funny name
        chai: [ 'chai' ]       # a local dep, with a name for introspection
        useless: ['_skipMe_']

      imports_bundle_depsVars:
        'agreement/isAgree': [ 'isAgree', 'isAgree2' ] # a bundle dep

      local_node_depsVars:
        util: []
        fs: []

    bundleDeepClone = _.clone bundle, true

    aot = new AlmondOptimizationTemplate bundle

    it "identifies what deps and vars are" , ->

      likeBA aot,
        bundle: bundleDeepClone

        local_nonNode_deps: [
          'lodash',
          'uberscore',
          'chai',
          'useless' ],

        local_nonNode_args:[
          '__lodash',
          '_uB',
          'chai',
          '_skipMe_' ]


    it "creates stubs for grabbing local deps from `global` / `window`, AMD shim or node's require:", ->
      equalSet _.keys(aot.dependencyFiles), [
          'getExcluded_util'
          'getExcluded_fs'

          # these are added on closure
          'getLocal_lodash'
          'getLocal_uberscore'
          'getLocal_chai'
          'getLocal_useless'
        ]

    it "creates corresponding paths for stubs", ->
      deepEqual aot.paths,
        util: 'getExcluded_util'
        fs: 'getExcluded_fs'

        # these are added on closure
        lodash: 'getLocal_lodash'
        chai: 'getLocal_chai'
        uberscore: 'getLocal_uberscore'
        useless: 'getLocal_useless'