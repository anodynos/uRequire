MasterDefaultsConfig = require '../../code/config/MasterDefaultsConfig'
Dependency = require "../../code/fileResources/Dependency"

# replace depStrings @ indexes with a String() having 'untrusted:true` property
untrust = (indexes, depsStrings) ->
  for idx in indexes
    depsStrings[idx] = new String depsStrings[idx]
    depsStrings[idx].untrusted = true
    depsStrings[idx].inspect = -> @toString() + ' (untrusted in test)'
  depsStrings

describe "Dependency:", ->

  describe "init & and extracting data:", ->

    it "split plugin, extension, resourceName & recostruct as String", ->
      dep = new Dependency depString = 'somePlugin!somedir//dep.js', {}

      equal dep.pluginName, 'somePlugin'
      equal dep.extname, '.js'
      equal dep.name(), 'somePlugin!somedir/dep' #.js ?
      equal dep.toString(), depString
      equal dep.name(plugin:no, ext:no), 'somedir/dep'

    it "'node' is not considered a plugin - its just a flag", ->
      dep = new Dependency depString = 'node!somedir/dep.js', {}

      equal dep.pluginName, 'node'
      equal dep.name(), 'somedir/dep' #.js
      equal dep.toString(), depString
      equal dep.depString, depString
      equal dep.name(plugin:true, ext:true), 'somedir/dep.js'

  describe "uses module.path & bundle.dstFilenames:", ->

    describe "converts from (unormalized) fileRelative to bundleRelative:", ->
      dep = new Dependency(
        depString = './.././../../rootdir//dep'         # original non-normalized dependency name
        {
          path: './path/from/bundleroot/module.path.js'  # the module that has this dependenecy
          bundle: dstFilenames: ['rootdir/dep.js']     # module files in bundle
        }
      )

      it "knows basic dep data", ->
        equal dep.extname, undefined
        equal dep.pluginName, ''

      it "calculates bundleRelative", ->
        equal dep.name(relative:'bundle'), 'rootdir/dep'

      it "calculates a normalized fileRelative", ->
        equal dep.name(relative:'file'), '../../../rootdir/dep'

      it "returns depString as toString()", ->
        equal dep.toString(), depString

      it "knows dep is found", -> tru dep.isFound
      it "dep.type is 'bundle'", -> equal dep.type, 'bundle'

    describe "converts from bundleRelative to fileRelative:", ->
      dep = new Dependency(
        depString = 'path/from/bundleroot/to/some/nested/module'            # dependency name
        {
          path: 'path/from/bundleroot/module.path'                    # the module that has this dependenecy
          bundle: dstFilenames: ['path/from/bundleroot/to/some/nested/module.js']   # module files in bundle
        }
      )

      it "calculates as-is bundleRelative", ->
        equal dep.name(relative:'bundle'), 'path/from/bundleroot/to/some/nested/module'

      it "calculates a fileRelative", ->
        equal dep.name(relative:'file'), './to/some/nested/module'

      it "knows dep is found", -> tru dep.isFound
      it "dep.type is 'bundle'", -> equal dep.type, 'bundle'

    describe "Changing its depString and module.path:", ->

      describe "changes the calculation of paths:", ->

        dep = new Dependency(
          'path/to/module'           # dependency name
          {
            path: 'someRootModule'
            bundle: dstFilenames: [ # module files in bundle
              'path/to/module.js',
              'path/to/another/module.js']
          }
        )

        dep.depString = 'path/to/another/module'
        dep.module.path = 'some/non/rootModule.js'        # the module that has this dependenecy

        it "knows dep is found", -> tru dep.isFound

        it "dep.type is 'bundle'", ->
          equal dep.type, 'bundle'
          tru dep.isBundle

        it "calculates as-is bundleRelative", ->
          equal dep.name(relative:'bundle'), 'path/to/another/module'

        it "calculates fileRelative", ->
          equal dep.name(relative:'file'), '../../path/to/another/module'

      describe "changes the calculation of paths, with plugin present:", ->

        dep = new Dependency(
          'plugin!path/to/module'         # dependency name
          {
            path: 'someRootModule'        # the module that has this dependenecy
            bundle: dstFilenames: [       # module files in bundle
              'path/to/module.js',
              'path/to/another/module.js']
          }
        )

        dep.depString = 'plugin!path/to/another/module'
        dep.module.path = 'some/non/rootModule.js'        # the module that has this dependenecy

        it "knows dep is found", -> tru dep.isFound
        it "dep.type is 'bundle'", ->
          equal dep.type, 'bundle'
          tru dep.isBundle

        it "calculates as-is bundleRelative with the same plugin", ->
          equal dep.name(relative:'bundle'), 'plugin!path/to/another/module'

        it "calculates fileRelative with the same plugin ", ->
          equal dep.name(relative:'file'), 'plugin!../../path/to/another/module'


  describe "A nodejs style `require('some/dirname')` is translated to require('some/dirname/index.js'):", ->

    dep = new Dependency(
      'path/to/some/dirname'        # dependency name, missing `index.js`
      {                             # the module mock with this dependenecy
        path: 'path/to/aModule'
        bundle: dstFilenames: [  'path/to/some/dirname/index.js']
      }
    )

    it "the dep is not `found`", -> fals dep.isFound
    it "the dep is only `foundAsIndex`", -> tru dep.isFoundAsIndex

    describe "dep.name() has `index` appended ", ->
      it "as fileRelative", -> equal dep.name(), './some/dirname/index'
      it "as bundleRelative", -> equal dep.name(relative:'bundle'), 'path/to/some/dirname/index'

    describe "dep equals a string dep with `index` appended ", ->
      it "as fileRelative", -> dep.isEqual './some/dirname/index'
      it "as bundleRelative", -> dep.isEqual 'path/to/some/dirname/index'

  describe "isEquals():", ->
    mod =
      path: 'path/from/bundleroot/module.path.js'
      bundle: dstFilenames: ['rootdir/dep.js']

    anotherMod =
      path: 'another/bundleroot/module2.js'
      bundle: mod.bundle # same bundle

    dep1 = new Dependency '.././../../rootdir/dep.js', mod
    dep2 = new Dependency 'rootdir/dep', mod
    dep3 = new Dependency '../.././rootdir///dep', anotherMod
    depPlugin = new Dependency 'somePlugin!rootdir/dep', mod
    locDep = new Dependency 'localDep', mod

    it "recognises 'local' type equality", ->
      tru locDep.isEqual 'localDep'
      fals locDep.isEqual './localDep'

    it "With `Dependency` as param", ->
      tru dep1.isEqual dep2
      tru dep2.isEqual dep1
      tru dep1.isEqual dep3
      tru dep3.isEqual dep2

    it "false when plugin differs", ->
      fals dep1.isEqual depPlugin
      fals dep2.isEqual depPlugin
      fals dep3.isEqual depPlugin

    describe "With `String` as param:", ->

      describe " with `bundleRelative` format:", ->

        describe "with .js extensions", ->
          it "matches alike", ->
            [dep1, dep2, dep3].forEach (dep) ->
              tru dep.isEqual 'rootdir/dep.js'

        describe "plugins still matter:", ->

          it "they make a difference", ->
            [dep1, dep2, dep3].forEach (dep) ->
              fals dep.isEqual 'somePlugin!rootdir/dep.js'

          it "they only match same plugin name:", ->
            tru depPlugin.isEqual 'somePlugin!rootdir/dep.js'
            fals depPlugin.isEqual 'someOtherPlugin!rootdir/dep.js'

        describe "without extensions:", ->
          it "matches alike", ->
            [dep1, dep2, dep3].forEach (dep) ->
              tru dep.isEqual 'rootdir/dep'

          describe "plugins still matter:", ->
            it "they make a difference", ->
              [dep1, dep2, dep3].forEach (dep) ->
                fals dep1.isEqual 'somePlugin!rootdir/dep'

            it "they only match same plugin name:", ->
              tru depPlugin.isEqual 'somePlugin!rootdir/dep'
              tru depPlugin.isEqual 'somePlugin!../../../rootdir/dep'
              fals depPlugin.isEqual 'someOtherPlugin!rootdir/dep'

      describe " with `fileRelative` format, it matches relative path from same module distance", ->

        it "with .js extensions", ->
          tru dep1.isEqual '../../../rootdir/dep.js'
          tru dep2.isEqual '../../../rootdir/dep.js'
          tru dep3.isEqual '../../rootdir/dep.js'

        it "with .js extensions & unormalized paths", ->
          tru dep1.isEqual './../../../rootdir/dep.js'
          tru dep2.isEqual '.././../../rootdir/dep.js'
          tru dep3.isEqual './../../rootdir/dep.js'

        it "plugins still matter", ->
          tru depPlugin.isEqual 'somePlugin!../../../rootdir/dep.js'
          fals depPlugin.isEqual 'someOtherPlugin!../../../rootdir/dep.js'

        it "plugins still matter with unormalized paths", ->
          tru depPlugin.isEqual 'somePlugin!./.././../../rootdir/dep.js'
          tru depPlugin.isEqual 'somePlugin!./.././../../rootdir/dep.js'

        it "without extensions", ->
          tru dep1.isEqual './../../../rootdir/dep'
          tru dep2.isEqual './../../../rootdir/dep'
          tru dep3.isEqual '../.././rootdir/./dep'

        it "plugins still matter", ->
          tru depPlugin.isEqual 'somePlugin!./../../../rootdir/dep'
          fals depPlugin.isEqual 'someOtherPlugin!../../../rootdir/dep'

      it "with false extensions", ->
        fals dep1.isEqual 'rootdir/dep.txt'
        fals dep2.isEqual '../../../rootdir/dep.txt'
        fals dep3.isEqual '../../rootdir/dep.txt'

      it "looking for one in an array", ->
        dependencies = [dep1, dep2, depPlugin]
        tru (_.some dependencies, (dep) -> dep.isEqual 'rootdir/dep.js')

  describe "resolving all types bundle/file relative, external, local, notFound, webRootMap:", ->
    mod =
      path: 'actions/greet'

      bundle:
        dstFilenames: [
          'main.js'
          'actions/greet.js'
          'actions/moreactions/say.min.js'
          'calc/add.js'
          'calc/multiply.js'
          'data/numbers.js'
          'data/messages/bye.ext.js'
          'data/messages/hello.min.js'
          'url.js'                          # url is in 'bundle.dependencies.node' bu if in bundle, its a bundle!
          'somedir/index.js'
          'some/deep/dir/index.js'
          'actions/index.js'
          'index.js'
        ]
        dependencies:
          node: MasterDefaultsConfig.bundle.dependencies.node.concat [
                  'when/node/function', 'node/**/*', '!stream', '!url']
          locals: { when: [] }
          paths: {}
        package: {}

    strDependencies = [
      'underscore'                    # should add to 'local'
      'data/messages/hello.min.js'        # should remove .js, since its in bundle.dstFilenames
      './/..//data//messages/bye.ext'     # should normalize
      './moreactions/say.min.js'      # should normalize & find, even with .min as ext
      '../lame/dir.js'                # should add to 'notFoundInBundle', add as is
      '.././../some/external/lib.js'  # should add to 'external', add as is
      '/assets/jpuery-max'            # should add to webRootMap
       # system
      'require'
      'module'
      'exports'
      #node / node looking
      'url'     # actually in bundle, we have to declare it on `node`
      'stream'  # normaly node-only, but excluded in dependencies.node from being there!
      'util'    # node only
      'when/node/function' # node only, but also local (not missing)
      'node/nodeOnly/deps'

      # dirname/index.js
      'somedir'
      '../somedir'
      'some/deep/dir'
      '../some/deep/dir'

      './'   # should find 'actions/index.js'

      './..' # should find 'index.js'
    ]

    dependencies = []
    for dep in strDependencies
      dependencies.push d = new Dependency dep, mod

    dependencies.push ddd = new Dependency '"main"+".js"', mod, untrusted:true

    expected =

      bundleRelative: untrust [dependencies.length-1], [ # @todo: with .js removed or not ?
        'underscore'                 # local lib
        'data/messages/hello.min'        # .js is removed since its in bundle.dstFilenames
        'data/messages/bye.ext'          # as bundleRelative
        'actions/moreactions/say.min'
        'lame/dir' # relative to bundle, event its NOT in bundle.dstFilenames # @todo: .js ?
        '../some/external/lib'    # relative to bundle, considering module.path
        '/assets/jpuery-max'
        'require' # as is
        'module' # as is
        'exports' # as is
        'url'
        'stream'
        'util'
        'when/node/function'
        'node/nodeOnly/deps'

        'somedir/index'
        'somedir/index'
        'some/deep/dir/index'
        'some/deep/dir/index'

        'actions/index'

        'index'

        '"main"+".js"'
      ]

      fileRelative: untrust [dependencies.length-1], [     # @todo: with .js removed or not ?
        'underscore'                    # local lib, as is
        '../data/messages/hello.min'        # converted fileRelative
        '../data/messages/bye.ext'
        './moreactions/say.min'
        '../lame/dir' #@todo  .js'
        '../../some/external/lib' #todo .js'    #exactly as is
        '/assets/jpuery-max'
        'require'  # as is
        'module'   # as is
        'exports'  # as is
        '../url'
        'stream'
        'util'
        'when/node/function'
        'node/nodeOnly/deps'

        '../somedir/index'
        '../somedir/index'
        '../some/deep/dir/index'
        '../some/deep/dir/index'

        './index'

        '../index'

        '"main"+".js"'
      ]

      local: [ 'underscore', 'stream', 'util', 'when/node/function' ]
      external:[ '../../some/external/lib'] #.js' ]
      notFoundInBundle:[ '../lame/dir'] #.js' ]

      webRootMap: ['/assets/jpuery-max']
      system: ['require', 'module', 'exports']
      untrusted: untrust [0], ['"main"+".js"']
      node: ['util', 'when/node/function', 'node/nodeOnly/deps']
      nodeLocal: ['util', 'when/node/function']

    it "using dep.isXXX:", ->
      fileRelative =  ( d.name relative:'file' for d in dependencies )
      bundleRelative = ( d.name relative:'bundle' for d in dependencies)
      local = ( d.name() for d in dependencies when d.isLocal)
      external = ( d.name() for d in dependencies when d.isExternal)

      notFoundInBundle = ( d.name() for d in dependencies when d.isNotFoundInBundle )
      webRootMap = ( d.name() for d in dependencies when d.isWebRootMap )
      system = ( d.name() for d in dependencies when d.isSystem )
      untrusted = ( d.name() for d in dependencies when d.isUntrusted )
      node = ( d.name() for d in dependencies when d.isNode )
      nodeLocal = ( d.name() for d in dependencies when d.isNodeLocal )

      deepEqual {bundleRelative, fileRelative,
          external, notFoundInBundle, webRootMap,
          system, untrusted, node, nodeLocal, local
      }, expected

    it "using dep.type:", ->
      fileRelative = ( d.name relative:'file' for d in dependencies )
      bundleRelative = ( d.name relative:'bundle' for d in dependencies)
      external = ( d.name() for d in dependencies when d.type is 'external')
      notFoundInBundle = ( d.name() for d in dependencies when d.type is 'notFoundInBundle')
      webRootMap = ( d.name() for d in dependencies when d.type is 'webRootMap' )
      system = ( d.name() for d in dependencies when d.type is 'system' )
      untrusted = ( d.name() for d in dependencies when d.type is 'untrusted' )

      nodeLocal = ( d.name() for d in dependencies when d.type is 'nodeLocal' )

      node = ( d.name() for d in dependencies when d.type in ['node', 'nodeLocal'])
      local = ( d.name() for d in dependencies when d.type in ['local', 'nodeLocal'])

      deepEqual {bundleRelative, fileRelative,
          external, notFoundInBundle, webRootMap,
          system, untrusted, node, nodeLocal, local
      }, expected
