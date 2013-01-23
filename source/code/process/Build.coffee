_ = require 'lodash'
_B = require 'uberscore'
_fs = require 'fs'
_wrench = require 'wrench'

#Logging
Logger = require '../utils/Logger'
l = new Logger 'Build'

# uRequire
upath = require '../paths/upath'
uRequireConfigMasterDefaults = require '../config/uRequireConfigMasterDefaults'

module.exports =

class Build
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor: ->@_constructor.apply @, arguments

  _constructor: (buildCfg)->
    _.extend @, _B.deepCloneDefaults buildCfg, uRequireConfigMasterDefaults.build

    @out = Build.outputModuleToFile unless @out

  @templates = ['UMD', 'AMD', 'nodejs', 'combined']
  @moduleExtensions = ['js', 'javascript','coffee'] # 'iced', 'coco', 'ts', 'ls'

  #@todo : check @outputPath exists
  @outputModuleToFile: (modulePath, content)->
    Build.outputToFile upath.join(@outputPath, "#{modulePath}.js"), content


  @outputToFile: (outputFilename, content)-> # @todo:1 make private ?
    l.debug 5, "Writting file '#{outputFilename}' (#{content.length} chars)"
    try
      if not _fs.existsSync upath.dirname(outputFilename)
        l.verbose "Creating directory '#{upath.dirname outputFilename}'"
        _wrench.mkdirSyncRecursive upath.dirname(outputFilename)

      _fs.writeFileSync outputFilename, content, 'utf-8'
      if @watch #if debug
        l.verbose "Written file '#{outputFilename}'"
    catch err
      err.uRequire = "uRequire: error outputToFile '#{outputFilename}'"
      l.err err.uRequire
      throw err

  # copyFile helper (missing from fs & wrench)
  # @todo: improve (based on http://procbits.com/2011/11/15/synchronous-file-copy-in-node-js/)
  @copyFileSync: (srcFile, destFile) ->
    l.debug 30, "copyFileSync {src='#{srcFile}', dst='#{destFile}'"
    try
      BUF_LENGTH = 64*1024
      buff = new Buffer(BUF_LENGTH)
      fdr = _fs.openSync(srcFile, 'r')

      if not (_fs.existsSync upath.dirname(destFile))
        l.verbose "Creating directory #{upath.dirname destFile}"
        _wrench.mkdirSyncRecursive upath.dirname(destFile)

      fdw = _fs.openSync(destFile, 'w')
      bytesRead = 1
      pos = 0
      while bytesRead > 0
        bytesRead = _fs.readSync(fdr, buff, 0, BUF_LENGTH, pos)
        _fs.writeSync(fdw,buff,0,bytesRead)
        pos += bytesRead
      _fs.closeSync(fdr)
      _fs.closeSync(fdw)
    catch err
      err.uRequire = "uRequire: error copyFileSync from '#{srcFile}' to '#{destFile}'"
      l.err err.uRequire
      throw err


if Logger::debugLevel > 90
  YADC = require('YouAreDaChef').YouAreDaChef

  YADC(Build)
    .before /_constructor/, (match, buildCfg)->
      l.debug "Before '#{match}' with buildCfg = \n", _.omit(buildCfg, [])