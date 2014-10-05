_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/urequire/urequire-spec', 1

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
rimraf = require 'rimraf'

urequire = require '../../code/urequire'

globExpand = require 'glob-expand'
isFileInSpecs = require '../../code/config/isFileInSpecs'
BundleFile = require '../../code/fileResources/BundleFile'

example = 'urequire-example'
exampleDir = "../#{example}"
exampleTemp = "temp/#{example}"
#copyFiles = null

describe "urequire BundleBuilder:", ->
  bb = null
  defaultConfig = null
  VERSION = JSON.parse(fs.readFileSync process.cwd() + '/package.json').version

  before "Finding or `git clone` `#{exampleDir}`", ->
    (fs.existsP(exampleDir).then (isExists)->
      if isExists
        l.ok "Example repo exists in `#{exampleDir}`"
        When()
      else
        l.warn "Cloning repo anodynos/#{example} in `../`"
        logExecP("git clone https://github.com/anodynos/#{example}", cwd: '../').then ->
          logExecP("git checkout master", cwd: exampleDir)
    )
      .then ->
        l.deb "Deleting 'temp'"
        rimraf.sync 'temp'
        l.deb "Copying source files from '#{ exampleDir }' to '#{exampleTemp}':"
        copyFiles = (
           _.filter globExpand({cwd: exampleDir + '/source', filter: 'isFile'},
                    ['**/*'])
          ).map((f)->'source/'+f).concat _.filter globExpand({cwd: exampleDir, filter: 'isFile'}, ['*'])

        for file in copyFiles
          BundleFile.copy exampleDir + '/' + file, exampleTemp + '/' + file

  defaultConfig =
    path: "#{exampleTemp}/source/code"
    dependencies: exports: bundle: lodash: ['_']
    main: "urequire-example"
    resources: [
        #  'injectVERSION' # test a promise injectVERSION
        [ '+injectVERSIONPromises', 'An injectVERSION that returns a promise instead of sync', ['urequire-example.js'],
          (m)-> When().delay(0).then -> m.beforeBody = "var VERSION = '#{VERSION }';" ]

        [ '!injectTestAsync', 'An inject test that runs async', ['urequire-example.js'],
          (m, cb)-> setTimeout -> cb null, "'testASync';" + m.converted ]

        [ '!injectTestSync', 'An inject test that runs synchronoysly', ['urequire-example.js'],
          (m)-> "'testSync';" + m.converted ]

    ]
    clean: true
    debugLevel: 110

  describe "`BundleBuilder.buildBundle` builds all files in `#{exampleTemp}/source/code`}`: ", ->
    tests = [
        cfg:
          template: 'UMDplain'
          dstPath: "#{exampleTemp}/build/UMD"
        mylib: "#{exampleTemp}/build/UMD/urequire-example.js"
      ,
        cfg:
          template: 'nodejs'
          dstPath: "#{exampleTemp}/build/nodejs"
        mylib: "#{exampleTemp}/build/nodejs/urequire-example.js"
      ,
        cfg:
          template: 'combined'
          dstPath: "#{exampleTemp}/build/urequire-example-dev"
        mylib: "#{exampleTemp}/build/urequire-example-dev.js"
    ]


    buildLib = null
    global_urequireExample = 'global': 'urequireExample'
    global_uEx = 'global': 'uEx'

    for test in tests
      do (cfg = test.cfg, mylib = test.mylib)->
        describe "with `#{cfg.template}` template:", ->
          before ->
            bb = new urequire.BundleBuilder [cfg, defaultConfig]
            bb.buildBundle().then ->
              global.urequireExample = global_urequireExample
              global.uEx = global_uEx
              buildLib = require '../../../' + mylib

          it "initialized correctly from a defaultConfig", ->
            tru _B.isHash bb.bundle #todo: test more
            tru _B.isHash bb.build
            equal bb.build.template.name, cfg.template

          it "lib has VERSION", ->
              equal buildLib.VERSION, VERSION

          it "lib file exists & has correct content", ->
            When.all [
              expect(fs.existsP mylib).to.eventually.be.true
              expect(fs.readFileP mylib, 'utf8').to.eventually.equal fs.readFileSync mylib, 'utf8' # @todo: equal to what ?
              fs.readFileP(mylib, 'utf8').then (content)->
                if cfg.template isnt 'combined'
                  tru _.startsWith content, "'testSync';'testASync';"
            ]

          describe "lib has correct behavior", ->

            it "exports required modules", ->
              equal buildLib.person.age, 40
              equal buildLib.add(40, 14), 54
              equal buildLib.calc.add(40, 14), 54
              equal buildLib.calc.multiply(40, 3), 120

            it "extends required 'class' modules", ->
              equal buildLib.person.eat('food'), 'ate food'

          describe "it exports:", ->
            it "to root (window / global)", ->
              equal buildLib, urequireExample
              equal buildLib, uEx

            it "adds noConflict(), that reclaims overwritten globals", ->
              equal buildLib.noConflict(), buildLib
              equal urequireExample, global_urequireExample
              equal uEx, global_uEx
