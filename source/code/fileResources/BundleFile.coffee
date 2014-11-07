_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/BundleFile'

fs = require 'fs'
mkdirp = require "mkdirp"
When = require 'when'

upath = require 'upath'

# urequire
UError = require '../utils/UError'
isTrueOrFileInSpecs = require '../config/isTrueOrFileInSpecs'
pathRelative = '../paths/pathRelative'

###
  Represents any file in the bundle (that matched `bundle.filez`)
###
class BundleFile

  # @todo: infer 'booleanOrFilespecs' from blendConfigs (with 'arraysConcatOrOverwrite' BlenderBehavior ?)
  for bof in ['clean', 'deleteErrored']
    do (bof)->
      Object.defineProperty BundleFile::, 'is'+ _.capitalize(bof),
        get: -> isTrueOrFileInSpecs @bundle?.build?[bof], @dstFilename

  ###
    `data` has
    * bundle this BundleFile belongs
    * srcFilename {String} bundleRelative eg 'models/PersonModel.coffee'
  ###
  constructor: (data)->
    _.extend @, data
    @dstFilename = @srcFilename # initial dstfilename, assume no filename conversion

  refresh: When.lift -> # check for filesystem timestamp etc
    if not @srcExists
      throw new UError "BundleFile missing '#{@srcFilepath}'"
    else
      stats = _.pick fs.statSync(@srcFilepath), statProps = ['mtime', 'size']
      if not _.isEqual stats, @fileStats
        @fileStats = stats
        @hasChanged = true
      else
        l.verbose "No changes in #{l.prettify statProps} of file '#{@srcFilename}'"
        @hasChanged = false

  reset:->
    delete @fileStats
    delete @hasErrors
    @dstFilename = @srcFilename

  clean: ()->
    filenames = @dstFilenamesSaved or [ @dstFilename ]
    for fname in _.map(filenames, (f)=> upath.join @dstPath, f)
      if not fs.existsSync fname
        l.deb 30, "clean: Not existing file '#{fname}' - cant delete!."
      else
        l.verbose "clean: Deleting file: #{fname}"
        try
          fs.unlinkSync fname
        catch err
          l.er "clean: Cant delete file '#{fname}'.", err

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

    # paths
    pathToRoot: get:-> pathRelative upath.dirname(@path), "/", { assumeRoot:true }

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

  # Without params it copies (binary) the source file from `bundle.path`
  # to `build.dstPath`
  copy: (srcFilename=@srcFilename, dstFilename=@dstFilename)->
    BundleFile.copy upath.join(@bundle?.path or '', srcFilename),
                    upath.join(@bundle?.build?.dstPath or '', dstFilename)

  # todo: use `fs-extra` instead
  # copyFile helper (missing from fs)
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

      if not fs.existsSync(dstFileDirname = upath.dirname dstFile)
        l.verbose "copy: Creating directory #{dstFileDirname}"
        mkdirp.sync dstFileDirname

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

  @requireClean: require "require-clean"

  #shortcut as instance var
  requireClean: (name=@srcRealpath)-> BundleFile.requireClean(name)

  inspect: ->
    inspectText = " #{@constructor.name} : '#{@dstFilename}' "
    inspectText += '\u001b[32m(hasChanged)' if @hasChanged
    inspectText += '\u001b[31m(hasErrors)' if @hasErrors
    inspectText

module.exports = BundleFile

_.extend module.exports.prototype, {l, _, _B}