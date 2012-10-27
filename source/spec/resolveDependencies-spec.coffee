console.log '\nresolveDependencies-test started'

chai = require 'chai'
resolveDependencies = require "../code/resolveDependencies"

assert = chai.assert
expect = chai.expect

describe "resolveDependencies ", ->

  it "resolves bundle&file relative, finds external, global, notFound, webRoot", ->
    #
    # test data
    #
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

    dependencies = [
      'underscore'                  # should add to 'global'
      'data/messages/hello.js'      # should remove .js, since dep it's in the bundleFiles
      '../data/messages/bye'        # should normalize in bundleRelative
      '../lame/dir.js'                 # should add to 'notFoundInBundle', add as is
      '../../some/external/lib.js'     # should add to 'external', add as is
      '/assets/jpuery-max'          # should add to web root
    ]

    # #########################################
    # expected outcome
    # ##########################################
    expectedDeps =
      bundleRelative: [
        'underscore'          # global lib
        'data/messages/hello' # .js is removed
        'data/messages/bye'   # normalized
        '../lame/dir.js'      # exactly as is
        '../../some/external/lib.js' #exactly as is
        '/assets/jpuery-max'
      ]
      fileRelative: [
        'underscore'              # global lib, as is
        '../data/messages/hello'  # fileRelative, with .js is removed
        '../data/messages/bye'
        '../lame/dir.js'
        '../../some/external/lib.js' #exactly as is
        '/assets/jpuery-max'
      ]
      global: [ 'underscore' ]
      external:[ '../../some/external/lib.js' ]
      notFoundInBundle:[ '../lame/dir.js' ] #exactly as is
      webRoot: ['/assets/jpuery-max']

    resDeps = resolveDependencies modyle, bundleFiles, dependencies
    # console.log '\n', resDeps, '\n'
    expect(resDeps).to.deep.equal expectedDeps





