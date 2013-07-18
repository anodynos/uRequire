_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
l = new _B.Logger 'urequire/process/Build'

# uRequire
DependenciesReporter = require './../utils/DependenciesReporter'
uRequireConfigMasterDefaults = require '../config/uRequireConfigMasterDefaults'
UError = require '../utils/UError'
TextResource = require '../fileResources/TextResource'

module.exports =

class Build
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor: ->@_constructor.apply @, arguments

  _constructor: (buildCfg)->
    _.extend @, buildCfg

    @out = TextResource.save unless @out #todo: check 'out' - what's out there ?

    @interestingDepTypes =
      if @verbose
        DependenciesReporter::reportedDepTypes
      else
        idp = ['notFoundInBundle', 'untrustedRequireDeps', 'untrustedAsyncDeps']
        if @template.name is 'combined'
          idp.push 'global'
        idp

  @templates = ['UMD', 'AMD', 'nodejs', 'combined']
