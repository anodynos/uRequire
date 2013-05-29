# externals
_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
l = new _B.Logger 'urequire/UResource'

# uRequire
upath = require '../paths/upath'
ModuleGeneratorTemplates = require '../templates/ModuleGeneratorTemplates'
ModuleManipulator = require "../moduleManipulation/ModuleManipulator"
Dependency = require "../Dependency"
BundleFile = require './BundleFile'
UError = require '../utils/UError'


###
  Represents any *textual* resource (including but not limited to js-convertable code).

  Each time it `@refresh()`es,
    if `@source` (content) in file is changed, its passed through all @converters:
    - stores .convert(@source) result as @converted
    - stores .convertFn(@filname) result as @convertedFilename
###
class UResource extends BundleFile

  ###
  @param {Object} bundle The Bundle where this URersource belongs
  @param {String} filename, bundleRelative eg 'models/PersonModel.coffee'
  @param {Array<?>} converters The converters (bundle.resources) that matched this filename & are used in turn to convert, each time we `refresh()`
  ###
  constructor: (@bundle, @filename, @converters)->

  ###
    Check if source (AS IS eg js, coffee, LESS etc) has changed
    and convert it passing throught all @converters

    @return true if there was a change (and convertions took place) and note as @hasChanged
            false otherwise
  ###
  refresh: ->
    if not super
      return false # no change in parent, why should I change ?

    else #refresh only if parent says so
      source = undefined
      try
        source = fs.readFileSync @fullPath, 'utf-8'
      catch err
        @hasErrors = true
        l.err uerr = "Error reading file '#{@fullPath}'"
        throw new UError uerr, nested:err

      try
        if source and (@source isnt source)
          # go through all converters, converting source & filename in turn
          @source = @converted = source
          @convertedFilename = @filename
          for converter in @converters
            # convert source, or better the previous @converted from convert()
            if _.isFunction converter.convert
              l.debug "Converting '#{@convertedFilename}' with '#{converter.name}'..." if l.deb 60
              @converted = converter.convert @converted, @convertedFilename

            #convert Filename
            switch _B.type converter.convertFn
              when 'Function'
                @convertedFilename = converter.convertFn @convertedFilename
              when 'String'
                @convertedFilename = upath.changeExt @convertedFilename, converter.convertFn

            l.debug "...resource.convertedFilename is '#{@convertedFilename}'" if l.deb 95

          @hasErrors = false
          return @hasChanged = true
        else
          l.debug "No changes in source of resource '#{@filename}' " if l.deb 90
          return @hasChanged = false

      catch err
        @hasErrors = true
        l.err uerr = "Error converting '#{@filename}' with converter '#{converter?.name}'."
        throw new UError uerr, nested:err

module.exports = UResource

### Debug information ###
#if l.deb >= 90
#  YADC = require('YouAreDaChef').YouAreDaChef
#
#  YADC(UModule)
#    .before /_constructor/, (match, bundle, filename)->
#      l.debug("Before '#{match}' with filename = '#{filename}'")



