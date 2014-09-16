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
exampleDir = "temp/#{example}"

describe.only "urequire BundleBuilder:", ->

  before "Initialize exampleDir", ->
    fs.existsP(exampleDir).then (isExists)->
      if isExists
        l.ok 'Example repo exists in `temp/`'
        When null # unused return val wrapped as promise resolution
      else
        fs.existsP("../#{example}").then (isExists)->
          if isExists
            exampleDir = "../#{example}"
            l.ok "Example repo exists in `#{exampleDir}`"
            When()
          else
            l.warn ok "Cloning repo anodynos/#{example} in `temp/`"
            mkdirP('temp').then -> logExecP "git clone anodynos/#{example}", cwd: 'temp'

  describe "builds `exampleDir/source/code`:", ->

    bb = null
    config = null
    beforeEach ->
      config =
        path: "#{exampleDir}/source/code"
        clean: true
#        template: 'UMDplain'
        template: 'combined'
        main: "mylib"
        dstPath: "#{exampleDir}/build/code"
        debugLevel: 0

    it "Initialized correctly from a config", ->
      bb = new urequire.BundleBuilder([config])
      tru _B.isHash bb.bundle #todo: test more
      tru _B.isHash bb.build

    it "`bundleBuilder.buildBundle` builds all files in `exampleDir/source/code", ->
      mylib = "#{exampleDir}/build/code/mylib.js"

      bb.buildBundle().then ->
        When.all [
          expect(fs.existsP mylib).to.eventually.be.true
          expect(fs.readFileP mylib, 'utf8').to.eventually.equal fs.readFileSync mylib, 'utf8' #todo: equal to what ?
        ]

    it "`bundleBuilder.buildBundle changedFiles` build only changed files", ->
      bb.buildBundle 'models/person.ls'
        .then ->


    it "eval/run file"
    it "has correct behavior"
    it "converted LiveScript"
    it "converted coco -> "
    it "converted less -> css"
