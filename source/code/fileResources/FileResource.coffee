# externals
_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
l = new _B.Logger 'urequire/FileResource'

# uRequire
BundleFile = require './BundleFile'
UError = require '../utils/UError'


###
  Represents any file resource, whose source/content we dont read (but subclasses do).
  The `convert()` of the resource converter on FileResource should handle the file contents - for example fs.read it, require() it or spawn an external program.

  Each time it `@refresh()`es:
    if super is changed, it runs `runResourceConverters`.
    NOTE:
      It only runs converters compatible for this instance's clazz
      Eg if @ instanceof FileResource, then 'coffee-script' which is a module converter will not run.
###
class FileResource extends BundleFile
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p ;null

  ###
  @param {Object} bundle The Bundle where this FileResource belongs
  @param {String} filename, bundleRelative eg 'models/PersonModel.coffee'
  @param {Array<?>} converters The converters (bundle.resources) that matched this filename & are used in turn to convert, each time we `refresh()`
  ###
  constructor: (@bundle, @filename, @converters)-> super

  ###
    Check if source (AS IS eg js, coffee, LESS etc) has changed
    and convert it passing throught all @converters

    @return true if there was a change (and convertions took place) and note as @hasChanged
            false otherwise
  ###
  refresh: ->
    if not super
      return false # no change in parent, why should I change ?
    else
      if @constructor is FileResource # run only for this class, otherwise let subclasses decide wheather to run resourceConverters.
        return @hasChanged = @runResourceConverters (conv)-> not conv.isAfterTemplate
      else true

  # go through all converters, converting with each one
  # Note: it acts on @converted & @dstFilename, leaving them in a new state
  runResourceConverters: (convFilter=->true) ->
    # @todo: rename  @converters to @resourceConverters
    for converter in @converters when \
              convFilter(converter) and       # filter and silence higher resourceConverters
              (!converter.clazz or (@ instanceof converter.clazz))  # (eg dont run 'coffee-script' (a module converter) - if @ is NOT a Module

      if _.isFunction converter.convert
        l.debug "Converting #{@constructor?.name} '#{@dstFilename}' with '#{converter.name}'..." if l.deb 70

        # convert @filename to @dstFilename (i.e the previous @dstFilename from converter.dstFilename(), intially @filename)
        if _.isFunction converter.dstFilename
          @dstFilename = converter.dstFilename @dstFilename
          l.debug "... @dstFilename is '#{@dstFilename}'" if l.deb 95

        try
          @converted = @convert converter # Although we dont have a @source, the `resourceConverter.convert` might
                                          # return some `converted` content - we store it at @converted
                                          # if @converted isnt falsy, we automatically save @converted
                                          # at `build.dstPath` when there are changes @todo: save 'String' only.
          @hasChanged = true
        catch err
          @hasErrors = true
          l.err uerr = "Error converting #{@constructor?.name} '#{@filename}' with converter '#{converter?.name}'.", err
          if not @bundle.build.continue
            throw new UError uerr, {nested:err, stack:true}

    @hasErrors = false
    return @hasChanged


  # convert @ using resourceConverter.convert
  # and it might return its result.
  convert: (converter)-> # we pass @ (a BundleFile/FileResource instance), with @srcFilepath, @dstFilepath, @bundle, @bundle.build etc
    converter.convert @  # as well as @source in TextResource, @moduleInfo in Module etc.

  reset:-> super; delete @converted

module.exports = FileResource