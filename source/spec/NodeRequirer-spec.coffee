chai = require 'chai'
assert = chai.assert
expect = chai.expect

_ = require 'lodash'
fs = require('fs')
upath = require '../code/paths/upath'

NR = require "../code/NodeRequirer"
Dependency = require "../code/fileResources/Dependency"

# @todo: test asynch `require([], callback)`
# @todo: getRequirejs & requirejs.config paths - (inject a mock requirejs, via injected mock nodeRequire)

# a make up module name
moduleNameBR = 'path/fromBundleRoot/toModuleName.js'

# assume path is this spec's __dirname
# so __dirname + moduleNameBR, is the fake calling modulefile
dirname = upath.dirname "#{__dirname}/#{moduleNameBR}"

# a fake webRootMap
webRootMap = '../fakeWebRoot/mapping/'

# load & parse requirejs.config.json, *existing along spec dir!*
rjsconf = JSON.parse fs.readFileSync "#{__dirname}/requirejs.config.json", 'utf-8'

nr = new NR moduleNameBR, module, dirname, webRootMap

describe "NodeRequirer basics:", ->

  it "identifies path", ->
    expect(nr.path).to.equal upath.normalize "#{__dirname}/"

  it "identifies webRootMap", ->
    expect(nr.webRoot).to.equal upath.normalize "#{__dirname}/#{webRootMap}"

  it "loads 'requirejs.config.json' from path", ->
    expect(nr.getRequireJSConfig()).to.deep.equal rjsconf

  it "nodejs require-mock called with correct module path", ->
    path = ''
    nr.nodeRequire = (m)-> path = m # works via closure cause its called in synch
    nr.require 'path/fromBundleRoot/to/anotherModule'

    expect(path).to.equal upath.normalize "#{__dirname}/path/fromBundleRoot/to/anotherModule"

  describe "resolves Dependency paths:", ->
    it "global-looking Dependency", ->
      resolvedDeps = nr.resolvePaths new Dependency 'underscore', path:moduleNameBR
      for resDep in ['underscore', upath.normalize "#{__dirname}/underscore"]
        expect(resDep in resolvedDeps).to.be.true

    it "bundleRelative Dependency", ->
      depStr = 'some/pathTo/depName'
      expect(nr.resolvePaths new Dependency depStr, path:moduleNameBR).to.deep
        .equal [upath.normalize "#{__dirname}/#{depStr}"]

    it "fileRelative Dependency", ->
      expect(
        nr.resolvePaths new Dependency('./rel/pathTo/depName', path:moduleNameBR)
      ).to.deep.equal [ upath.normalize "#{__dirname}/#{upath.dirname moduleNameBR}/rel/pathTo/depName" ]

    it "requirejs config {paths:..} Dependency", ->
      expect(nr.resolvePaths new Dependency 'src/depName', path:moduleNameBR).to.deep
        .equal [upath.normalize "#{__dirname}/../../src/depName"]

describe "NodeRequirer uses requirejs config :", ->

  it "statically stores parsed 'requirejs.config.json' for this path", ->
    expect(NR::requireJSConfigs[nr.path]).to.deep.equal rjsconf

  it "identifies path, via baseUrl (relative to webRootMap)", ->
    baseUrl_webMap_relative = "/some/webRootMap/path" # inject a webRootMap-relative baseUrl on requirejs.config
    NR::requireJSConfigs[upath.normalize __dirname + '/'].baseUrl = baseUrl_webMap_relative
    nr = new NR moduleNameBR, module, dirname, webRootMap # and instantiate a new NR

    expect(nr.path).to.equal upath.normalize "#{__dirname}/#{webRootMap}/#{baseUrl_webMap_relative}/"

  it "identifies path, via baseUrl (relative to path)", ->
    baseUrl_webMap_bundleRootRelative = "../some/other/path" # inject a webRootMap-relative baseUrl on requirejs.config
    NR::requireJSConfigs[upath.normalize __dirname + '/'].baseUrl = baseUrl_webMap_bundleRootRelative
    nr = new NR moduleNameBR, module, dirname, webRootMap # and instantiate a new NR

    expect(nr.path).to.equal upath.normalize "#{__dirname}/#{baseUrl_webMap_bundleRootRelative}/"

