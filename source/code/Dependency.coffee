_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
_B = require 'uberscore'
l = new _B.Logger 'urequire/Dependency'

upath = require './paths/upath'
pathRelative = require './paths/pathRelative'

# @todo: doc it
# @todo: make all functions property getters
# @todo: tidy up - simplify
class Dependency
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p

  ###
    @param {String} depString The original dependency, as passed i.e 'uberscore' or '../mylibs/dep'

    @param {String} moduleString The module (bundle relative) that has this dependency (optional).
                    Used to calculate relative paths.

    @param {Bundle or {} with dstFilenames: Array<String>}
        The dstFilenames (bundleRelative) in the bundle are used to
        calculate whether './../myDep' isFound, which in turn is used by isGlobal etc.
  ###
  constructor: (@depString, @moduleString='', @bundle)->
    
    depString = depString.replace /\\/g, '/'

    indexOfSep = depString.indexOf '!'
    if indexOfSep > 0
      @pluginName = depString[0..indexOfSep-1]

    @resourceName = if indexOfSep >= 0
                      depString[indexOfSep+1..@depString.length-1]
                    else
                      depString

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
    #todo: other valid types ?

  @property type: get:->
    if @isGlobal
      Dependency.TYPES.global
    else
      if @isExternal
        Dependency.TYPES.external
      else
        if @isNotFoundInBundle
          Dependency.TYPES.notFoundInBundle
        else  # webRootMap deps, like '/assets/myLib'
          if @isWebRootMap
            Dependency.TYPES.webRootMap
          else
            Dependency.TYPES.bundle

  name: (options = {})->
    options.ext ?= if @isExternal or @isNotFoundInBundle then true else false
    options.plugin ?= true
    options.relativeType ?= 'file'

    """
      #{  if options.plugin and @pluginName then @pluginName + '!' else ''
      }#{ if options.relativeType is 'bundle' then @_bundleRelative else @_fileRelative # default = 'file'
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

  @property
  
    _bundleRelative: get:->
      if @isFileRelative and @isBundleBoundary
        upath.normalize "#{upath.dirname @moduleString}/#{@resourceName}"
      else
        @resourceName
  
    _fileRelative: get:->
      if @moduleString and @isFound
        pathRelative "$/#{upath.dirname @moduleString}", "$/#{@_bundleRelative}", dot4Current:true
      else
        @resourceName
  
    # ###### Where about does this dependency lie ?
  
    isBundleBoundary: get:->
      if @isWebRootMap or (not @moduleString)
        false
      else
        !!pathRelative "$/#{@moduleString}/../../#{@resourceName}", "$" #2 .. steps back :$ & module
  
    isFileRelative: get:-> @resourceName[0] is '.'
  
    isRelative: get:-> @resourceName.indexOf('/') >= 0 and not @isWebRootMap
  
    isWebRootMap: get:-> @resourceName[0] is '/'
  
    isGlobal: get:->  not @isWebRootMap and
                    not @isRelative and
                    not @isFound
  
    ### external-looking deps, like '../../../some/external/lib' ###
    isExternal: get:-> not (@isBundleBoundary or @isWebRootMap)
  
      
  
    # seem to belong to bundle, eg like myPath/MyLib or ../some/bundle/path
    # but is both not found like '../myNotFoundLib' 
    # and it doesn't look like a global eg 'lodash'  
    isNotFoundInBundle: get:-> @isBundleBoundary and not (@isFound or @isGlobal)
      
    isFound: get:-> 
      if @bundle?.dstFilenames 
        upath.defaultExt(@_bundleRelative, '.js') in @bundle.dstFilenames
        #todo: check with "less -> css", 'teacup -> HTML'

module.exports = Dependency