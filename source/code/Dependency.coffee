_ = require 'lodash'
_.mixin (require 'underscore.string').exports()

upath = require './paths/upath'
pathRelative = require './paths/pathRelative'


class Dependency
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor:-> @_constructor.apply @, arguments

  _constructor: (@dep, @moduleFilename='', @bundleFiles=[])->
    @dep = @dep.replace /\\/g, '/'

    indexOfSep = @dep.indexOf '!'
    if indexOfSep > 0
      @pluginName = @dep[0..indexOfSep-1]

    @resourceName = if indexOfSep >= 0
                      @dep[indexOfSep+1..@dep.length-1]
                    else
                      @dep

    # trim & store file extension
    if upath.extname @resourceName
      @extname = upath.extname @resourceName
      @resourceName = upath.trimExt @resourceName

  @TYPES:
    notFoundInBundle: 'notFoundInBundle'
    global: 'global'
    external: 'external'
    webRootMap: 'webRootMap'
    bundle: 'bundle'

  @property type: get:->
    if @isGlobal()
      Dependency.TYPES.global
    else
      if @isExternal()
        Dependency.TYPES.external
      else
        if @isNotFoundInBundle()
          Dependency.TYPES.notFoundInBundle
        else  # webRootMap deps, like '/assets/myLib'
          if @isWebRootMap()
            Dependency.TYPES.webRootMap
          else
            Dependency.TYPES.bundle

  name: (options = {})->
    options.ext ?= if @isExternal() or @isNotFoundInBundle() then true else false
    options.plugin ?= true
    options.relativeType ?= 'file'

    """
      #{  if options.plugin and @pluginName then @pluginName + '!' else ''
      }#{ if options.relativeType is 'bundle' then @_bundleRelative() else @_fileRelative() # default = 'file'
      }#{ if options.ext is false or not @extname then '' else @extname }
    """

  toString:-> @name()

  ###
  Compare this Dependency instance with another, either Dependency or a string representation of another type.
  It caters for different representations of
    * bundleRelative / fileRelative
    * having `.js` extension or not

  @param dep {Dependency | String | .toString} The depedency to compare with this - returns true if
  ###
  isEqual: (dep)->
    isSameJSFile = (a,b)->  # checks filenames a & b are equal, with '.js' being default ext
      upath.defaultExt(a, '.js') is upath.defaultExt(b, '.js')

    if _.isFunction dep.isBundleBoundary and  # ducktyping: looks like a Dependnecny!
       _.isFunction dep.name
        return isSameJSFile dep.name(), @name() #is it the same file, irrespecitve of .js ?
    else
      if not _.isString dep
        dep = dep.toString()

    return isSameJSFile(dep, @name()) or # plugin: relativeType: 'file', ext:true}
           isSameJSFile(dep, @name relativeType:'bundle') # relativeType:'bundle'

  _bundleRelative: ()->
    if @isFileRelative() and @isBundleBoundary()
      upath.normalize "#{upath.dirname @moduleFilename}/#{@resourceName}"
    else
      @resourceName

  _fileRelative: ()->
    if @moduleFilename and @isFound()
      pathRelative "$/#{upath.dirname @moduleFilename}", "$/#{@_bundleRelative()}", dot4Current:true
    else
      @resourceName

  # ###### Where about does this dependency lie ?

  isBundleBoundary: ()->
    if @isWebRootMap() or (not @moduleFilename)
      false
    else
      !!pathRelative "$/#{@moduleFilename}/../../#{@resourceName}", "$" #2 .. steps back :$ & module

  isFileRelative: ()-> @resourceName[0] is '.'

  isRelative: ()-> @resourceName.indexOf('/') >= 0 and not @isWebRootMap()

  isWebRootMap: ()-> @resourceName[0] is '/'

  isGlobal: ()->  not @isWebRootMap() and
                  not @isRelative() and
                  not @isFound()

  ### external-looking deps, like '../../../some/external/lib' ###
  isExternal: ()-> not (@isBundleBoundary() or @isWebRootMap())

  ### seem to belong to bundle, but not found, like '../myLib' ###
  isNotFoundInBundle: ()-> @isBundleBoundary() and not (@isFound() or @isGlobal())

  isFound: ()->
    knownExtensions = ['.js', '.coffee'] # @todo: retrieve this info from elsewhere (eg Bundle ?)
    for ke in knownExtensions
      if (@_bundleRelative() + ke) in @bundleFiles
        return true

    return false

module.exports = Dependency