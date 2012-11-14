console.log '\nDependency-test started'

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

describe "Dependency - resolving many", ->

  it "resolves bundle&file relative, finds external, global, notFound, webRoot", ->

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
    external = ( d.toString() for d in deps when not (d.isBundleBoundary() or d.isWebRoot()) )
    notFoundInBundle = (
      d.toString() for d in deps when \
        d.isBundleBoundary() and
        not (d.isFound() or d.isGlobal() )
    )
    webRoot = ( d.toString() for d in deps when d.isWebRoot() )

    # console.log {bundleRelative, fileRelative, global, external, notFoundInBundle, webRoot}

    expect({bundleRelative, fileRelative, global, external, notFoundInBundle, webRoot}).to.deep.equal
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
      webRoot: ['/assets/jpuery-max']

