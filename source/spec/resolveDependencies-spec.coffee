console.log '\nresolveDependencies-test started'

chai = require 'chai'
resolveDependencies = require "../code/resolveDependencies"

assert = chai.assert
expect = chai.expect

describe "resolveDependencies ", ->

  it "resolve & normalize bundle, fileRelative and find external, global, notFound", ->
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
      'data/messages/hello'
      '../data/messages/bye'        # should normalize in bundleRelative
      '../lame/dir'                 # should add to 'notFoundInBundle', add as is
      '../../some/external/lib'     # should add to 'external', add as is
    ]

    #
    # expected outcome
    #
    expectedDeps =
      bundleRelative: [
        'underscore'          # global lib
        'data/messages/hello' # as is
        'data/messages/bye'   # normalized
        '../lame/dir'
        '../../some/external/lib'
      ]
      fileRelative: [
        'underscore'              # global lib, as is
        '../data/messages/hello'
        '../data/messages/bye'
        '../lame/dir'
        '../../some/external/lib'
      ]
      global: [ 'underscore' ]
      external:[ '../../some/external/lib' ]
      notFoundInBundle:[ '../lame/dir' ]

    resDeps = resolveDependencies modyle, bundleFiles, dependencies
#    console.log '\n', resDeps
    expect(resDeps).to.deep.equal expectedDeps





