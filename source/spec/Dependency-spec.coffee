_ = require 'lodash'

chai = require 'chai'
assert = chai.assert
expect = chai.expect

Dependency = require "../code/Dependency"

describe "Dependency", ->

  it "split plugin, extension, resourceName & recostruct as String", ->
    dep = new Dependency 'node!somedir/dep.js'

    expect(dep.pluginName).to.equal 'node'
    expect(dep.extname).to.equal '.js'
    expect(dep.bundleRelative()).to.equal 'somedir/dep.js'
    expect(dep.fileRelative()).to.equal 'somedir/dep.js'
    expect(dep.toString()).to.equal 'node!somedir/dep.js'
    expect(dep.name plugin:no, ext:no ).to.equal 'somedir/dep'

  it "uses modyle & bundleFiles to convert from fileRelative", ->
    dep = new Dependency 'node!../../../rootdir/dep', 'path/from/bundleroot/modyle.js', ['rootdir/dep.js']
    expect(dep.pluginName).to.equal 'node'
    expect(dep.extname).to.equal undefined
    expect(dep.bundleRelative()).to.equal 'rootdir/dep'
    expect(dep.fileRelative()).to.equal '../../../rootdir/dep'
    expect(dep.toString()).to.equal 'node!../../../rootdir/dep'
    expect(dep.name plugin:no, relativeType:'bundle' ).to.equal 'rootdir/dep'

describe "Dependency isEquals(),", ->
  dep1 = new Dependency '../../../rootdir/dep.js', 'path/from/bundleroot/modyle.js', ['rootdir/dep.js']
  dep2 = new Dependency 'rootdir/dep', 'path/from/bundleroot/modyle.js', ['rootdir/dep.js']
  dep3 = new Dependency 'node!rootdir/dep', 'path/from/bundleroot/modyle.js', ['rootdir/dep.js']

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

    modyle = 'actions/greet.js'

    bundleFiles = [
       'main.js'
       'actions/greet.js'
       'calc/add.js'
       'calc/multiply.js'
       'calc/more/powerof.js'
       'data/numbers.js'
       'data/messages/bye.js'
       'data/messages/hello.js'
      ]

    strDependencies = [
      'underscore'                  # should add to 'global'
      'data/messages/hello.js'      # should remove .js, since its in the bundleFiles
      '../data/messages/bye'        # should normalize in bundleRelative
      '../lame/dir.js'                 # should add to 'notFoundInBundle', add as is
      '../../some/external/lib.js'     # should add to 'external', add as is
      '/assets/jpuery-max'          # should add to web root
    ]

    deps = []
    for dep in strDependencies
      deps.push new Dependency dep, modyle, bundleFiles

    fileRelative = ( d.toString() for d in deps )

    bundleRelative = ( d.bundleRelative() for d in deps)

    global = ( d.toString() for d in deps when d.isGlobal())

    external = ( d.toString() for d in deps when not (d.isBundleBoundary() or d.isWebRootMap()) )

    notFoundInBundle = (
      d.toString() for d in deps when \
        d.isBundleBoundary() and
        not (d.isFound() or d.isGlobal() )
    )

    webRootMap = ( d.toString() for d in deps when d.isWebRootMap() )

    # console.log {bundleRelative, fileRelative, global, external, notFoundInBundle, webRootMap}

    expect({bundleRelative, fileRelative, global, external, notFoundInBundle, webRootMap}).to.deep.equal
      bundleRelative: [
        'underscore'                 # global lib
        'data/messages/hello.js'     # .js is removed
        'data/messages/bye'          # normalized
        'lame/dir.js'                # normalized
        '../../some/external/lib.js' # exactly as is
        '/assets/jpuery-max'
      ]
      fileRelative: [
        'underscore'                 # global lib, as is
        '../data/messages/hello.js'  # converted fileRelative (@todo: with .js removed or not ?)
        '../data/messages/bye'
        '../lame/dir.js'
        '../../some/external/lib.js' #exactly as is
        '/assets/jpuery-max'
      ]
      global: [ 'underscore' ]
      external:[ '../../some/external/lib.js' ]
      notFoundInBundle:[ '../lame/dir.js' ] #exactly as is
      webRootMap: ['/assets/jpuery-max']

