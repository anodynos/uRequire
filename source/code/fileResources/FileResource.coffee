# externals
_ = require 'lodash'
fs = require 'fs'
wrench = require 'wrench'
_B = require 'uberscore'
l = new _B.Logger 'urequire/fileResources/FileResource'

# uRequire
BundleFile = require './BundleFile'
upath = require '../paths/upath'
UError = require '../utils/UError'

###
  Represents any file resource, whose source/content we dont read (but subclasses do).
  The `convert()` of the ResourceConverter should handle the file contents - for example fs.read it, require() it or spawn an external program.

  Nevertheless, it can `save()` its `converted` content (if any).

  Each time it `@refresh()`es, if super is changed (BundleFile's fileStats), it runs `runResourceConverters`:
      - calls `converter.convert()` and stores result as @converted
      - calls `converter.convFilename()` and stores result as @dstFilename
    otherwise it returns `@hasChanged = false`

  When `save()` is called (with no args) it outputs `@converted` to `@dstFilepath`.
###
class FileResource extends BundleFile
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p; null

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
      if @constructor is FileResource # run only for this class, otherwise let subclasses decide wheather to run ResourceConverters.
        return @hasChanged = @runResourceConverters (conv)-> not conv.isAfterTemplate
      else true

  read: (filepath=@srcFilepath)->
    try
      fs.readFileSync filepath, 'utf-8'
    catch err
      @hasErrors = true
      throw new UError "Error reading file '#{filepath}'", nested:err

  save: (outputFilename=@dstFilepath, content=@converted)->
    @::save outputFilename, content

  @save: (outputFilename, content, options='utf-8')->
    l.debug("Save file '#{outputFilename}'") if l.deb 20

    throw new UError "Error saving - no outputFilename" if !outputFilename
    throw new UError "Error saving - no content" if !content

    try
      if not fs.existsSync upath.dirname(outputFilename)
        l.verbose "Creating directory '#{upath.dirname outputFilename}'"
        wrench.mkdirSyncRecursive upath.dirname(outputFilename)

      fs.writeFileSync outputFilename, content, options
      if @watch #if debug
        l.verbose "Saved file '#{outputFilename}'"
    catch err
      l.err uerr = "Can't save '#{outputFilename}'", err
      throw new UError uerr, nested:err

  # go through all converters, converting with each one
  # Note: it acts on @converted & @dstFilename, leaving them in a new state
  runResourceConverters: (convFilter=->true) ->
    # @todo: rename  @converters to @ResourceConverters
    for converter in @converters when \
        convFilter(converter) # filter
        # silence higher ResourceConverters, (eg dont run 'coffee-script' (a module converter) - if @ is NOT a Module
        #(!converter.clazz or (@ instanceof converter.clazz))

      if _.isFunction converter.convert
        l.debug "Converting #{@constructor?.name} '#{@dstFilename}' with '#{converter.name}'..." if l.deb 70

        # convert @filename to @dstFilename (i.e the previous @dstFilename from converter.dstFilename(), intially @filename)
        if _.isFunction converter.convFilename
          @dstFilename = converter.convFilename @dstFilename, @srcFilename, @
          l.debug "... @dstFilename is '#{@dstFilename}'" if l.deb 95

        try
          @converted = converter.convert.call @, @ # store return value at @converted
                                                   # and if its non-empty String, save it at @dstFilepath
          @hasChanged = true
        catch err
          @hasErrors = true
          l.err uerr = "Error converting #{@constructor?.name} '#{@filename}' with converter '#{converter?.name}'.", err
          if not @bundle.build.continue
            throw new UError uerr, {nested:err, stack:true}

    @hasErrors = false
    return @hasChanged

  reset:-> super; delete @converted

module.exports = FileResource