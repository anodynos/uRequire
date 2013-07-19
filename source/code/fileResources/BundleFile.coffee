_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
l = new _B.Logger 'urequire/fileResources/BundleFile'

Build = require '../process/Build'
wrench = require "wrench"

upath = require '../paths/upath'
UError = require '../utils/UError'

###
  A dummy/base class, representing any file in the bundle
###
class BundleFile
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p ;null

  ###
    @param {Object} bundle The Bundle where this BundleFile belongs
    @param {String} filename, bundleRelative eg 'models/PersonModel.coffee'
  ###
  constructor: (@bundle, @filename)-> @dstFilename = @srcFilename # initial dst filename, assume no filename conversion

  refresh:-> #perhaps we could check for filesystem timestamp etc
    if not fs.existsSync @srcFilepath
      throw new UError "BundleFile missing '#{@srcFilepath}'"
    else
      stats = _.pick fs.statSync(@srcFilepath), statProps = ['mtime', 'size']
      if not _.isEqual stats, @fileStats
        @hasChanged = true
        @dstFilename = @srcFilename # reset to original @filename
      else
        @hasChanged = false
        l.debug "No changes in #{statProps} of file '#{@dstFilename}' " if l.deb 90

    @fileStats = stats
    return @hasChanged

  reset:-> delete @fileStats

  @property
    extname: get: -> upath.extname @filename                # original extension, eg `.js` or `.coffee`

    # alias to source @filename
    srcFilename: get: -> @filename
    srcFilepath: get: -> upath.join @bundle.path, @filename # source filename with path, eg `myproject/mybundle/mymodule.js`
    srcRealpath: get: -> "#{process.cwd()}/#{@srcFilepath}"

    # @dstFilename populated after each refresh/conversion (or a default on constructor)
    dstFilepath: get:-> if @bundle.build then upath.join @bundle.build.dstPath, @dstFilename # destination filename with build.dstPath, eg `myBuildProject/mybundle/mymodule.js`
    dstRealpath: get:-> "#{process.cwd()}/#{@dstFilepath}"

    dstExists: get:-> if @dstFilepath then fs.existsSync @dstFilepath

    # sourceMap information
    # Currentyl usefull only for coffee/livescript/typescript conversion as TextResource (i.e .js), NOT Modules
    # @todo(3, 3, 8): implement source map for Modules that havetemplate conversion!
    #
    # @todo: spec it
    # With {srcFilepath: 'source/code/glink.coffee', dstFilepath: 'build/code/glink.js'}
    # sourceMapInfo = {file:"glink.js", sourceRoot:"../../source/code", sources:["glink.coffee"], sourceMappingURL="..."}
    sourceMapInfo: get: ->
      file: upath.basename @dstFilepath
      sourceRoot: upath.dirname upath.relative(upath.dirname(@dstFilepath), @srcFilepath)
      sources: [ upath.basename @srcFilepath ]
      sourceMappingURL: """
        /*
        //@ sourceMappingURL=#{upath.basename @dstFilepath}.map
        */
      """


  # Helpers: available to bundleFile instance (passed as convert() this & 1st argument) for convenience
  # They are defined as static, with an instance shortcut *with sane defaults*
  # They are all sync
  
  # Without params it copies (binary) the source file from `bundle.path`
  # to `build.dstPath` - otherwise it respects the params
  copy: (srcFile=@srcFilepath, dstFile=(upath.join @bundle.build.dstPath, @srcFilename))-> 
    BundleFile.copy srcFile, dstFile

  # copyFile helper (missing from fs & wrench)
  # @return true if copy was made, false if skipped (eg. same file)
  # copyFileSync based on http://procbits.com/2011/11/15/synchronous-file-copy-in-node-js/) @todo: improve !
  @copy: (srcFile, dstFile, overwrite='DUMMY')-> # @todo: overwrite: 'olderOrSizeDiff' (current default behavior) or 'all', 'none', 'older', 'sizeDiff'
    if not fs.existsSync srcFile
      throw new UError "copy source file missing '#{srcFile}'"
    else
      srcStats = _.pick fs.statSync(srcFile), ['atime', 'mtime', 'size']
      if fs.existsSync dstFile
        compStats = ['mtime', 'size']
        if _.isEqual (_.pick srcStats, compStats), (_.pick fs.statSync(dstFile), compStats)
          l.debug("NOT copying same src & dst files: srcFile='#{srcFile}', dstFile='#{dstFile}'") if l.deb 80
          return false

    l.debug("copy {src='#{srcFile}', dst='#{dstFile}'}") if l.deb 40
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
      l.err uerr = "copy from '#{srcFile}' to '#{dstFile}'", err
      throw new UError uerr, nested:err

  # helper - uncaching require
  # based on http://stackoverflow.com/questions/9210542/node-js-require-cache-possible-to-invalidate
  # Removes a nodejs module from the cache
  requireUncached: (moduleName)-> BundleFile.requireUncached moduleName
  @requireUncached: (moduleName) ->
    # Runs over the cache to search for all the cached nodejs modules files
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

    # Run over the cache looking for the files loaded by the specified module name
    searchCache moduleName, (mod)-> delete require.cache[mod.id]
    require moduleName

module.exports = BundleFile
