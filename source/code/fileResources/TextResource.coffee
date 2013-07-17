# externals
_ = require 'lodash'
fs = require 'fs'
wrench = require 'wrench'
_B = require 'uberscore'
l = new _B.Logger 'urequire/TextResource'

# uRequire
FileResource = require './FileResource'
UError = require '../utils/UError'
upath = require '../paths/upath'

###
  Represents a FileResource that is any *textual/utf-8* resource (including but not limited to js-convertable code).

  It knows how to `refresh()` its `source`, `save()` its `converted` content and `reset`:

  Each time it `@refresh()`es,
    if `@source` (content) in srcFile is changed, its passed through all @converters:
      - stores `converter.convert()` result as @converted
      - stores `converter.dstFilename(@srcFilename)` result as @dstFilename
    otherwise it returns `@hasChanged = false`

  When `save()` is called (with no args) it outputs `converted` to `dstFilepath`.
###
class TextResource extends FileResource

  ###
    Check if source (AS IS eg js, coffee, LESS etc) has changed
    and if it has, then convert it passing throught all @converters

    @return true if there was a change (and conversions took place) and note as @hasChanged, false otherwise
  ###
  refresh: ->
    if not super
      return false # no change in parent, why should I change ?

    else # refresh only if parent says so
      source = undefined
      try
        source = fs.readFileSync @srcFilepath, 'utf-8'
      catch err
        @hasErrors = true
        throw new UError "Error reading file '#{@srcFilepath}'", nested:err

      if source and (@source isnt source)
        # go through all converters, converting source & filename in turn
        @source = @converted = source
        @dstFilename = @filename

        return @hasChanged = @runResourceConverters (conv)->not conv.isAfterTemplate # only 'isAfterTemplate:false' aren't a module converted with template
      else
        l.debug "No changes in `source` of TextResource/#{@constructor.name} '#{@filename}' " if l.deb 90
        return @hasChanged = false

  save: (outputFilename=@dstFilepath, content=@converted)->
    @::save outputFilename, content

  @save: (outputFilename, content)-> # @todo:1 make private ?
    l.debug("Save file '#{outputFilename}'") if l.deb 20
    try
      if not fs.existsSync upath.dirname(outputFilename)
        l.verbose "Creating directory '#{upath.dirname outputFilename}'"
        wrench.mkdirSyncRecursive upath.dirname(outputFilename)

      fs.writeFileSync outputFilename, content, 'utf-8'
      if @watch #if debug
        l.verbose "Saved file '#{outputFilename}'"
    catch err
      l.err uerr = "Can't save '#{outputFilename}'", err
      throw new UError uerr, nested:err

  reset:-> super; delete @source

module.exports = TextResource

