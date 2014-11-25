chai.use require 'chai-as-promised'

globExpand = require 'glob-expand'
upath = require 'upath'
When = require 'when'
fs = require "fsp"

logPromise = require('../../code/promises/logPromise') l
execP = When.node.lift require("child_process").exec
logExecP = logPromise execP, 'exec', 'stdout', 'stderr'

mkdirP = When.node.lift require 'mkdirp'
rimraf = require 'rimraf'

urequire = require '../../code/urequire'

BundleFile = require '../../code/fileResources/BundleFile'

example = 'urequire-example-testbed'
exampleDir = "../#{example}"
exampleTemp = "temp/#{example}"

forceRefreshTemp = true

VERSION = JSON.parse(fs.readFileSync process.cwd() + '/package.json').version

describe "urequire:", ->
  it "has a VERSION (concated by grunt-concat on build):", ->
    equal urequire.VERSION, VERSION

describe "urequire.BundleBuilder:", ->
  bb = undefined

  before "Finding or `git clone` `#{exampleDir}`", ->
    if forceRefreshTemp or not fs.existsSync exampleTemp
      (fs.existsP(exampleDir).then (isExists)->
        if isExists
          l.ok "Example repo exists in `#{exampleDir}`"
          When()
        else
          l.warn "Cloning repo anodynos/#{example} in `../`"
          logExecP("git clone https://github.com/anodynos/#{example}", cwd: '../').then ->
            logExecP("git checkout 7550bfe", cwd: exampleDir)
      ).then ->
        l.deb "Deleting 'temp'"
        rimraf.sync 'temp'
        l.deb "Copying source files from '#{ exampleDir }' to '#{exampleTemp}':"
        copyFiles = globExpand({cwd: exampleDir + '/source', filter: 'isFile'}, ['**/*']).map((f)->'source/'+f)
                      .concat(_.filter globExpand({cwd: exampleDir, filter: 'isFile'}, ['*']))

        for file in copyFiles
          BundleFile.copy exampleDir + '/' + file, exampleTemp + '/' + file

  buildBundleResults = null

  # @todo: steal `urequire` from `urequire-example-testbed` Gruntfile.coffee
  main = 'my-main'
  grandParentConfig =
    main: main
    path: "#{exampleTemp}/source/code"
    filez: [/./, '!uRequireConfig.coffee']
    template: banner: false # testing async RCs that write to main file
    dependencies:
      imports:
        lodash: '_'
        'when/node': ['whenNode']
      rootExports: _B.okv {}, main, 'uEx'
    rjs:shim:
      lodash: { deps:[], exports:['_'] }
    exportsRoot: ['AMD', 'node', 'script'] # renamed to `rootExports.runtimes`

    resources: [
      # disable `coffee-script` RC & replace with `coffee-script-exec`
      (lookup)->
        (cf = lookup 'coffee-script').enabled = false

        _.extend lookup('exec').clone(), {
          name: '$coffee-script-exec'
          filez: cf.filez
          cmd: 'coffee -cp'
          convFilename: '.js'
        }

      # instead of 'inject-version', test a promise returning injectVERSION
      [ '+injectVERSIONPromises', 'An injectVERSION that returns a promise instead of sync', ["#{main}.js"],
        (m)-> When().delay(0).then -> m.beforeBody = "var VERSION = '#{VERSION }';" ]

      [ '!injectTestAsync', 'An inject test that runs async with callback', ["#{main}.js"],
        (m, cb)-> setTimeout => cb null, m.converted + ";'#{@name}';" ]

      [ '!injectTestSync', 'An inject test that runs synchronously', ["#{main}.js"],
        (m)-> m.converted + "'#{@name}';" ]

      [ '!injectTestPromise', 'An inject test that returns a promise', ["#{main}.js"],
        (m)-> When().delay(0).then => m.converted + "'#{@name}';"]
      
      [ '!injectTestAsyncRacePromise', 'An inject test with callback signature, returning promise instead', ["#{main}.js"],
        (m, cb)-> When().delay(0).then => m.converted + "'#{@name}';"]
    ]

    afterBuild: [
      (doneVal)-> buildBundleResults.push 'afterBuild0': doneVal
      (donePromise)->
        When().delay(1).then ->
          buildBundleResults.push 'afterBuild1': donePromise
    ]

  mainTextEndsWithRcInjections = "'injectTestAsync';'injectTestSync';'injectTestPromise';'injectTestAsyncRacePromise';"

  parentConfig =
    dependencies:
      imports:
        'when/callbacks': ['whenCallbacks']
      locals: 
        when: 'bower_components/when'        
      node: [
        'when/node**', 'nodeOnly/*'
      ]
      paths: 
        override: lodash: "user/defined/lodash/path"

    rjs: paths:
      lodash: "rjs/defined/lodash.min"

    resources: [
      ['less', { # ['style/**/*.less'], {
          $srcMain: 'style/myMainStyle.less'
          compress: true
      }]

      ['teacup-js', tags: 'html, doctype, body, div, ul, li']
    ]
    clean: true

    unknownkey: "irrelevant" # @todo: throw on unknown keys
#    debugLevel: 100

    afterBuild: [
      (err, bb)->
        When().delay(1).then ->
          buildBundleResults.push 'afterBuild2' : [err, bb]

      (err, bb, cb) ->
        setTimeout ->
          buildBundleResults.push 'afterBuild3' : [err, bb]
          cb null

      (err, bb, cb) -> # return promise instead of calling cb
        When().delay(1).then ->
          buildBundleResults.push 'afterBuild4' : [err, bb]
          throw new UError "afterBuild4 throws if err" if err

      (err, bb)-> #just sync, throw if err
        buildBundleResults.push 'afterBuild5' : [err, bb]
        throw new UError "afterBuild5 throws if err" if err
    ]

  describe "`BundleBuilder.buildBundle` :", ->
    tests = [
        cfg:
          template: 'UMDplain'
          target: "target1"
          dstPath: "#{exampleTemp}/build/UMDplain"
        mylib: "#{exampleTemp}/build/UMDplain/#{main}.js"
      ,
        cfg:
          template: 'nodejs'
          target: "target2"
          dstPath: "#{exampleTemp}/build/nodejs"
        mylib: "#{exampleTemp}/build/nodejs/#{main}.js"
      ,
        cfg:
          template: 'combined'
          target: "target3"
          dstPath: "#{exampleTemp}/build/combined/urequire-example-testbed"
        mylib: "#{exampleTemp}/build/combined/urequire-example-testbed.js"
    ]

    buildLib = null
    global_urequireExample = 'global': 'urequireExample'
    global_uEx = 'global': 'uEx'

    buildResult = null
    previousBB = null

    describe "builds all files in `#{exampleTemp}/source/code` :", ->
      for test in tests
        do (test, cfg = test.cfg, mylib = test.mylib)->

          describe "with `#{cfg.template}` template:", ->

            before ->
              bb = new urequire.BundleBuilder [cfg, parentConfig, grandParentConfig]
              buildBundleResults = []
              previousBB = buildResult
              buildResult = null
              bbP = bb.buildBundle()

              bbP.then (res)->
                buildResult = res
                buildBundleResults.push "then1": res
                global.urequireExample = global_urequireExample
                global.uEx = global_uEx
                buildLib = require '../../../' + mylib

              bbP.then (res)-> buildBundleResults.push "then2": res

            it "initialized correctly from parentConfigs", ->
              tru _B.isHash bb.bundle #todo: test more
              tru _B.isHash bb.build
              equal bb.build.template.name, cfg.template

            it "bb.buildBundle().then (res)-> res is bundleBuilder", ->
              equal buildResult, bb

            it "bb.buildBundle().then (res)-> res instanceof bundleBuilder", ->
              tru buildResult instanceof urequire.BundleBuilder

            describe "bundleBuilders build history", ->
              it "bundleBuilder.urequire.BBExecuted has bundleBuilder as last item", ->
                equal _.last(buildResult.urequire.BBExecuted), buildResult

              it "find the bundleBuilder executed before null (this one): ", ->
                equal buildResult.urequire.findBBExecutedBefore(null), buildResult

              it "find the bundleBuilder executed last with null (this one): ", ->
                equal buildResult.urequire.findBBExecutedLast(null), buildResult

              it "find the bundleBuilder executed last with target : ", ->
                equal buildResult.urequire.findBBExecutedLast(buildResult.build.target), buildResult

              describe "find the bundleBuilder executed before this current one: ", ->
                it "by BundleBuilder instance", ->
                  equal buildResult.urequire.findBBExecutedBefore(buildResult), previousBB

                it "by BundleBuilder build.target string", ->
                  equal buildResult.urequire.findBBExecutedBefore(buildResult.build.target), previousBB

              describe "find the bundleBuilder created : ", ->
                it "by target name", ->
                  equal buildResult.urequire.findBBCreated(buildResult.build.target), buildResult

            describe "bundleBuilder.bundle has the correct xxx_depVars:", ->
              removeInjectedIfCombined = (expectedDepVars)->
                if buildResult.build.template.name is 'combined'
                  for injected in [ 'lodash', 'when/node', 'when/callbacks']
                    delete expectedDepVars[injected]
                expectedDepVars

              it "`all_depsVars`", ->
                expected = {}
                expected[main] = [ 'uEx' ] #todo: gather also from @modules.flags.rootExports
                _.extend expected,
                  index: [ 'calc2' ]
                  "calc/add": [ "add" ]
                  "calc/index": [ "calc" ]
                  "calc/multiply": []
                  "lodash": [ "_" ]
                  "teacup": [ "teacup" ]
                  "models/Animal": [ "Animal" ]
                  "models/Person": [ "Person" ]
                  "markup/home": [ 'homeTemplate' ]
                  "markup/persons": [ 'persons' ]
                  "util": []
                  "when/node": ['whenNode']
                  'when/callbacks': [ 'whenCallbacks' ]
                  "nodeOnly/runsOnlyOnNode": ['nodeOnlyVar']
                  "path": []

                deepEqual buildResult.bundle.all_depsVars, expected

              describe "from modules (and injected 'imports' on non-`combined`):", ->

                it "`modules_depsVars`, which contain `dependencies.imports` on non `combined` template", ->
                  deepEqual buildResult.bundle.modules_depsVars,
                    removeInjectedIfCombined(
                      index: [ 'calc2' ]
                      "calc/add": [ "add" ]
                      "calc/index": [ "calc" ]
                      "calc/multiply": []
                      "lodash": [ "_" ] # imports
                      "teacup": [ "teacup" ]
                      "models/Animal": [ "Animal" ]
                      "models/Person": [ "Person" ]
                      "markup/home": [ 'homeTemplate' ]
                      "markup/persons": [ 'persons' ]
                      "util": []
                      "when/node": ['whenNode'] # imports
                      'when/callbacks': [ 'whenCallbacks' ] # imports
                      "nodeOnly/runsOnlyOnNode": ['nodeOnlyVar']
                      "path": []
                    )

                it "`modules_local_depsVars`", ->
                  deepEqual buildResult.bundle.modules_local_depsVars,
                    removeInjectedIfCombined(
                      "lodash": [ "_" ]         # imports
                      "teacup": [ "teacup" ]
                      "when/node": ['whenNode'] # imports
                      'when/callbacks': [ 'whenCallbacks' ] # imports
                      "util": []
                      "path": []
                    )

                it "`modules_node_depsVars`", ->
                  deepEqual buildResult.bundle.modules_node_depsVars,
                    removeInjectedIfCombined(
                      "nodeOnly/runsOnlyOnNode": ['nodeOnlyVar']
                      "util": []
                      "path": []
                      "when/node": ['whenNode'] # injected from dependencies.imports
                    )

              describe "from both modules & imports:", ->

                it "`local_depsVars`", ->
                  deepEqual buildResult.bundle.local_depsVars,
                      "lodash": [ "_" ]
                      "teacup": [ "teacup" ]
                      "when/node": ['whenNode']
                      'when/callbacks': [ 'whenCallbacks' ]
                      "util": []
                      "path": []

                it "`local_nonNode_depsVars`", ->
                  deepEqual buildResult.bundle.local_nonNode_depsVars,
                    "lodash": [ "_" ]
                    "teacup": [ "teacup" ]
                    'when/callbacks': [ 'whenCallbacks' ]

                it "`local_node_depsVars`", ->
                  deepEqual buildResult.bundle.local_node_depsVars,
                    "util": []
                    "when/node": ['whenNode']
                    "path": []

              describe "from imports only:", ->

                it "`imports_depsVars`", ->
                  deepEqual buildResult.bundle.imports_depsVars,
                    "lodash": [ "_" ]
                    "when/node": ['whenNode']
                    'when/callbacks': [ 'whenCallbacks' ]

                it "`imports_nonNode_depsVars`", ->
                  deepEqual buildResult.bundle.imports_nonNode_depsVars,
                    "lodash": [ "_" ]
                    'when/callbacks': [ 'whenCallbacks' ]

                it "`imports_bundle_depsVars`", ->
                  deepEqual buildResult.bundle.imports_bundle_depsVars, {}

              describe "from modules, excluding `imports` always:", ->

                it "`nonImports_local_depsVars`", ->
                  deepEqual buildResult.bundle.nonImports_local_depsVars,
                    "teacup": [ "teacup" ]
                    "util": []
                    "path": []

            describe "bundleBuilder.build.calcRequireJsConfig() calculates the correct:", ->

              describe "`paths`", ->
                depPaths =
                  lodash: [
                    "user/defined/lodash/path"
                    "rjs/defined/lodash.min" ]
                  when: [ 'bower_components/when' ]

                it "relative to `dstPath` by default:", ->
                  deepEqual buildResult.build.calcRequireJsConfig().paths,
                    _.mapValues depPaths, (paths)->
                      paths.map (path)->
                        upath.join upath.relative(bb.build.dstPath, '.'), path

                it "absolute to project's root ( paths as defined / found ):", ->
                  deepEqual buildResult.build.calcRequireJsConfig('').paths, depPaths

                it "to another path from root:", ->
                  somePath = 'another/long/path/from/root'
                  pathToRoot = upath.relative somePath, '.'
                  deepEqual buildResult.build.calcRequireJsConfig(somePath).paths,
                    _.mapValues depPaths, (paths)->
                      paths.map (path)->
                        upath.join pathToRoot, path

              describe "blends with another requirejs config and ignores protocol (http://, git:// etc) paths:", ->

                anotherRjsConfig =
                  paths: lodash: [
                    "another/blendWith/lodash/path"
                    "http://a.protocol/blendWith/path"
                    "ftp://another.protocol/blendWith/path"
                  ]
                  shim: backbone: { deps:['underscore'], exports:['Backbone'] }

                it "blends `paths`, with precedence to `override` and then `blendWith` paths", ->
                  blendedCfg = buildResult.build.calcRequireJsConfig('', anotherRjsConfig)
                  deepEqual blendedCfg.paths,
                    lodash: [
                      "user/defined/lodash/path"
                      "another/blendWith/lodash/path"
                      "http://a.protocol/blendWith/path"
                      "ftp://another.protocol/blendWith/path"
                      "rjs/defined/lodash.min"]
                    when: [ 'bower_components/when' ]

                it "blends `shim` with `_.merge`", ->
                  blendedCfg = buildResult.build.calcRequireJsConfig('', anotherRjsConfig)
                  deepEqual blendedCfg.shim,
                    lodash: { deps:[], exports:['_'] }
                    backbone: { deps:['underscore'], exports:['Backbone'] }

            describe "afterBuild tasks:", ->
              it "`afterBuild()` tasks are called once each, in serial order, followed by .then tasks:", ->
                deepEqual buildBundleResults, [
                  {'afterBuild0' : true}
                  {'afterBuild1' : true}
                  {'afterBuild2' : [null, bb]}
                  {'afterBuild3' : [null, bb]}
                  {'afterBuild4' : [null, bb]}
                  {'afterBuild5' : [null, bb]}
                  {'then1' : bb}
                  {'then2' : bb}
                ]

            describe "ResourceConverters work sync & async", ->

              it "lib has VERSION (injected via a promise returning RC)", ->
                  equal buildLib.VERSION, VERSION

              it "injection as async & sync RC work in the right order", ->
                if cfg.template isnt 'combined'
                  fs.readFileP(mylib, 'utf8').then (text)->
                    tru _.endsWith text, mainTextEndsWithRcInjections

              describe "'less' RC compiles to css:", ->

                it "with {options: compress: true}:", ->
                  expect(fs.readFileP "#{exampleTemp}/build/#{cfg.template}/style/myMainStyle.css", 'utf8')
                    .to.eventually.equal '.anotherStyle{width:2}.myMainStyle{width:1}'

                it "uses `srcMain` to compile 'myMainStyle.css' ONLY", ->
                  expect(fs.existsP "#{exampleTemp}/build/#{cfg.template}/style/morestyles/anotherStyle.css").to.eventually.be.false

            it "lib file exists & has correct content", ->
              When.all [
                expect(fs.existsP mylib).to.eventually.be.true
                expect(fs.readFileP mylib, 'utf8').to.eventually.equal fs.readFileSync mylib, 'utf8' # @todo: equal to what ?
              ]

            describe "`urequire-example-testbed` has the correct behavior", ->

              it "exports required modules", ->
                equal buildLib.person.age, 40
                equal buildLib.add(40, 14), 54
                equal buildLib.calc.add(40, 14), 54
                equal buildLib.calc.multiply(40, 3), 120

              it "renders teacup templates compiled by `teacup-js` RC", ->
                equal buildLib.homeHTML,
                  '<html><body><div id="Hello,">Universe!</div><ul><li>Leonardo</li><li>Da Vinci</li></ul></body></html>'

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

  describe "`BundleBuilder.buildBundle` rejects failures gracefully:", ->
    failingConfig =
      template: 'combined'
      deleteErrored: false
      continue: true
      dstPath: "#{exampleTemp}/build/combinedFailing/urequire-example-testbed"

    buildResult = null
    buildErrors = null

    filesWithError = [ "Person.ls", "Animal.co"].map (f)-> "#{exampleTemp}/source/code/models/" + f

    errorsToInject = [
      'DANGLING\n   TEXT'
      #"require 'missing/dep' \n"
    ]
    originalTexts = null

    after ->
      for f, i in filesWithError
        fs.writeFileSync filesWithError[i], originalTexts[i], encoding: 'utf8'

    before ->
      originalTexts or= []
      for f, i in filesWithError
        originalTexts[i] = fs.readFileSync filesWithError[i], encoding: 'utf-8'
        fs.writeFileSync filesWithError[i], errorsToInject[i] + originalTexts[i], encoding: 'utf8'

      buildBundleResults = []

      bb = new urequire.BundleBuilder [failingConfig, parentConfig, grandParentConfig]
      bbP = bb.buildBundle()

      bbP.then (res)->
        buildResult = res
        buildBundleResults.push "then1": res

      bbP.then (res)-> buildBundleResults.push "then2": res

      bbP.catch (err)-> buildBundleResults.push "catch1": buildErrors = err
      bbP.catch (err)-> buildBundleResults.push "catch2": buildErrors = err

    it "bb.buildBundle().then never called", ->
      equal buildResult, null

    it "bb.buildBundle().catch called with array of Errors", ->
      for err in buildErrors
        tru err instanceof UError

    it "`bb.build.hasErrors` is true", ->
      tru bb.build.hasErrors

    it "`bb.bundle.errorFiles` has one specfic file in error", ->
      equal _.size(bb.bundle.errorFiles), 1
      ok bb.bundle.errorFiles['models/Person.ls']
      tru bb.bundle.errorFiles['models/Person.ls'].hasErrors

    it "`bb.build.changedErrorFiles` has one specfic file in error", ->
      equal _.size(bb.build.changedErrorFiles), 1
      ok bb.build.changedErrorFiles['models/Person.ls']
      tru bb.build.changedErrorFiles['models/Person.ls'].hasErrors

    it "`bb.build.errors` has 2 + 2 errors (one for file, one for 'combined' failure & afterBuild4 & 5)", ->
      equal _.size(bb.build.errors), 4

    describe "afterBuild tasks:", ->
      it "`afterBuild()` tasks are called once each, in serial order, followed by .catch tasks.", ->
        deepEqual buildBundleResults, [
          {'afterBuild0' : buildErrors}
          {'afterBuild1' : buildErrors}
          {'afterBuild2' : [buildErrors, bb]}
          {'afterBuild3' : [buildErrors, bb]}
          {'afterBuild4' : [buildErrors, bb]}
          {'afterBuild5' : [buildErrors, bb]}
          {'catch1': buildErrors}
          {'catch2': buildErrors}
        ]