_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
_B = require 'uberscore'
l = new _B.Logger 'urequire/fileResources/Dependency'

upath = require './../paths/upath'
pathRelative = require './../paths/pathRelative'

# @todo: doc it
# @todo: make all functions property getters
# @todo: tidy up - simplify
class Dependency
  ###
    @param {String} depString The original dependency, as passed i.e 'uberscore' or '../mylibs/dep'

    @param {Module} module The module that has this dependency (optional).
        Used to calculate relative paths via its `.path` property.
        Can be a {} optionally containing a:
         - .path, as String, i.e the bundleRelative filename eg 'somePath/ModuleName'
         - .bundle or any {} with {dstFilenames: Array<String>}
          The dstFilenames (bundleRelative) in the bundle are used to
          calculate whether './../myDep' isFound, which in turn is used by isGlobal and others etc.
  ###
  constructor: (@depString, @module, @untrusted)->

  @systemDeps: ['require', 'exports', 'module']

  @TYPES:
    notFoundInBundle: 'notFoundInBundle'
    global: 'global'
    external: 'external'
    webRootMap: 'webRootMap'
    bundle: 'bundle'
    system: 'system'
    untrusted: 'untrusted'
    #todo: other valid types ?

  untrusted = (str)->
    str = new String(str + '')
    str.untrusted = true
    str.inspect = -> """'#{@}' (untrusted Dependency)"""
    str

  Object.defineProperties @::, #todo: change to CalcCachedProperties ? When do we refresh ?

    depString:
      get:-> if @untrusted then untrusted @_depString else @_depString

      set: (depString='')->
        @_depString = depString
        dp = depString.replace /\\/g, '/'

        indexOfSep = dp.indexOf '!'
        if indexOfSep > 0
          @pluginName = dp[0..indexOfSep-1]

        @resourceName = # keep the original resource name
          if indexOfSep >= 0 then dp[indexOfSep+1..@depString.length-1] else dp

        # trim & store file extension
        if upath.extname @resourceName
          @extname = upath.extname @resourceName
          @resourceName = upath.trimExt @resourceName

    type: get:->
      if @untrusted
        Dependency.TYPES.untrusted
      else
        if @isSystem # 'require', 'module', 'exports'
          Dependency.TYPES.system
        else
          if @isGlobal
            Dependency.TYPES.global
          else
            if @isExternal
              Dependency.TYPES.external
            else
              if @isNotFoundInBundle
                Dependency.TYPES.notFoundInBundle
              else
                if @isWebRootMap # eg '/assets/myLib'
                  Dependency.TYPES.webRootMap
                else
                  Dependency.TYPES.bundle

    _bundleRelative: get:->
      if @untrusted
        @depString
      else
        if @isFileRelative and @isBundleBoundary
          upath.normalize "#{upath.dirname @module.path}/#{@resourceName}"
        else
          upath.normalizeSafe @resourceName

    _fileRelative: get:->
      if @untrusted
        @_depString
      else
        if @module?.path and @isFound
          pathRelative "$/#{upath.dirname @module.path}", "$/#{@_bundleRelative}", dot4Current:true
        else
          upath.normalizeSafe @resourceName

    # ###### Where about does this dependency lie ?

    isBundleBoundary: get:->
      if @untrusted or @isWebRootMap or (not @module?.path)
        false
      else
        !!pathRelative "$/#{@module.path}/../../#{@resourceName}", "$" #2 .. steps back :$ & module

    isFileRelative: get:-> !@untrusted and @resourceName[0] is '.'

    isRelative: get:-> !@untrusted and @resourceName.indexOf('/') >= 0 and not @isWebRootMap

    isWebRootMap: get:-> !@untrusted and @resourceName[0] is '/'

    isGlobal: get:-> !(@untrusted or @isWebRootMap or @isRelative or @isFound or @isSystem)

    isSystem: get:-> (@depString in Dependency.systemDeps)

    ### external-looking deps, like '../../../some/external/lib' ###
    isExternal: get:-> !@untrusted and !(@isBundleBoundary or @isWebRootMap)

    # seem to belong to bundle, eg like myPath/MyLib or ../some/bundle/path
    # but is both not found like '../myNotFoundLib'
    # and it doesn't look like a global eg 'lodash'
    isNotFoundInBundle: get:-> !@untrusted and @isBundleBoundary and not (@isFound or @isGlobal or @isSystem)

    isUntrusted: get:-> @untrusted is true

    isFound: get:->
      if _.isArray @module?.bundle?.dstFilenames
        upath.defaultExt(@_bundleRelative, '.js') in @module.bundle.dstFilenames

  name: (options = {})->
    if @untrusted
      @depString
    else
      options.ext ?= if @isExternal or @isNotFoundInBundle then true else false
      options.plugin ?= true
      options.relative ?= 'file'
      options.quote ?= false

      """
        #{  if options.quote then "'" else ''
        }#{ if options.plugin and @pluginName and (@pluginName isnt 'node') then @pluginName + '!' else '' # 'node' is not considered a plugin, its a flag
        }#{ if options.relative is 'bundle' then @_bundleRelative else @_fileRelative # default = 'file'
        }#{ if options.ext is false or not @extname then '' else @extname
        }#{ if options.quote then "'" else '' }
      """

  toString:-> @depString

  inspect: ->
    if @untrusted
      @depString
    else
      "'#{@depString}' | bundleRelative = '#{@name relative:'bundle'}'"

  ###
  Compare this Dependency instance with another, either Dependency or a string representation of another type.
  It caters for different representations of
    * bundleRelative / fileRelative
    * having `.js` extension or not

  @param dep {Dependency | String | .toString} The depedency to compare with this - returns true if
  ###
  isEqual: (dep)->
    return false if not dep or @untrusted
    isSameJSFile = (a,b)-> upath.defaultExt(a, '.js') is upath.defaultExt(b, '.js')

    if not (dep instanceof Dependency)
      dep = new Dependency dep, @module

    isSameJSFile @name(relative:'bundle', ext:true),
                 dep.name(relative:'bundle', ext:true)

module.exports = Dependency

