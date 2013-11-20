_ = require 'lodash'
chai = require 'chai'
assert = chai.assert
expect = chai.expect

{ equal, notEqual, ok, notOk, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
  ixact, notIxact, like, notLike, likeBA, notLikeBA } = require '../spec-helpers'

AlmondOptimizationTemplate = require "../../code/templates/AlmondOptimizationTemplate"

describe "AlmondOptimizationTemplate:", ->

  it "handles *empty* globals & exports.bundle", ->
    bundle =
      globalDepsVars: {}
      nodeOnlyDepsVars: {}
      exportsBundleDepsVars:{}

    deepEqual new AlmondOptimizationTemplate(bundle),
      bundle: bundle
      exportsBundleGlobalParams: []
      exportsBundleGlobalDeps: []
      exportsBundleNonGlobalsDepsVars: {}
      globalNonExportsBundleDepsVars: {}
      defineAMDDeps: []

  describe "handling of globals & exports.bundle & nodeonly deps.", ->
    bundle =
      globalDepsVars:
        lodash: [ '_' ]
        jquery: [ '$', 'jQuery' ]

      exportsBundleDepsVars:
        lodash: [ '_', '_lodash_' ]
        'agreement/isAgree': [ 'isAgree', 'isAgree2' ]

      nodeOnlyDepsVars:
        util: []
        fs: []

    ao = new AlmondOptimizationTemplate bundle

    it "identifies what deps and vars are" , ->
      deepEqual ao,
        bundle: bundle
        exportsBundleGlobalParams: [ '_', '_lodash_' ],
        exportsBundleGlobalDeps: [ 'lodash', 'lodash' ],
        exportsBundleNonGlobalsDepsVars: { 'agreement/isAgree': [ 'isAgree', 'isAgree2' ] },
        globalNonExportsBundleDepsVars: { jquery: [ '$', 'jQuery' ]}
        defineAMDDeps: [ 'lodash', 'lodash', 'jquery' ]

    it "creates stubs for grabbing global deps from global or node", ->
      ok _B.isEqualArraySet(
          _.keys(ao.dependencyFiles),
          ['getGlobal_lodash', 'getGlobal_jquery', 'getNodeOnly_util', 'getNodeOnly_fs']
        )

    it "creates corresponding paths for stubs", ->
      deepEqual ao.paths,
        lodash: 'getGlobal_lodash'
        jquery: 'getGlobal_jquery'
        util: 'getNodeOnly_util'
        fs: 'getNodeOnly_fs'