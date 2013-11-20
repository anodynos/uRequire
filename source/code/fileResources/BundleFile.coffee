_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
l = new _B.Logger 'urequire/fileResources/BundleFile'

Build = require '../process/Build'
wrench = require "wrench"

upath = require '../paths/upath'
UError = require '../utils/UError'

isFileInSpecs = '../config/isFileInSpecs'

###
  Represents any file in the bundle (that matched `bundle.filez`)
###
class BundleFile
  ###
    @param bundle {Object} The Bundle where this BundleFile belongs
    @param filename {String} bundleRelative eg 'models/PersonModel.coffee'
  ###
  constructor: (data)->
    _.extend @, data
    @dstFilename = @srcFilename # initial dst filename, assume no filename conversion

  refresh:-> # check for filesystem timestamp etc
    if not @srcExists
      throw new UError "BundleFile missing '#{@srcFilepath}'"
    else
      stats = _.pick fs.statSync(@srcFilepath), statProps = ['mtime', 'size']
      if not _.isEqual stats, @fileStats
        @fileStats = stats
        @hasChanged = true
      else
        @hasChanged = false
        l.debug "No changes in #{statProps} of file '#{@dstFilename}' " if l.deb 90

    @hasChanged

  reset:->
    delete @fileStats
    delete @hasErrors

  Object.defineProperties @::,
    extname: get: -> upath.extname @srcFilename                # original extension, eg `.js` or `.coffee`

    # @srcFilename: set at creation
    srcFilepath: get: -> upath.join @bundle?.path or '', @srcFilename # source filename with `bundle.path`, eg `myproject/mybundle/mymodule.js`
    srcRealpath: get: -> "#{process.cwd()}/#{@srcFilepath}"
    srcExists: get:-> fs.existsSync @srcFilepath

    # @dstFilename populated after each refresh/conversion (or a default on constructor)
    dstPath: get:-> @bundle?.build?.dstPath or ''
    dstFilepath: get:-> upath.join @dstPath, @dstFilename # destination filename with `build.dstPath`, eg `myBuildProject/mybundle/mymodule.js`
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


  # Helpers: available to bundleFile instance (passed as `convert()`) for convenience
  # They are defined as static, with an instance shortcut *with sane defaults*
  # They are all sync
#  isSrcFilenameInSpecs: (filespecs)-> isFileInSpecs @srcFilename, filespecs
#  isDstFilenameInSpecs: (filespecs)-> isFileInSpecs @dstFilename, filespecs

  # Without params it copies (binary) the source file from `bundle.path`
  # to `build.dstPath`
  copy: (srcFilename=@srcFilename, dstFilename=@srcFilename)->
    BundleFile.copy upath.join(@bundle?.path or '', srcFilename),
                    upath.join(@bundle?.build?.dstPath or '', dstFilename)

  # copyFile helper (missing from fs & wrench)
  # @return true if copy was made, false if skipped (eg. same file)
  # copyFileSync based on http://procbits.com/2011/11/15/synchronous-file-copy-in-node-js/) @todo: improve !
  @copy: (srcFile, dstFile, overwrite='DUMMY')-> # @todo: overwrite: 'olderOrSizeDiff' (current default behavior) or 'all', 'none', 'older', 'sizeDiff'
    if not fs.existsSync srcFile
      throw new UError "copy: source file missing '#{srcFile}'"
    else
      srcStats = _.pick fs.statSync(srcFile), ['atime', 'mtime', 'size']
      if fs.existsSync dstFile
        compStats = ['mtime', 'size']
        if _.isEqual (_.pick srcStats, compStats), (_.pick fs.statSync(dstFile), compStats)
          l.debug("NOT copying same: srcFile='#{srcFile}', dstFile='#{dstFile}'") if l.deb 80
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
      throw new UError "copy: Error copying from '#{srcFile}' to '#{dstFile}'", nested:err

  # helper - uncaching require
  # based on http://stackoverflow.com/questions/9210542/node-js-require-cache-possible-to-invalidate
  # Removes a nodejs module from the cache
  @requireUncached: (name) ->
    # Runs over the cache to search for all the cached nodejs modules files
    searchCache = (name, callback) ->
      # Resolve the module identified by the specified name
      mod = require.resolve(name)
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
    searchCache name, (mod)-> delete require.cache[mod.id]
    require name

  #shortcut as instance var
  requireUncached: (name=@srcRealpath)-> BundleFile.requireUncached(name)

  inspect: ->
    inspectText = " #{@constructor.name} : '#{@srcFilename}' "
    inspectText += '(hasChanged)' if @hasChanged
    inspectText += '(hasErrors)' if @hasErrors
    inspectText

module.exports = BundleFile
