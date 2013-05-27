_ = require 'lodash'
_B = require 'uberscore'

l = new _B.Logger 'urequire/UResource'

upath = require '../paths/upath'
ModuleGeneratorTemplates = require '../templates/ModuleGeneratorTemplates'
ModuleManipulator = require "../moduleManipulation/ModuleManipulator"
Dependency = require "../Dependency"
fs = require 'fs'

###
  Represents any textual resource (including but not limited to js-convertable code).
  Each time it `@refresh()`es, if source in file is changed,
  its passed through all @converters and stores result as @converted
###
class UResource
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p

  ###
  @param {Object} bundle The Bundle where this URersource belongs
  @param {String} filename of module, bundleRelative eg 'models/PersonModel.coffee'
  @param {Array<?>} converters The converters (bundle.resources) that matched this filename & are used in turn to convert, each time we `refresh()`
  ###
  constructor: (@bundle, @filename, @converters)->
    @refresh()

  @property extname: get: -> upath.extname @filename                # original extension, eg `.js` or `.coffee`
  @property fullPath: get: -> "#{@bundle.bundlePath}/#{@filename}" # full filename on OS filesystem, eg `myproject/mybundle/mymodule.js`

  ###
    Check if source (AS IS eg js, coffee, LESS etc) has changed
    and convert it passing throught all @converters

    @return true if there was a change (and convertions took place), false otherwise
  ###
  refresh: ->
    try
      if @source isnt source = fs.readFileSync @fullPath, 'utf-8'
        @source = @converted = source
        @convertedFilename = @filename
        for converter in @converters
          if _.isFunction converter.convert
            l.debug "Converting '#{@convertedFilename}' with '#{converter.name}'..." if l.deb 60
            @converted = converter.convert @converted, @convertedFilename

          switch _B.type converter.convertFn
            when 'Function'
              @convertedFilename = converter.convertFn @convertedFilename
            when 'String'
              @convertedFilename = upath.changeExt @convertedFilename, converter.convertFn

          l.debug "...resource.convertedFilename is '#{@convertedFilename}'" if l.deb 85

        @hasErrors = false
        return @hasChanged = true
      else
        return @hasChanged = false
    catch err
      err.uRequire = "Error converting '#{@filename}' with converter '#{converter.name}'."
      l.err err.uRequire, err
      @hasErrors = true
      throw err

module.exports = UResource

### Debug information ###
#if l.deb >= 90
#  YADC = require('YouAreDaChef').YouAreDaChef
#
#  YADC(UModule)
#    .before /_constructor/, (match, bundle, filename)->
#      l.debug("Before '#{match}' with filename = '#{filename}'")



