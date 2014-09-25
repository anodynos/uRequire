_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/urequire/urequire-spec'

chai = require 'chai'
chai.use require 'chai-as-promised'
expect = chai.expect
{ equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
ixact, notIxact, like, notLike, likeBA, notLikeBA, equalSet, notEqualSet } = require '../specHelpers'

When = require 'when'
fs = require "fs"

logPromise = require('../../code/promises/logPromise') l
execP = When.node.lift require("child_process").exec
logExecP = logPromise execP, 'exec', 'stdout', 'stderr'

mkdirP = When.node.lift require 'mkdirp'

urequire = require '../../code/urequire'

example = 'urequire-example'
exampleDir = "../#{example}"

describe "urequire BundleBuilder:", ->
  bb = null
  defaultConfig = null
  VERSION = JSON.parse(fs.readFileSync process.cwd() + '/package.json').version

  before "Initializing exampleDir as `#{exampleDir}`", ->
    fs.existsP(exampleDir).then (isExists)->
      if isExists
        l.ok "Example repo exists in `#{exampleDir}`"
        When()
      else
        l.warn "Cloning repo anodynos/#{example} in `../`"
        logExecP "git clone anodynos/#{example}", cwd: '../'

  beforeEach ->
    defaultConfig =
      path: "#{exampleDir}/source/code"
      dependencies: exports: bundle: lodash: ['_']
      main: "urequire-example"
      resources: ['injectVERSION']
      clean: true
      debugLevel: 0

  describe "`BundleBuilder.buildBundle` builds all files in `#{exampleDir}/source/code`}`: ", ->
    tests = [
        cfg:
          template: 'UMDplain'
          dstPath: "#{exampleDir}/build/UMDplain"
        mylib: "#{exampleDir}/build/UMDplain/urequire-example.js"
      ,
        cfg:
          template: 'nodejs'
          dstPath: "#{exampleDir}/build/nodejs"
        mylib: "#{exampleDir}/build/nodejs/urequire-example.js"
      ,
        cfg:
          template: 'combined'
          dstPath: "#{exampleDir}/build/urequire-example-dev"
        mylib: "#{exampleDir}/build/urequire-example-dev.js"
    ]

    for test in tests
      do (cfg = test.cfg, mylib = test.mylib)->
        describe "with `#{cfg.template}` template:", ->
          it "initialized correctly from a defaultConfig", ->
            bb = new urequire.BundleBuilder [cfg, defaultConfig]
            tru _B.isHash bb.bundle #todo: test more
            tru _B.isHash bb.build
            equal bb.build.template.name, cfg.template

          it "it builds correctly", ->

            bb.buildBundle().then -> # @todo: separate these tests

              buildLib = require '../../../' + mylib
              equal buildLib.VERSION, VERSION

              equal buildLib, urequireExample
              equal buildLib, uEx
              equal buildLib.noConflict(), buildLib
              equal urequireExample, undefined
              equal uEx, undefined

              equal buildLib.person.age, 40
              equal buildLib.add(40, 14), 54

              When.all [
                expect(fs.existsP mylib).to.eventually.be.true
                expect(fs.readFileP mylib, 'utf8').to.eventually.equal fs.readFileSync mylib, 'utf8' # @todo: equal to what ?
              ]