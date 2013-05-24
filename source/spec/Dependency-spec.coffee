_ = require 'lodash'
chai = require 'chai'
assert = chai.assert
expect = chai.expect

Dependency = require "../code/Dependency"

describe "Dependency", ->

  it "converts simple paths from bundleRelative to fileRelative", ->
    dep = new Dependency(
      'path/to/module'           # dependency name
      'someRootModule.js'        # the module that has this dependenecy
      ['path/to/module.coffee']  # module files in bundle
    )
    expect(dep.name relativeType:'bundle').to.equal 'path/to/module'
    expect(dep.name relativeType:'file').to.equal './path/to/module'

  it "converts simple paths from fileRelative to bundleRelative", ->
    dep = new Dependency(
      './path/to/module'           # dependency name
      'someRootModule.js'        # the module that has this dependenecy
      ['path/to/module.coffee']  # module files in bundle
    )
    expect(dep.name relativeType:'bundle').to.equal 'path/to/module'
    expect(dep.name relativeType:'file').to.equal './path/to/module'

  it "split plugin, extension, resourceName & recostruct as String", ->
    dep = new Dependency 'node!somedir/dep.js'

    expect(dep.pluginName).to.equal 'node'
    expect(dep.extname).to.equal '.js'
    expect(dep.name()).to.equal 'node!somedir/dep.js'
    expect(dep.toString()).to.equal dep.name()
    expect(dep.name plugin:no, ext:no ).to.equal 'somedir/dep'

  it "uses modyleName & bundleFiles to convert from fileRelative to bundleRelative", ->
    dep = new Dependency(
      '../../../rootdir/dep'            # dependency name
      'path/from/bundleroot/modyleName.js'  # the module that has this dependenecy
      ['rootdir/dep.js']                # module files in bundle
    )
    expect(dep.extname).to.equal undefined
    expect(dep.pluginName).to.equal undefined
    expect(dep.name relativeType:'bundle').to.equal 'rootdir/dep'
    expect(dep.name relativeType:'file').to.equal '../../../rootdir/dep'
    expect(dep.toString()).to.equal '../../../rootdir/dep'


  it "uses modyleName & bundleFiles to convert from bundleRelative to fileRelative", ->
    dep = new Dependency(
      'path/from/bundleroot/to/some/nested/module'           # dependency name
      'path/from/bundleroot/modyleName.js'                       # the module that has this dependenecy
      ['path/from/bundleroot/to/some/nested/module.coffee']  # module files in bundle
    )
    expect(dep.name relativeType:'bundle').to.equal 'path/from/bundleroot/to/some/nested/module'
    expect(dep.name relativeType:'file').to.equal './to/some/nested/module'
    expect(dep.toString()).to.equal './to/some/nested/module'

describe "Dependency isEquals(),", ->
  dep1 = new Dependency '../../../rootdir/dep.js', 'path/from/bundleroot/modyleName.js', ['rootdir/dep.js']
  dep2 = new Dependency 'rootdir/dep', 'path/from/bundleroot/modyleName.js', ['rootdir/dep.js']
  dep3 = new Dependency 'node!rootdir/dep', 'path/from/bundleroot/modyleName.js', ['rootdir/dep.js']

  it "With `Dependency` as param", ->
    expect(dep1.isEqual dep2).to.be.true
    expect(dep2.isEqual dep1).to.be.true
  it "false when plugin differs", ->
    expect(dep1.isEqual dep3).to.be.false

  describe "With `String` as param", ->
    describe " with `bundleRelative` format ", ->
      it "with .js extensions", ->
        expect(dep1.isEqual 'rootdir/dep.js').to.be.true
        expect(dep2.isEqual 'rootdir/dep.js').to.be.true
      it "plugins still matter", ->
        expect(dep3.isEqual 'node!rootdir/dep.js').to.be.true
      it "without extensions", ->
        expect(dep1.isEqual 'rootdir/dep').to.be.true
        expect(dep2.isEqual 'rootdir/dep').to.be.true
        it "plugins still matter", ->
          expect(dep3.isEqual 'node!rootdir/dep').to.be.true

    describe " with `fileRelative` format ", ->
      it "with .js extensions", ->
        expect(dep1.isEqual '../../../rootdir/dep.js').to.be.true
        expect(dep2.isEqual '../../../rootdir/dep.js').to.be.true
      it "plugins still matter", ->
        expect(dep3.isEqual 'node!../../../rootdir/dep.js').to.be.true
      it "without extensions", ->
        expect(dep1.isEqual '../../../rootdir/dep').to.be.true
        expect(dep2.isEqual '../../../rootdir/dep').to.be.true
        it "plugins still matter", ->
          expect(dep3.isEqual 'node!../../../rootdir/dep').to.be.true

    it " with false extensions", ->
      expect(dep1.isEqual 'rootdir/dep.txt').to.be.false
      expect(dep2.isEqual '../../../rootdir/dep.txt').to.be.false

    it " looking for one in an array", ->
      deps = [dep1, dep2, dep3]
      expect(
        _.any deps, (dep)-> dep.isEqual 'rootdir/dep.js'
      ).to.be.true

describe "Dependency - resolving many", ->

  it "resolves bundle&file relative, finds external, global, notFound, webRootMap", ->

    modyleName = 'actions/greet.js'

    bundleFiles = [
       'main.js'
       'actions/greet.js'
       'calc/add.js'
       'calc/multiply.js'
       'calc/more/powerof.js'
       'data/numbers.js'
       'data/messages/bye.js'
       'data/messages/hello.coffee'
      ]

    strDependencies = [
      'underscore'                  # should add to 'global'
      'data/messages/hello.js'      # should remove .js, since its in bundleFiles
      '../data/messages/bye'        # should normalize in bundleRelative
      '../lame/dir.js'              # should add to 'notFoundInBundle', add as is
      '../../some/external/lib.js'  # should add to 'external', add as is
      '/assets/jpuery-max'          # should add to web root
    ]

    deps = []
    for dep in strDependencies
      deps.push new Dependency dep, modyleName, bundleFiles

    fileRelative = ( d.name relativeType:'file' for d in deps )
    bundleRelative = ( d.name relativeType:'bundle' for d in deps)
    global = ( d.toString() for d in deps when d.isGlobal())
    external = ( d.toString() for d in deps when d.isExternal())
    notFoundInBundle = ( d.toString() for d in deps when d.isNotFoundInBundle() )
    webRootMap = ( d.toString() for d in deps when d.isWebRootMap() )

    expect({bundleRelative, fileRelative, global, external, notFoundInBundle, webRootMap}).to.deep.equal
      bundleRelative: [ # @todo: with .js removed or not ?
        'underscore'                 # global lib
        'data/messages/hello'        # .js is removed since its in bundleFiles
        'data/messages/bye'          # as bundleRelative
        'lame/dir.js'                # as bundleRelative, with .js since its NOT in bundleFiles
        '../../some/external/lib.js' # exactly as is
        '/assets/jpuery-max'
      ]
      fileRelative: [ # @todo: with .js removed or not ?
        'underscore'                 # global lib, as is
        '../data/messages/hello'  # converted fileRelative
        '../data/messages/bye'
        '../lame/dir.js'
        '../../some/external/lib.js' #exactly as is
        '/assets/jpuery-max'
      ]
      global: [ 'underscore' ]
      external:[ '../../some/external/lib.js' ]
      notFoundInBundle:[ '../lame/dir.js' ] #exactly as is
      webRootMap: ['/assets/jpuery-max']

