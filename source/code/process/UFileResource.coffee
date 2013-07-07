# externals
_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
l = new _B.Logger 'urequire/UFileResource'

# uRequire
UBundleFile = require './UBundleFile'
UError = require '../utils/UError'


###
  Represents any file resource, whose source/content we dont read.
  Instead the converter is responsible with dealing with the file contents (eg fs.read it, require() it or spawn an external program.

  Each time it `@refresh()`es:
    if super is changed, it runs `runResourceConverters` only for this class's instances (not subclasses.
    `converter.convert()` is called with @srcFilepath & @dstFilepath args
###
class UFileResource extends UBundleFile
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p ;null

  ###
  @param {Object} bundle The Bundle where this UFileResource belongs
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
      if @constructor is UFileResource # run only for this class, otherwise let subclasses decide wheather to run resourceConverters.
        return @hasChanged = @runResourceConverters (conv)-> not conv.isAfterTemplate
      else true

  # go through all converters, converting with each one
  # Note: it acts on @converted & @dstFilename, leaving them in a new state
  runResourceConverters: (convFilter=->true) ->
    try
      for converter in @converters when \
          convFilter(converter) and      # pass filter
          (@ instanceof converter.clazz) # silence higher resourceConverters (eg 'coffee-script' which is a module converter)

        if _.isFunction converter.convert
          l.debug "Converting #{@constructor?.name} '#{@dstFilename}' with '#{converter.name}'..." if l.deb 70

          # convert @filename to @dstFilename (i.e the previous @dstFilename from converter.dstFilename(), intially @filename)
          if _.isFunction converter.dstFilename
            @dstFilename = converter.dstFilename @dstFilename
            l.debug "... @dstFilename is '#{@dstFilename}'" if l.deb 95

          @convert converter

      @hasErrors = false
      return @hasChanged = true
    catch err
      @hasErrors = true
      l.err uerr = "Error converting #{@constructor?.name} '#{@filename}' with converter '#{converter?.name}'."
      throw new UError uerr, nested:err

  convert: (converter)-> @converted = converter.convert @srcFilepath, @dstFilepath

  reset:-> super; delete @converted

module.exports = UFileResource