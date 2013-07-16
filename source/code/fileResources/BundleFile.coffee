_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
l = new _B.Logger 'urequire/BundleFile'

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
    # source filename with path, eg `myproject/mybundle/mymodule.js`
    srcFilepath: get: -> upath.join @bundle.path, @filename

    # @dstFilename populated after each refresh/conversion (or a default on constructor)

    # destination filename with build.dstPath, eg `myBuildProject/mybundle/mymodule.js`
    dstFilepath: get:-> if @bundle.build then upath.join @bundle.build.dstPath, @dstFilename

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

module.exports = BundleFile
