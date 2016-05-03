fs = require('fs')
upath = require 'upath'

NodeRequirer = require "../../code/NodeRequirer"
Dependency = require "../../code/fileResources/Dependency"

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

nr = new NodeRequirer moduleNameBR, module, require, dirname, webRootMap

describe "NodeRequirer:", ->

  describe "basics:", ->

    it "identifies path", ->
      equal nr.path, upath.normalize "#{__dirname}/"

    it "identifies webRootMap", ->
      equal nr.webRoot, upath.normalize "#{__dirname}/#{webRootMap}"

    it "loads 'requirejs.config.json' from path", ->
      deepEqual nr.getRequireJSConfig(), rjsconf

    it "nodejs require-mock called with correct module path", ->
      path = ''
      nr.nodeRequire = (m) -> path = m
      nr.require 'path/fromBundleRoot/to/anotherModule'

      equal path, upath.normalize "#{__dirname}/path/fromBundleRoot/to/anotherModule"

    describe "resolves Dependency paths:", ->
      it "local-looking Dependency", ->
        deepEqual nr.resolvePaths(new Dependency 'underscore', path:moduleNameBR),
          ['underscore', upath.normalize "#{__dirname}/underscore"]

      it "bundleRelative Dependency", ->
        depStr = 'some/pathTo/depName'
        deepEqual nr.resolvePaths(new Dependency depStr, path:moduleNameBR),
          [upath.normalize "#{__dirname}/#{depStr}"]

      it "fileRelative Dependency", ->
        deepEqual nr.resolvePaths(new Dependency './rel/pathTo/depName', path:moduleNameBR),
          [ upath.normalize "#{__dirname}/#{upath.dirname moduleNameBR}/rel/pathTo/depName" ]

      it "requirejs config {paths:..} Dependency", ->
        deepEqual nr.resolvePaths(new Dependency 'src/depName', path:moduleNameBR),
          [upath.normalize "#{__dirname}/../../src/depName"]

  describe "NodeRequirer uses requirejs config :", ->

    it "statically stores parsed 'requirejs.config.json' for this path", ->
      deepEqual NodeRequirer::requireJSConfigs[nr.path], rjsconf

    it "identifies path, via baseUrl (relative to webRootMap)", ->
      baseUrl_webMap_relative = "/some/webRootMap/path" # inject a webRootMap-relative baseUrl on requirejs.config
      NodeRequirer::requireJSConfigs[upath.normalize __dirname + '/'].baseUrl = baseUrl_webMap_relative
      nr = new NodeRequirer moduleNameBR, module, require, dirname, webRootMap # and instantiate a new NodeRequirer

      equal nr.path, upath.normalize "#{__dirname}/#{webRootMap}/#{baseUrl_webMap_relative}/"

    it "identifies path, via baseUrl (relative to path)", ->
      baseUrl_webMap_bundleRootRelative = "../some/other/path" # inject a webRootMap-relative baseUrl on requirejs.config
      NodeRequirer::requireJSConfigs[upath.normalize __dirname + '/'].baseUrl = baseUrl_webMap_bundleRootRelative
      nr = new NodeRequirer moduleNameBR, module, require, dirname, webRootMap # and instantiate a new NodeRequirer

      equal nr.path, upath.normalize "#{__dirname}/#{baseUrl_webMap_bundleRootRelative}/"
