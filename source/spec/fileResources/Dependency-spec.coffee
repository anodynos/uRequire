_ = require 'lodash'
chai = require 'chai'
assert = chai.assert
expect = chai.expect

{areEqual, areLike, areRLike, untrust} = require '../helpers'

Dependency = require "../../code/fileResources/Dependency"

describe "Dependency:", ->

  describe "init & and extracting data:", ->

    it "split plugin, extension, resourceName & recostruct as String", ->
      dep = new Dependency depString = 'somePlugin!somedir/dep.js'

      expect(dep.pluginName).to.equal 'somePlugin'
      expect(dep.extname).to.equal '.js'
      expect(dep.name()).to.equal 'somePlugin!somedir/dep.js'
      expect(dep.toString()).to.equal depString
      expect(dep.name plugin:no, ext:no ).to.equal 'somedir/dep'

    it "'node' is not considered a plugin - its just a flag", ->
      dep = new Dependency depString = 'node!somedir/dep.js'

      expect(dep.pluginName).to.equal 'node'
      expect(dep.name()).to.equal 'somedir/dep.js'
      expect(dep.toString()).to.equal depString
      expect(dep.depString).to.equal depString
      expect(dep.name plugin:true, ext:true).to.equal 'somedir/dep.js'

  describe "uses module.path & bundle.dstFilenames:", ->

    describe "converts from (unormalized) fileRelative to bundleRelative:", ->
      dep = new Dependency(
        depString = './.././../../rootdir//dep'         # original non-normalized dependency name
        {
          path: 'path/from/bundleroot/module.path.js'  # the module that has this dependenecy
          bundle: dstFilenames: ['rootdir/dep.js']     # module files in bundle
        }
      )

      it "knows basic dep data", ->
        expect(dep.extname).to.equal undefined
        expect(dep.pluginName).to.equal undefined

      it "knows dep is found", -> expect(dep.isFound).to.equal true
      it "dep.type is 'bundle'", -> expect(dep.type).to.equal 'bundle'

      it "calculates bundleRelative", ->
        expect(dep.name relative:'bundle').to.equal 'rootdir/dep'

      it "calculates a normalized fileRelative", ->
        expect(dep.name relative:'file').to.equal '../../../rootdir/dep'

      it "returns depString as toString()", ->
        expect(dep.toString()).to.equal depString


    describe "converts from bundleRelative to fileRelative:", ->
      dep = new Dependency(
        depString = 'path/from/bundleroot/to/some/nested/module'            # dependency name
        {
          path: 'path/from/bundleroot/module.path'                    # the module that has this dependenecy
          bundle: dstFilenames: ['path/from/bundleroot/to/some/nested/module.js']   # module files in bundle
        }
      )

      it "knows dep is found", -> expect(dep.isFound).to.equal true
      it "dep.type is 'bundle'", -> expect(dep.type).to.equal 'bundle'

      it "calculates as-is bundleRelative", ->
        expect(dep.name relative:'bundle').to.equal 'path/from/bundleroot/to/some/nested/module'

      it "calculates a fileRelative", ->
        expect(dep.name relative:'file').to.equal './to/some/nested/module'

    describe "Changing its depString and module.path:", ->

      describe "changes the calculation of paths:", ->

        dep = new Dependency(
          'path/to/module'           # dependency name
          {
            path: 'someRootModule'
            bundle: dstFilenames: ['path/to/module.js', 'path/to/another/module.js']  # module files in bundle
          }
        )

        dep.depString = 'path/to/another/module'
        dep.module.path = 'some/non/rootModule.js'        # the module that has this dependenecy

        it "knows dep is found", -> expect(dep.isFound).to.equal true
        it "dep.type is 'bundle'", -> expect(dep.type).to.equal 'bundle'

        it "calculates as-is bundleRelative", ->
          expect(dep.name relative:'bundle').to.equal 'path/to/another/module'

        it "calculates fileRelative", ->
          expect(dep.name relative:'file').to.equal '../../path/to/another/module'

      describe "changes the calculation of paths, with plugin present:", ->

        dep = new Dependency(
          'plugin!path/to/module'           # dependency name
          {
            path: 'someRootModule'        # the module that has this dependenecy
            bundle: dstFilenames: ['path/to/module.js', 'path/to/another/module.js']  # module files in bundle
          }
        )

        dep.depString = 'path/to/another/module'
        dep.module.path = 'some/non/rootModule.js'        # the module that has this dependenecy

        it "knows dep is found", -> expect(dep.isFound).to.equal true
        it "dep.type is 'bundle'", -> expect(dep.type).to.equal 'bundle'

        it "calculates as-is bundleRelative with the same plugin", ->
          expect(dep.name relative:'bundle').to.equal 'plugin!path/to/another/module'

        it "calculates fileRelative with the same plugin ", ->
          expect(dep.name relative:'file').to.equal 'plugin!../../path/to/another/module'

  describe "isEquals():", ->
    mod =
      path: 'path/from/bundleroot/module.path.js'
      bundle: bundle: dstFilenames: ['rootdir/dep.js']

    anotherMod =
      path: 'another/bundleroot/module2.js'
      bundle: dstFilenames: ['rootdir/dep.js']

    dep1 = new Dependency '.././../../rootdir/dep.js', mod
    dep2 = new Dependency 'rootdir/dep', mod
    dep3 = new Dependency '../.././rootdir///dep', anotherMod
    depPlugin = new Dependency 'somePlugin!rootdir/dep', mod
    glob = new Dependency 'globalDep', mod

    it "recognises 'global' type equality", ->
      expect(glob.isEqual 'globalDep').to.be.true
      expect(glob.isEqual './globalDep').to.be.false

    it "With `Dependency` as param", ->
      expect(dep1.isEqual dep2).to.be.true
      expect(dep2.isEqual dep1).to.be.true
      expect(dep1.isEqual dep3).to.be.true
      expect(dep3.isEqual dep2).to.be.true

    it "false when plugin differs", ->
      expect(dep1.isEqual depPlugin).to.be.false
      expect(dep2.isEqual depPlugin).to.be.false
      expect(dep3.isEqual depPlugin).to.be.false

    describe "With `String` as param:", ->

      describe " with `bundleRelative` format:", ->

        describe "with .js extensions", ->
          it "matches alike", ->
            expect(dep1.isEqual 'rootdir/dep.js').to.be.true
            expect(dep2.isEqual 'rootdir/dep.js').to.be.true
            expect(dep3.isEqual 'rootdir/dep.js').to.be.true

        describe "plugins still matter:", ->

          it "they make a difference", ->
            expect(dep1.isEqual 'somePlugin!rootdir/dep.js').to.be.false
            expect(dep2.isEqual 'somePlugin!rootdir/dep.js').to.be.false
            expect(dep3.isEqual 'somePlugin!rootdir/dep.js').to.be.false

          it "they only match same plugin name:", ->
            expect(depPlugin.isEqual 'somePlugin!rootdir/dep.js').to.be.true
            expect(depPlugin.isEqual 'someOtherPlugin!rootdir/dep.js').to.be.false

        describe "without extensions:", ->
          it "matches alike", ->
            expect(dep1.isEqual 'rootdir/dep').to.be.true
            expect(dep2.isEqual 'rootdir/dep').to.be.true
            expect(dep3.isEqual 'rootdir/dep').to.be.true

          describe "plugins still matter:", ->
            it "they make a difference", ->
              expect(dep1.isEqual 'somePlugin!rootdir/dep').to.be.false
              expect(dep2.isEqual 'somePlugin!./rootdir/dep').to.be.false
              expect(dep3.isEqual 'somePlugin!rootdir/dep').to.be.false

            it "they only match same plugin name:", ->
              expect(depPlugin.isEqual 'somePlugin!rootdir/dep').to.be.true
              expect(depPlugin.isEqual 'somePlugin!../../../rootdir/dep').to.be.true
              expect(depPlugin.isEqual 'someOtherPlugin!rootdir/dep').to.be.false

      describe " with `fileRelative` format, it matches relative path from same module distance", ->

        it "with .js extensions", ->
          expect(dep1.isEqual '../../../rootdir/dep.js').to.be.true
          expect(dep2.isEqual '../../../rootdir/dep.js').to.be.true

          expect(dep3.isEqual '../../rootdir/dep.js').to.be.true

        it "with .js extensions & unormalized paths", ->
          expect(dep1.isEqual './../../../rootdir/dep.js').to.be.true
          expect(dep2.isEqual '.././../../rootdir/dep.js').to.be.true
          expect(dep3.isEqual './../../rootdir/dep.js').to.be.true

        it "plugins still matter", ->
          expect(depPlugin.isEqual 'somePlugin!../../../rootdir/dep.js').to.be.true
          expect(depPlugin.isEqual 'someOtherPlugin!../../../rootdir/dep.js').to.be.false

        it "plugins still matter with unormalized paths", ->
          expect(depPlugin.isEqual 'somePlugin!./.././../../rootdir/dep.js').to.be.true
          expect(depPlugin.isEqual 'somePlugin!./.././../../rootdir/dep.js').to.be.true

        it "without extensions", ->
          expect(dep1.isEqual './../../../rootdir/dep').to.be.true
          expect(dep2.isEqual './../../../rootdir/dep').to.be.true
          expect(dep3.isEqual '../.././rootdir/./dep').to.be.true

        it "plugins still matter", ->
          expect(depPlugin.isEqual 'somePlugin!./../../../rootdir/dep').to.be.true
          expect(depPlugin.isEqual 'someOtherPlugin!../../../rootdir/dep').to.be.false

      it "with false extensions", ->
        expect(dep1.isEqual 'rootdir/dep.txt').to.be.false
        expect(dep2.isEqual '../../../rootdir/dep.txt').to.be.false
        expect(dep3.isEqual '../../rootdir/dep.txt').to.be.false

      it "looking for one in an array", ->
        dependencies = [dep1, dep2, depPlugin]
        expect(_.any dependencies, (dep)-> dep.isEqual 'rootdir/dep.js').to.be.true

  describe "resolving all types bundle/file relative, external, global, notFound, webRootMap:", ->
    mod =
      path: 'actions/greet'
      bundle: dstFilenames: [
       'main.js'
       'actions/greet.js'
       'actions/moreactions/say.js'
       'calc/add.js'
       'calc/multiply.js'
       'data/numbers.js'
       'data/messages/bye.js'
       'data/messages/hello.js'
      ]

    strDependencies = [
      'underscore'                    # should add to 'global'
      'data/messages/hello.js'        # should remove .js, since its in bundle.dstFilenames
      './/..//data//messages/bye'     # should normalize
      './moreactions/say.js'          # should normalize
      '../lame/dir.js'                # should add to 'notFoundInBundle', add as is
      '.././../some/external/lib.js'  # should add to 'external', add as is
      '/assets/jpuery-max'            # should add to webRootMap
      'require', 'module', 'exports'  # system libs
    ]

    dependencies = []
    for dep in strDependencies
      dependencies.push new Dependency dep, mod

    dependencies.push new Dependency '"main"+".js"', mod, true # untrusted

    expected =
      bundleRelative: untrust [10], [ # @todo: with .js removed or not ?
        'underscore'                 # global lib
        'data/messages/hello'        # .js is removed since its in bundle.dstFilenames
        'data/messages/bye'          # as bundleRelative
        'actions/moreactions/say'
        'lame/dir.js'                # as bundleRelative, with .js since its NOT in bundle.dstFilenames
        '../../some/external/lib.js' # exactly as is
        '/assets/jpuery-max'
        'require', 'module', 'exports' # as is
        '"main"+".js"'
      ]
      fileRelative: untrust [10], [     # @todo: with .js removed or not ?
        'underscore'                    # global lib, as is
        '../data/messages/hello'        # converted fileRelative
        '../data/messages/bye'
        './moreactions/say'
        '../lame/dir.js'
        '../../some/external/lib.js'    #exactly as is
        '/assets/jpuery-max'
        'require', 'module', 'exports'  # as is
        '"main"+".js"'
      ]
      global: [ 'underscore' ]
      external:[ '../../some/external/lib.js' ]
      notFoundInBundle:[ '../lame/dir.js' ]
      webRootMap: ['/assets/jpuery-max']
      system: ['require', 'module', 'exports']
      untrusted: untrust [0], ['"main"+".js"']

    it "using dep.isXXX:", ->
      fileRelative =  ( d.name relative:'file' for d in dependencies )
      bundleRelative = ( d.name relative:'bundle' for d in dependencies)
      global = ( d.name() for d in dependencies when d.isGlobal)
      external = ( d.name() for d in dependencies when d.isExternal)
      notFoundInBundle = ( d.name() for d in dependencies when d.isNotFoundInBundle )
      webRootMap = ( d.name() for d in dependencies when d.isWebRootMap )
      system = ( d.name() for d in dependencies when d.isSystem )
      untrusted = ( d.name() for d in dependencies when d.isUntrusted )

      expect(
        areEqual {bundleRelative, fileRelative, global,
          external, notFoundInBundle, webRootMap, system, untrusted
        }, expected
      ).to.be.true

    it "using dep.type:", ->
      fileRelative = ( d.name relative:'file' for d in dependencies )
      bundleRelative = ( d.name relative:'bundle' for d in dependencies)
      global = ( d.name() for d in dependencies when d.type is 'global')
      external = ( d.name() for d in dependencies when d.type is 'external')
      notFoundInBundle = ( d.name() for d in dependencies when d.type is 'notFoundInBundle')
      webRootMap = ( d.name() for d in dependencies when d.type is 'webRootMap' )
      system = ( d.name() for d in dependencies when d.type is 'system' )
      untrusted = ( d.name() for d in dependencies when d.type is 'untrusted' )

      expect(
        areEqual {bundleRelative, fileRelative, global,
          external, notFoundInBundle, webRootMap, system, untrusted
        }, expected
      ).to.be.true