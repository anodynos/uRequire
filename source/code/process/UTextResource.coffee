# externals
_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
l = new _B.Logger 'urequire/UTextResource'

# uRequire
UFileResource = require './UFileResource'
UError = require '../utils/UError'

###
  Represents any *textual/utf-8* resource (including but not limited to js-convertable code).

  Each time it `@refresh()`es,
    if `@source` (content) in file is changed, its passed through all @converters:
    - stores `converter.convert(@source)` result as @converted
    - stores `converter.dstFilename(@filename)` result as @dstFilename
###
class UTextResource extends UFileResource

  ###
    Check if source (AS IS eg js, coffee, LESS etc) has changed
    and if it has, then convert it passing throught all @converters

    @return true if there was a change (and conversions took place) and note as @hasChanged, false otherwise
  ###
  refresh: ->
    if not super
      return false # no change in parent, why should I change ?

    else #refresh only if parent says so
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

        return @hasChanged = @runResourceConverters (conv)->not conv.isAfterTemplate
      else
        l.debug "No changes in `source` of UTextResource/#{@constructor.name} '#{@filename}' " if l.deb 90
        return @hasChanged = false

  convert: (converter)-> @converted = converter.convert @converted, @dstFilename

  reset:-> super; delete @source

module.exports = UTextResource

