# externals
_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
l = new _B.Logger 'urequire/TextResource'

# uRequire
FileResource = require './FileResource'
UError = require '../utils/UError'

###
  Represents any *textual/utf-8* resource (including but not limited to js-convertable code).

  Each time it `@refresh()`es,
    if `@source` (content) in file is changed, its passed through all @converters:
      - stores `converter.convert()` result as @converted
      - stores `converter.dstFilename(@srcFilename)` result as @dstFilename
    otherwise it returns `@hasChanged = false`
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

  reset:-> super; delete @source

module.exports = TextResource

