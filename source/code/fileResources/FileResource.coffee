# externals
_ = require 'lodash'
fs = require 'fs'
mkdirp = require 'mkdirp'
_B = require 'uberscore'
l = new _B.Logger 'urequire/fileResources/FileResource'

# uRequire
BundleFile = require './BundleFile'
upath = require '../paths/upath'
UError = require '../utils/UError'

###
  Represents any bundlefile resource, whose source/content we dont read (but subclasses do).

  The `convert()` of the ResourceConverter should handle the file contents - for example fs.read it, require() it or spawn an external program.

  Paradoxically, a FileResource
    - can `read()` its source contents (assumed utf-8 text)
    - can `save()` its `converted` content (if any).

  Each time it `@refresh()`es, if super is changed (BundleFile's fileStats), it runs `runResourceConverters`:
      - calls `converter.convert()` and stores result as @converted
      - calls `converter.convFilename()` and stores result as @dstFilename
    otherwise it returns `@hasChanged = false`

  When `save()` is called (with no args) it outputs `@converted` to `@dstFilepath`.
###
class FileResource extends BundleFile

  ###
    @data converters {Array<ResourceConverter} (bundle.resources) that matched this filename & are used in turn to convert, each time we `refresh()`
  ###

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
        return @hasChanged = @runResourceConverters (rc)-> !rc.isBeforeTemplate and !rc.isAfterTemplate
      else true

  reset:-> super; delete @converted

  # go through all Resource `converters`, converting with each one
  # Note: it acts on @converted & @dstFilename, leaving them in a new state
  runResourceConverters: (convFilter=->true) ->
    @hasErrors = false
    for resConv in @converters when convFilter(resConv)
      try
        if _.isFunction resConv.convert
          l.debug "Converting #{@constructor?.name} srcFn='#{@srcFilename}', dstFn='#{@dstFilename}' with RC='#{resConv.name}'..." if l.deb 40
          @converted = resConv.convert @ # store return value at @converted

        # convert @srcFilename to @dstFilename
        # (actually convert the previous @dstFilename -intially @srcFilename- to the new @dstFilename)
        if _.isFunction resConv.convFilename
          @dstFilename = resConv.convFilename @dstFilename, @srcFilename, @
          l.debug "... @dstFilename is '#{@dstFilename}'" if l.deb 70

        @hasChanged = true
      catch err
        @hasErrors = true
        throw new UError """
           Error converting #{@constructor?.name} '#{@srcFilename}' with resConv '#{resConv?.name}'.""", {nested:err}
      
      break if resConv.isTerminal

    return @hasChanged

  readOptions = 'utf-8' # compatible with node 0.8 #{encoding: 'utf-8', flag: 'r'}
  read: (filename=@srcFilename, options=readOptions)->
    _.defaults options, readOptions if options isnt readOptions
    filename = upath.join @bundle?.path or '', filename
    try
      fs.readFileSync filename, options
    catch err
      @hasErrors = true
      @bundle.handleError new UError "Error reading file '#{filename}'", nested:err
      undefined

  save: (filename=@dstFilename, content=@converted, options)->
    @constructor.save upath.join(@dstPath, filename), content, options

  saveOptions = 'utf-8' # compatible with node 0.8 {encoding: 'utf-8', mode: 438, flag: 'w'}
  @save: (filename, content, options=saveOptions)->
    _.defaults options, saveOptions if options isnt saveOptions
    l.debug("Saving file '#{filename}'...") if l.deb 95
    @bundle.handleError new UError "Error saving - no filename" if !filename
    @bundle.handleError new UError "Error saving - no content" if !content

    try
      if not fs.existsSync upath.dirname(filename)
        l.verbose "Creating directory '#{upath.dirname filename}'"
        mkdirp.sync upath.dirname(filename)

      fs.writeFileSync filename, content, options
      l.verbose "Saved file '#{filename}'"
      return true
    catch err
      l.er uerr = "Can't save '#{filename}'", err
      @bundle.handleError new UError uerr, nested:err

module.exports = FileResource