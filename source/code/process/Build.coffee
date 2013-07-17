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

  # helpers - @todo: move them / make them available to bundleFile instance (passed as convert() argument)?
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
  # @return true if copy was made, false if skipped (eg. same file)
  # @todo: improve (based on http://procbits.com/2011/11/15/synchronous-file-copy-in-node-js/)
  @copyFileSync: (srcFile, dstFile) -> # @todo: overwrite: 'olderdiff' (current default) or 'all', 'none', 'older', 'diff'
    if not fs.existsSync srcFile
      throw new UError "copyFileSync source file missing '#{srcFile}'"
    else
      srcStats = _.pick fs.statSync(srcFile), ['atime', 'mtime', 'size']
      if fs.existsSync dstFile
        compStats = ['mtime', 'size']
        if _.isEqual (_.pick srcStats, compStats), (_.pick fs.statSync(dstFile), compStats)
          l.debug("copyFileSync same src & dst files - not copying : srcFile='#{srcFile}', dstFile='#{dstFile}'") if l.deb 80
          return false

    l.debug("copyFileSync {src='#{srcFile}', dst='#{dstFile}'}") if l.deb 40
    try
      BUF_LENGTH = 64*1024
      buff = new Buffer(BUF_LENGTH)
      fdr = fs.openSync(srcFile, 'r')

      if not (fs.existsSync upath.dirname(dstFile))
        l.verbose "Creating directory #{upath.dirname dstFile}"
        wrench.mkdirSyncRecursive upath.dirname(dstFile)

      fdw = fs.openSync(dstFile, 'w')
      bytesRead = 1
      pos = 0
      while bytesRead > 0
        bytesRead = fs.readSync fdr, buff, 0, BUF_LENGTH, pos
        fs.writeSync fdw, buff, 0, bytesRead
        pos += bytesRead
      fs.closeSync fdr
      fs.closeSync fdw

      fs.utimesSync dstFile, srcStats.atime, srcStats.mtime
      return true
    catch err
      l.err uerr = "copyFileSync from '#{srcFile}' to '#{dstFile}'", err
      throw new UError uerr, nested:err

  # helper - uncaching require
  # http://stackoverflow.com/questions/9210542/node-js-require-cache-possible-to-invalidate
  # Removes a nodejs module from the cache
  uncache: (moduleName) ->
    # Run over the cache looking for the files loaded by the specified module name
    searchCache moduleName, (mod) ->
      delete require.cache[mod.id]

  #Runs over the cache to search for all the cached nodejs modules files
  searchCache = (moduleName, callback) ->
    # Resolve the module identified by the specified name
    mod = require.resolve(moduleName)
    # Check if the module has been resolved and found within the cache
    if mod and ((mod = require.cache[mod]) isnt undefined)
      # Recursively go over the results
      (run = (mod) ->
        # Go over each of the module's children and run over it
        mod.children.forEach (child)-> run child
        # Call the specified callback providing the found module
        callback mod
      ) mod