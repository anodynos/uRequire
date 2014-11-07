exports.VERSION = if VERSION? then VERSION else '{NO_VERSION}' # 'VERSION' variable is added by grant:concat
_ = (_B = require 'uberscore')._

When = require './promises/whenFull'
fs = require 'fsp'

require 'coffee-script/register'

Object.defineProperties exports, # lazily export

  # used by UMD-transformed modules when running on nodejs
  NodeRequirer: get:-> require './NodeRequirer'

  #some bonus usefull stuff for `afterBuild`-ers
  upath: get:-> require "upath"
  isFileIn: get:-> require 'is_file_in'

  # below, just for reference
  Bundle: get:-> require "./process/Bundle"
  Build: get:-> require "./process/Build"
  Module: get:-> require "./fileResources/Module"

  # our main "processor"
  BundleBuilder: get:-> require "./process/BundleBuilder"

  BBExecuted: get:-> BBExecuted

BBExecuted = []

exports.addBBExecuted = (bb)->
  _.pull BBExecuted, bb # mutate existing array
  BBExecuted.push bb

exports.findBBExecutedLast = (target)->
  if _.isUndefined(target) or _.isNull(target)
    _.last BBExecuted
  else
    if _.isString target
      _.findLast BBExecuted, (bb)-> bb.build.target is target
    else
      throw new Error "urequire: findBBExecutedLast() unknown parameter type `#{_B.type target}`, target argument = #{target}"

exports.findBBExecutedBefore = (bbOrTarget)->
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