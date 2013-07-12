_ = require 'lodash'
fs = require 'fs'
wrench = require 'wrench'
_B = require 'uberscore'

l = new _B.Logger 'urequire/Build'

# uRequire
upath = require '../paths/upath'
DependenciesReporter = require './../utils/DependenciesReporter'
uRequireConfigMasterDefaults = require '../config/uRequireConfigMasterDefaults'
UError = require '../utils/UError'

module.exports =

class Build
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor: ->@_constructor.apply @, arguments

  _constructor: (buildCfg)->
    _.extend @, buildCfg

    @out = Build.outputToFile unless @out #todo: check 'out' - what's out there ?

    @interestingDepTypes =
      if @verbose
        DependenciesReporter::reportedDepTypes
      else
        idp = ['notFoundInBundle', 'untrustedRequireDeps', 'untrustedAsyncDeps']
        if @template.name is 'combined'
          idp.push 'global'
        idp

  @templates = ['UMD', 'AMD', 'nodejs', 'combined']

  @outputToFile: (outputFilename, content)-> # @todo:1 make private ?
    l.debug("Writting file '#{outputFilename}'") if l.deb 5
    try
      if not fs.existsSync upath.dirname(outputFilename)
        l.verbose "Creating directory '#{upath.dirname outputFilename}'"
        wrench.mkdirSyncRecursive upath.dirname(outputFilename)

      fs.writeFileSync outputFilename, content, 'utf-8'
      if @watch #if debug
        l.verbose "Written file '#{outputFilename}'"
    catch err
      l.err uerr = "Can't outputToFile '#{outputFilename}'"
      throw new UError uerr, nested:err

  # copyFile helper (missing from fs & wrench)
  # @todo: improve (based on http://procbits.com/2011/11/15/synchronous-file-copy-in-node-js/)
  @copyFileSync: (srcFile, destFile) ->
    l.debug("copyFileSync {src='#{srcFile}', dst='#{destFile}'") if l.deb 30
    try
      BUF_LENGTH = 64*1024
      buff = new Buffer(BUF_LENGTH)
      fdr = fs.openSync(srcFile, 'r')

      if not (fs.existsSync upath.dirname(destFile))
        l.verbose "Creating directory #{upath.dirname destFile}"
        wrench.mkdirSyncRecursive upath.dirname(destFile)

      fdw = fs.openSync(destFile, 'w')
      bytesRead = 1
      pos = 0
      while bytesRead > 0
        bytesRead = fs.readSync(fdr, buff, 0, BUF_LENGTH, pos)
        fs.writeSync(fdw,buff,0,bytesRead)
        pos += bytesRead
      fs.closeSync(fdr)
      fs.closeSync(fdw)
    catch err
      l.err uerr = "copyFileSync from '#{srcFile}' to '#{destFile}'"
      throw new UError uerr, nested:err


#if l.deb 90
#  YADC = require('YouAreDaChef').YouAreDaChef
#
#  YADC(Build)
#    .before /_constructor/, (match, buildCfg)->
#      l.debug("Before '#{match}' with buildCfg = \n", _.omit(buildCfg, []))