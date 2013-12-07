_ = (_B = require 'uberscore')._
l = new _B.Logger 'urequire/fileResources/Dependency'

_.mixin (require 'underscore.string').exports()

MasterDefaultsConfig = require '../config/MasterDefaultsConfig'

upath = require './../paths/upath'
pathRelative = require './../paths/pathRelative'

isFileInSpecs = require '../config/isFileInSpecs'

untrust = (str)->
  str = new String(str + '')
  str.untrusted = true
  str.inspect = -> """'#{@}' (untrusted Dependency)"""
  str


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
          calculate whether './../myDep' isFound, which in turn is used by isLocal and others etc.
  ###
  constructor: (@depString, @module, @untrusted)->

  Object.defineProperties @::,

    depString:
      get:-> if @untrusted then untrust @_depString else @_depString

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


  #todo: other valid types ?
  TYPES = [
    'notFoundInBundle',
    'external',
    'untrusted',
    'system',
    'bundle',
    'webRootMap'
    'nodeLocal'
    #'local' # local is when nodeLocal also
    #'node'  # node is a generic function :-)
  ]
  for type in TYPES
    do (type)->
      Object.defineProperty Dependency::, 'is' + _.capitalize(type),
        get: -> @type is type

  Object.defineProperties @::,

    isLocal: get:-> @type in ['local', 'nodeLocal']

    type: get:->
      if @untrusted
        'untrusted'
      else
        if @depString in ['require', 'exports', 'module']
          'system'
        else
          if @resourceName[0] is '/'
            'webRootMap'
          else
            # lets see if its found in the bundle
            if @isNode
              if @_isInLocals
                'nodeLocal'
              else
                'node'
            else
              if @isFound
                'bundle'
              else
                if not @_isBundleBoundary
                  'external'
                else
                  if (@resourceName.indexOf('/') < 0) or               # a) its without '/', eg 'when'
                     @_isInLocals                                      # b) its 'when/node/function', but in `dependencies.local`
                     # todo : need to check `(@resourceName[0] isnt '.')` ?
                     # @todo infer locals from package.json, bower.json etc & use depsVars type
                    'local'
                  else
                    'notFoundInBundle'

    _isInLocals: get:->
      (@module?.bundle?.dependencies?.locals or
        MasterDefaultsConfig.bundle.dependencies.locals)[ @resourceName.split('/')[0] ] # we have the 'when' key

    isNode: get:->
      (@pluginName is 'node') or # 'node' is a fake plugin signaling nodejs-only executing modules.
      isFileInSpecs @name(plugin:false, relative:'bundle'),
        (@module?.bundle?.dependencies?.node or
          MasterDefaultsConfig.bundle.dependencies.node)


    isFound: get:->
      if _.isArray @module?.bundle?.dstFilenames
        upath.defaultExt(@_bundleRelative, '.js') in @module.bundle.dstFilenames

    _bundleRelative: get:->
      if @untrusted
        @depString
      else
        if (@resourceName[0] is '.')  and @_isBundleBoundary
          upath.normalize "#{upath.dirname(@module?.path or '__root__')}/#{@resourceName}"
        else # keep bundleRelative outside of bundle with at least ./
          upath.normalizeSafe @resourceName

    _fileRelative: get:->
      if @untrusted
        @_depString
      else
        if @module?.path and @isFound
          pathRelative "$/#{upath.dirname(@module?.path or '__root__')}", "$/#{@_bundleRelative}", dot4Current:true
        else
          upath.normalizeSafe @resourceName

    # does this dependency lie within bundle's boundaries ?
    _isBundleBoundary: get:->
      if @untrusted #or @isWebRootMap
        false
      else
        !!pathRelative "$/#{@module?.path}/../../#{@resourceName}", "$" #2 .. steps back :$ & module

  name: (options = {})->
    if @untrusted
      @depString
    else
      options.ext ?= false #if @isExternal or @isNotFoundInBundle then true else false
      options.plugin ?= true
      options.relative ?= 'file'
      options.quote ?= false

      """
        #{  if options.quote then "'" else ''
        }#{ if options.plugin and @pluginName and not @isNode then @pluginName + '!' else ''
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

_.extend module.exports.prototype, {l, _, _B}
