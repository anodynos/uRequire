_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/urequire/urequire-spec'

chai = require 'chai'
chai.use require 'chai-as-promised'
expect = chai.expect

{ equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
ixact, notIxact, like, notLike, likeBA, notLikeBA, equalSet, notEqualSet } = require '../specHelpers'

fs = require 'fs'


urequire = require '../../code/urequire'

describe.only "urequire BundleBuilder", ->
  config = null
  bb = null

  setConfigDone = (cfg, done)->
    cfg.done = (val)->
      if val then done()
      else done new Error "uRequire: urequire.BundleBuilder.buildBundle() returned #{val}"

  beforeEach ->
    config =
      path: "source/spec/urequire/code"
      clean: true
      template: 'UMDplain'
      dstPath: "build/spec/urequire/code"
      debugLevel: 0

  it "Initialized from config", ->
    bb = new urequire.BundleBuilder([config])
    tru _B.isHash bb.bundle #todo: test more
    tru _B.isHash bb.build


  it "bundleBuilder.buildBundle ", (mochaDone)->
    config.done = (val)->
      if val
        tru fs.existsSync("source/spec/urequire/code/mylib.js");
        mochaDone()
      else
        mochaDone new Error "uRequire: urequire.BundleBuilder.buildBundle() returned #{val}"
    bb = new urequire.BundleBuilder([config])
    bb.buildBundle()

  it "bundleBuilder.buildBundle changedFiles", (done)->
    setConfigDone config, done
    bb = new urequire.BundleBuilder([config])
    bb.buildBundle('models/person.ls')

