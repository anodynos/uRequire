_ = require 'lodash'
_B = require 'uberscore'
l = new _B.Logger 'templates/AlmondOptimizationTemplate-specs'

chai = require 'chai'
expect = chai.expect

{ equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
  ixact, notIxact, like, notLike, likeBA, notLikeBA } = require '../spec-helpers'

AlmondOptimizationTemplate = require "../../code/templates/AlmondOptimizationTemplate"

describe "AlmondOptimizationTemplate:", ->

  it "handles *empty* locals & exports.bundle", ->
    bundle =
      localNonNode_depsVars: {}
      nodeOnly_depsVars: {}
      exportsBundle_depsVars:{}

    deepEqual new AlmondOptimizationTemplate(bundle),
      bundle: bundle
      localDeps: []
      localParams: []
      localArgs: []
      localDepsVars: {}
      exportsBundle_nonLocals_depsVars: {}
      local_nonExportsBundle_depsVars: {}
      localDeps: []

  describe "handling of locals & exports.bundle & nodeonly deps.", ->

    bundle =

      localNonNode_depsVars:
        lodash: [ '__lodash' ] # a local dep, under a funny name
        uberscore: ['_uB']     # another local dep, under a funny name
        chai: [ 'chai' ]       # a local dep, with a name for introspection
        useless: ['_skipMe_']

      exportsBundle_depsVars:
        chai: ['chai']        # a local dep, # @todo: test without no var
        lodash: [ '_']        # a local dep, one depVar
        uberscore: [          # a local dep, many depVars
          '_B'
          'uber'
        ]
        'agreement/isAgree': [ 'isAgree', 'isAgree2' ] # a bundle dep

      nodeOnly_depsVars:
        util: []
        fs: []

    bundleDeepClone = _.clone bundle, true

    ao = new AlmondOptimizationTemplate bundle

    it "identifies what deps and vars are" , ->

      likeBA ao,

        bundle: bundleDeepClone

        localDeps: [
          'chai'
          'lodash'
          'uberscore'
          'uberscore'
        ]

        localArgs: [
          'chai'
          '_'
          '_B'
          'uber'
        ]

        localDepsVars:
          'chai': ['chai']
          'lodash': ['_']
          'uberscore': ['_B', 'uber']

        exportsBundle_nonLocals_depsVars:
          'agreement/isAgree': [ 'isAgree', 'isAgree2' ]

        local_nonExportsBundle_depsVars:
          useless: [ '_skipMe_' ]

    it 'correct bundle.localNonNode_depsVars', ->
      deepEqual bundle.localNonNode_depsVars,
        lodash: [ '__lodash' ]
        chai: [ 'chai' ]
        uberscore: ['_uB' ]
        useless: [ '_skipMe_' ]

    it "creates stubs for grabbing local deps from `global` / `window`, AMD shim or node's require", ->
      ok _B.isEqualArraySet(
          _.keys(ao.dependencyFiles),
            [
             'getLocal_useless'
             'getNodeOnly_util'
             'getNodeOnly_fs'

             # these are added on closure
             'getLocal_lodash'
             'getLocal_uberscore'
             'getLocal_chai'
            ]
        )

    it "creates corresponding paths for stubs", ->
      deepEqual ao.paths,
        useless: 'getLocal_useless'
        util: 'getNodeOnly_util'
        fs: 'getNodeOnly_fs'

        # these are added on closure
        lodash: 'getLocal_lodash'
        chai: 'getLocal_chai'
        uberscore: 'getLocal_uberscore'