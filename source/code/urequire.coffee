exports.VERSION = if VERSION? then VERSION else '{NO_VERSION}' # 'VERSION' injected by urequire-rc-inject-version

When = require './promises/whenFull'
fs = require 'fsp'

_.mixin require('underscore.string').exports()

require 'coffee-script/register'

Object.defineProperties exports, # lazily export

  # used by UMD-transformed modules when running on nodejs
  NodeRequirer: get:-> require './NodeRequirer'

  #some bonus usefull stuff for `afterBuild`-ers
  upath: get:-> require "upath"
  umatch: get:-> require 'umatch'

  # below, just for reference
  Bundle: get:-> require "./process/Bundle"
  Build: get:-> require "./process/Build"
  Module: get:-> require "./fileResources/Module"

  # our main "processor"
  BundleBuilder: get:-> require "./process/BundleBuilder"

  BBExecuted: get:-> BBExecuted
  BBCreated: get:-> BBCreated


_.each ['CodeMerger', 'isEqualCode', 'isLikeCode', 'replaceCode', 'toAST', 'toCode'], (codeUtil)->
  Object.defineProperty exports, codeUtil, get: -> require './codeUtils/' + codeUtil

BBExecuted = []
BBCreated = []

_.extend exports,

  addBBCreated: (bb)->
    if bb.build.target and exports.findBBCreated(bb.build.target)
      throw new UError "Can't have two BundleBuilders with the same `target` '#{bb.build.target}'"
    BBCreated.push bb

  findBBCreated: (target)->
    _.find BBCreated, (bb)-> bb.build.target is target

  addBBExecuted:  (bb)->
    _.pull BBExecuted, bb # mutate existing array
    BBExecuted.push bb

  findBBExecutedLast: (target)->
    if _.isUndefined(target) or _.isNull(target)
      _.last BBExecuted
    else
      if _.isString target
        _.findLast BBExecuted, (bb)-> bb.build.target is target
      else
        throw new Error "urequire: findBBExecutedLast() unknown parameter type `#{_B.type target}`, target argument = #{target}"

  findBBExecutedBefore: (bbOrTarget)->
    if _.isUndefined(bbOrTarget) or _.isNull(bbOrTarget)
      _.last BBExecuted
    else
      if _.isString bbOrTarget
        li = _.findLastIndex BBExecuted, (bb)-> bb.build.target is bbOrTarget
      else
        if bbOrTarget instanceof require("./process/BundleBuilder")
          li = _.lastIndexOf BBExecuted, bbOrTarget
        else
          throw new Error "urequire: findBBExecutedBefore() unknown parameter type `#{_B.type bbOrTarget}`, bbOrTarget argument = #{bbOrTarget}"

      if li >= 1
        BBExecuted[li-1]
      else
        null

blendConfigs = exports.blendConfigs = require './config/blendConfigs'
for b in ['dependenciesBindingsBlender', 'templateBlender', 'shimBlender', 'watchBlender']
  exports[b] = blendConfigs[b]
