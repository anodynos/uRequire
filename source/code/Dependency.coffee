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

    # file extension
    if upath.extname @resourceName #store (@todo: trim extension and keep like that)
      @extname = upath.extname @resourceName

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

  # @todo @property name: {get}
  name: (options = {})->
    options.ext ?= true
    options.plugin ?= true
    options.relativeType ?= 'file'

    n = """
      #{  if options?.plugin and @pluginName then @pluginName + '!' else ''
      }#{ if options?.relativeType is 'bundle' then @bundleRelative() else @fileRelative() #file = default
      }
    """

    if options.ext or not @extname
      n
    else
      n[0..(n.length - @extname.length)-1] #strip extension ?

  toString:-> @name()

  isEqual: (dep)-> # @todo: unhack
    isSameJSFile = (a,b)->  # checks filenames a & b are equal, with '.js' being default ext
      upath.defaultExt(a, '.js') is upath.defaultExt(b, '.js')

    if _.isFunction dep.isBundleBoundary  # ducktyping: looks like a Dependnecny!
      return isSameJSFile dep.name(), @name() #is it the same file, irrespecitve of .js ?
    else
      if not _.isString dep
        dep = dep.toString()

    return (
       isSameJSFile(dep, @toString()) or # plugin: relativeType: 'file', ext:true}
       isSameJSFile(dep, @name(relativeType:'bundle')) # plugin, ext, relativeType:'file'
    )

  bundleRelative: ()->
    if @isFileRelative() and @isBundleBoundary()
        upath.normalize "#{upath.dirname @moduleFilename}/#{@resourceName}"
      # normalize and check if in bundleFiles
#        normalized =
#      if (normalized + (@extname || '.js')) in @bundleFiles #should not call isFound here, cause it depends on us.
        #normalized
#      else
#        @resourceName
    else
      @resourceName

  fileRelative: ()->
    if @moduleFilename and @isFound()
      pathRelative "$/#{upath.dirname @moduleFilename}", "$/#{@bundleRelative()}", dot4Current:true
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

  ### external-looking deps, like '../../../someLib' ###
  isExternal: ()-> not (@isBundleBoundary() or @isWebRootMap())

  ### seem to belong to bundle, but not found, like '../myLib' ###
  isNotFoundInBundle: ()-> @isBundleBoundary() and not (@isFound() or @isGlobal())

  isFound: ()-> # @todo: Remove .js dependency - Might have a dep to 'a.js' but we have 'a.coffee'
    knownExtensions = ['.js', '.coffee'] # @todo: retrieve this info from elsewhere (eg Bundle ?)
    for ke in knownExtensions
      if (@bundleRelative() + (if @extname then '' else ke)) in @bundleFiles
        return true

    return false

module.exports = Dependency