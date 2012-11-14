console.log '\nNodeRequirer-test started'

chai = require 'chai'
assert = chai.assert
expect = chai.expect

_ = require 'lodash'
_fs = require('fs')
upath = require '../code/paths/upath'

NodeRequirer = require "../code/NodeRequirer"

# @todo: test resolvePaths
# @todo: getRequirejs & requirejs.config paths - (inject a mock requirejs, via injected mock nodeRequire)
# @todo: test asynch `require([], callback)`


describe "NodeRequirer", ->

  # a make up module name
  modyle = 'path/fromBundleRoot/to/moduleName.js'

  # assume bundleRoot is this spec's __dirname
  # so __dirname + modyle, is the fake calling modulefile
  dirname = upath.dirname "#{__dirname}/#{modyle}"

  # a fake webRootMap
  webRootMap = '../fakeWebRoot/mapping/'

  # load & parse requirejs.config.json, *existing along spec dir!*
  rjsconf = JSON.parse _fs.readFileSync __dirname + '/' + 'requirejs.config.json', 'utf-8'

  #instantiate a single NodeRequirer
  nodeRequirer = new NodeRequirer modyle, dirname, webRootMap

  it "identifies bundleRoot", ->
    expect(nodeRequirer.bundleRoot).to.equal __dirname + '/'

  it "identifies webRoot", ->
    expect(nodeRequirer.webRoot).to.equal upath.normalize "#{__dirname}/#{webRootMap}"

  it "loads 'requirejs.config.json' from bundleRoot", ->
    expect(nodeRequirer.getRequireJSConfig()).to.deep.equal rjsconf

  it "statically stores parsed 'requirejs.config.json' for this bundleRoot", ->
    expect(NodeRequirer::requireJSConfigs[nodeRequirer.bundleRoot]).to.deep.equal rjsconf

  it "statically stores parsed 'requirejs.config.json' for this bundleRoot", ->
    expect(NodeRequirer::requireJSConfigs[nodeRequirer.bundleRoot]).to.deep.equal rjsconf

  it "calls node's mock-require with correct module path", ->
    modulePath = ''
    nodeRequirer.nodeRequire = (m)-> modulePath = m # works via closure cause its called in synch

    nodeRequirer.require 'path/fromBundleRoot/to/anotherModule'
    expect(modulePath).to.equal upath.normalize "#{__dirname}/path/fromBundleRoot/to/anotherModule"


  it "identifies bundleRoot, via baseUrl (relative to webRoot)", ->
    baseUrl_webMap_relative = "/some/webRoot/path" # inject a webRoot-relative baseUrl on requirejs.config
    NodeRequirer::requireJSConfigs[__dirname + '/'].baseUrl = baseUrl_webMap_relative
    nr = new NodeRequirer modyle, dirname, webRootMap # and instantiate a new NR

    expect(nr.bundleRoot).to.equal upath.normalize "#{__dirname}/#{webRootMap}/#{baseUrl_webMap_relative}/"

  it "identifies bundleRoot, via baseUrl (relative to bundleRoot)", ->
    baseUrl_webMap_bundleRootRelative = "../some/other/path" # inject a webRoot-relative baseUrl on requirejs.config
    NodeRequirer::requireJSConfigs[__dirname + '/'].baseUrl = baseUrl_webMap_bundleRootRelative
    nr = new NodeRequirer modyle, dirname, webRootMap # and instantiate a new NR

    expect(nr.bundleRoot).to.equal upath.normalize "#{__dirname}/#{baseUrl_webMap_bundleRootRelative}/"


