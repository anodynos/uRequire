When = require 'when'
# uRequire
FileResource = require './FileResource'
ResourceConverter = require '../config/ResourceConverter'

###
  Represents a FileResource that is any *textual/utf-8* resource (including but not limited to js-convertable code).

  It knows how to `refresh()` its `source` and `reset` it:

  Each time it `@refresh()`es, if parent & `@source` (content) in source file is changed, its passed through all @converters.
###
class TextResource extends FileResource

  ###
    Check if source (AS IS eg js, coffee, LESS etc) has changed
    and if it has, then convert it passing throught all @converters

    @return true if there was a change (and conversions took place) and note as @hasChanged, false otherwise
  ###
  refresh: ->
    super.then (superRefreshed)=>
      if not superRefreshed
        false # no change in parent, why should I change ?
      else # refresh only if parent says so
        source = @read()
        if source and (@source isnt source) # go through converters, converting source & filename in turn
          @source = source
          @converted = @source
          @dstFilename = @srcFilename
          @runResourceConverters (rc)-> rc.runAt not in _.flatten [ResourceConverter.runAt_modOnly, 'afterSave']
        else
          l.debug "No changes in `source` of TextResource/#{@constructor.name} '#{@srcFilename}' " if l.deb 90
          @hasChanged = false

  reset:-> super; delete @source

module.exports = TextResource

_.extend module.exports.prototype, {l, _, _B}