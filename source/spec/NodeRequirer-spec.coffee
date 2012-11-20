console.log '\nNodeRequirer-test started'

chai = require 'chai'
assert = chai.assert
expect = chai.expect

_ = require 'lodash'
_fs = require('fs')
upath = require '../code/paths/upath'

NR = require "../code/NodeRequirer"
Dependency = require "../code/Dependency"

# @todo: test asynch `require([], callback)`
# @todo: getRequirejs & requirejs.config paths - (inject a mock requirejs, via injected mock nodeRequire)

# a make up module name
modyle = 'path/fromBundleRoot/toModuleName.js'

# assume bundleRoot is this spec's __dirname
# so __dirname + modyle, is the fake calling modulefile
dirname = upath.dirname "#{__dirname}/#{modyle}"

# a fake webRootMap
webRootMap = '../fakeWebRoot/mapping/'

# load & parse requirejs.config.json, *existing along spec dir!*
rjsconf = JSON.parse _fs.readFileSync "#{__dirname}/requirejs.config.json", 'utf-8'

nr = new NR modyle, dirname, webRootMap

describe "NodeRequirer basics:", ->

  it "identifies bundleRoot", ->
    expect(nr.bundleRoot).to.equal upath.normalize "#{__dirname}/"

  it "identifies webRoot", ->
    expect(nr.webRoot).to.equal upath.normalize "#{__dirname}/#{webRootMap}"

  it "loads 'requirejs.config.json' from bundleRoot", ->
    expect(nr.getRequireJSConfig()).to.deep.equal rjsconf

  it "nodejs require-mock called with correct module path", ->
    modulePath = ''
    nr.nodeRequire = (m)-> modulePath = m # works via closure cause its called in synch
    nr.require 'path/fromBundleRoot/to/anotherModule'

    expect(modulePath).to.equal upath.normalize "#{__dirname}/path/fromBundleRoot/to/anotherModule"

  describe "resolves Dependency paths:", ->
    it "global-looking Dependency", ->
      expect(resolvedDeps = nr.resolvePaths new Dependency 'underscore', modyle).to.deep
        .equal ['underscore', upath.normalize "#{__dirname}/underscore"]

    it "bundleRelative Dependency", ->
      depStr = 'some/pathTo/depName'
      expect(nr.resolvePaths new Dependency depStr, modyle).to.deep
        .equal [upath.normalize "#{__dirname}/#{depStr}"]

    it "fileRelative Dependency", ->
      expect(nr.resolvePaths new Dependency './rel/pathTo/depName', modyle).to.deep
        .equal [upath.normalize "#{__dirname}/#{upath.dirname modyle}/rel/pathTo/depName"]

    it "requirejs config {paths:..} Dependency", ->
      expect(nr.resolvePaths new Dependency 'src/depName', modyle).to.deep
        .equal [upath.normalize "#{__dirname}/../../src/depName"]

describe "NodeRequirer uses requirejs config :", ->

  it "statically stores parsed 'requirejs.config.json' for this bundleRoot", ->
    expect(NR::requireJSConfigs[nr.bundleRoot]).to.deep.equal rjsconf

  it "identifies bundleRoot, via baseUrl (relative to webRoot)", ->
    baseUrl_webMap_relative = "/some/webRoot/path" # inject a webRoot-relative baseUrl on requirejs.config
    NR::requireJSConfigs[upath.normalize __dirname + '/'].baseUrl = baseUrl_webMap_relative
    nr = new NR modyle, dirname, webRootMap # and instantiate a new NR

    expect(nr.bundleRoot).to.equal upath.normalize "#{__dirname}/#{webRootMap}/#{baseUrl_webMap_relative}/"

  it "identifies bundleRoot, via baseUrl (relative to bundleRoot)", ->
    baseUrl_webMap_bundleRootRelative = "../some/other/path" # inject a webRoot-relative baseUrl on requirejs.config
    NR::requireJSConfigs[upath.normalize __dirname + '/'].baseUrl = baseUrl_webMap_bundleRootRelative
    nr = new NR modyle, dirname, webRootMap # and instantiate a new NR

    expect(nr.bundleRoot).to.equal upath.normalize "#{__dirname}/#{baseUrl_webMap_bundleRootRelative}/"

