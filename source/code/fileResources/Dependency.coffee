_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/Dependency' #, 110

_.mixin (require 'underscore.string').exports()

MasterDefaultsConfig = require '../config/MasterDefaultsConfig'

upath = require './../paths/upath'
pathRelative = require './../paths/pathRelative'

isFileIn = require 'is_file_in'
UError = require '../utils/UError'

minimatch = require 'minimatch'
util = require 'util'

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
  @defaults = { untrusted: false }

  constructor: (depString, @module, defaults = Dependency.defaults)->
    _.defaults @, defaults if defaults isnt Dependency.defaults
    @AST_requireLiterals or= [] # stores the AST(s) of this dep
    @depString = depString

  clone: -> new Dependency @depString, @module, {@AST_requireLiterals, @untrusted}

  Object.defineProperties @::,

    # extract `pluginName`!`resourceName`.`ext`, keeping input as-is.
    # also extract isPartial information for both
    depString:
      get:-> if @untrusted then untrust @_depString else @_depString

      set: (depString='')->
        @_depString = depString
        dp = depString.replace /\\/g, '/'

        indexOfSep = dp.indexOf '!' #@todo: use _.strLeft / _.strRight
        if indexOfSep > 0
          if not @plugin
            @plugin = new Dependency dp[0..indexOfSep-1], @ # why not ?
          else
            @plugin.depString = dp[0..indexOfSep-1]
        else
          delete @plugin

        @originalResourceName = # keep the original resource name
          if indexOfSep >= 0 then dp[indexOfSep+1..dp.length-1] else dp #)

        @resourceName = upath.normalizeSafe @originalResourceName

        # store isPartial for resourceName
        if _.last(@resourceName) is '|'
          @resourceName = @resourceName[0..@resourceName.length-2] # trim '|', set flag
          @isPartial = true

        if _.last(@resourceName) is '/'
          @resourceName = @resourceName[0..@resourceName.length-2]

        if upath.extname @resourceName # trim & store file extension
          @extname = upath.extname @resourceName
          @resourceName = upath.trimExt @resourceName

        @updateAST() # wasted initially, but best to always keep in sync

  # update code AST, always storing the resolved `relative: 'file'` representation
  updateAST: ->
    for depLiteral in (@AST_requireLiterals or [])
      if depLiteral.value isnt (name = @name())
        l.debug(80, "Replacing AST literal '#{depLiteral.value}' with '#{name}'")
        depLiteral.value = name

  #todo: other valid types ?
  TYPES = [
    'notFoundInBundle',
    'external',
    'untrusted',
    'system',
    'bundle',
    'nodeLocal'
    #'webRootMap'
    #'local' # local is when nodeLocal also
    #'node'  # node is a generic function :-)
  ]
  for type in TYPES
    do (type)->
      Object.defineProperty Dependency::, 'is' + _.capitalize(type),
        get: -> @type is type

  Object.defineProperties @::,

    isLocal: get:-> @type in ['local', 'nodeLocal']

    pluginName: get: -> if @plugin then @plugin.name() else ''

    type: get:->
      if @untrusted
        'untrusted'
      else
        if @depString in ['require', 'exports', 'module']
          'system'
        else
          if @isWebRootMap
            'webRootMap'
          else
            # lets see if its found in the bundle
            if @isNode
              if @_isInLocals
                'nodeLocal'
              else
                'node'
            else
              if (@isFound or @isFoundAsIndex)
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
      (@plugin?.name?() is 'node') or # 'node' is a fake plugin signaling nodejs-only executing modules.
      isFileIn @name(plugin:false, relative:'bundle'),
        (@module?.bundle?.dependencies?.node or
          MasterDefaultsConfig.bundle.dependencies.node)

    isFound: get:->
      if _.isArray @module?.bundle?.dstFilenames
        upath.defaultExt(@_bundleRelative, '.js') in @module.bundle.dstFilenames

    isFoundAsIndex: get:->
      if _.isArray @module?.bundle?.dstFilenames
        upath.defaultExt(@_bundleRelative + '/index', '.js') in @module.bundle.dstFilenames

    isWebRootMap: get:-> @resourceName[0] is '/'

    isRelative: get:-> @resourceName[0] is '.'

    _bundleRelative: get:->
      if @untrusted
        @depString
      else
        if @isRelative #and @_isBundleBoundary
          upath.join upath.dirname(@module?.path or '.'), @resourceName
        else # keep bundleRelative outside of bundle with at least ./
          upath.normalizeSafe @resourceName

    _fileRelative: get:->
      if @untrusted
        @_depString
      else
        if @module?.path and (@isFound or @isFoundAsIndex)
          pathRelative upath.dirname(@module?.path or '__root__'), @_bundleRelative, { dot4Current:true, assumeRoot:true}
        else
          upath.normalizeSafe @resourceName

    # does this dependency lie within bundle's boundaries ?
    _isBundleBoundary: get:->
      if @untrusted or @isWebRootMap
        false
      else
        !!@pathToRoot

    pathToRoot: get: ->  # 2 `..` steps back :resourceName & modulePath
      pathRelative "#{@module?.path}/../../#{@resourceName}", ".", assumeRoot: true

    modulePathToRoot: get: ->
      pathRelative upath.dirname(@module?.path or "__root__"), "/", assumeRoot:true

  name: (options = {})->
    if @untrusted
      @depString
    else
      options.ext ?= false #if @isExternal or @isNotFoundInBundle then true else false
      options.plugin ?= true
      options.relative ?= 'file'
      options.quote ?= false

      (if options.quote then "'" else '') + # @todo: use _.quote
      (if options.plugin and @plugin and not @isNode then @plugin.name() + '!' else '') +
      (if options.relative is 'bundle' then @_bundleRelative else @_fileRelative) + # default = 'file'
      (if !@isFound and @isFoundAsIndex then '/index' else '') +
      (if options.ext is false or not @extname then '' else @extname) +
      (if options.quote then "'" else '')

  toString:-> @depString

  inspect: ->
    if @untrusted
      @depString
    else
      "'#{@name()}'"

  ###
  Compare this Dependency instance with another, either Dependency or a string representation of another dep.

  It caters for different representations of
    * bundleRelative / fileRelative
    * having `.js` extension or not
    * having plugin or not
  by comparing the bundleRelative paths with (default) .js extension

  @param dep {Dependency | String | .toString} The depedency to compare with this - returns true if
  @todo: use @isMatch dep, {some:options}
  ###
  isEqual: (dep)->
    return true if dep is @
    return false if not dep or @untrusted

    if not (dep instanceof Dependency)
      dep = new Dependency dep, @module

    return false if @module?.bundle? isnt dep.module?.bundle? #only if we have a bundle, for testing

    isSameJSFile @name(relative:'bundle', ext:true),
                 dep.name(relative:'bundle', ext:true)

  isSameJSFile = (a,b)-> upath.defaultExt(a, '.js') is upath.defaultExt(b, '.js')

  ###
  Check if this Dependency instance matches with a:

   * Another Dependency instance that has to *match* with this dep
      * All its data like @plugin.name() or @resourceName, ext etc have to match

      * Its resourceName can be a partial or minimatch search it self. @todo: & plugin

    * A string representation with either:

      * a resourceName like `src/models/Person`, possibly prefixed with an AMD-style pluginName like 'plugins/spy!src/models/Person'`

      * a *partial* `resourceName`, denoted by | at the end, eg `'myplugin/spy|!src|'`

      * a `minimatch` comparison of @plugin.name() & @resourceName comparison # @todo look below

    * A RegExp, again matching both @plugin.name() & @resourceName on its own

  * ???? A Function called with depName, dep ???

  It caters for different representations of
    * bundleRelative / fileRelative
    * having `.js` extension or not
    * having plugin or not
  by comparing the bundleRelative paths with (default) .js extension

  @param matchDep {Dependency | String | RegExp | Function | {toString: function} The depedency to compare with this

  @return true if a match, false otherwise

  # @todo: write more specs & doc it better
  # @todo: convert to agreement / _B.Blender
  # @todo: return  matched part if its a partial match (needs tweak for minimatch / impossible!)
  ###
  isMatch: (matchDep, options)->
    l.deb "isMatch: options =", options, "\nmatchDep =", matchDep, "\n@ =", @ if l.deb(105)

    return false if not matchDep or @untrusted # @todo: match untrusted also, as text representation or isEqualCode
    return matchDep.test(@name options) if _.isRegExp matchDep

    matchDep = new Dependency(matchDep, @module) if _.isString matchDep # extract plugin, resourceName etc

    if not (matchDep instanceof Dependency)
      l.er err = "Dependency.isMatch: wrong dependency type '#{matchDep}' should be String|RegExp|Dependency."
      throw new UError err
    else

      if @module?.bundle? isnt matchDep.module?.bundle? #only if we have a bundle, for testing
        l.deb "isMatch: false cause of module.bundle" if l.deb(120)
        return false

      if @plugin and not @plugin.isMatch matchDep.plugin, options
        l.deb "isMatch: false cause of @plugin.isMatch" if l.deb(120)
        return false

      matchDepName = matchDep.resourceName
      thisName = @name {plugin: false, relative: options.relative }
      if matchDep.isPartial
        if not _.startsWith thisName, matchDepName
          l.deb "isMatch: false cause isPartial _.startsWith '#{thisName}', '#{matchDepName}'" if l.deb(120)
          return false
      else
        matchDepName = upath.defaultExt matchDepName, '.js'
        thisName = upath.defaultExt thisName, '.js'
        if not minimatch matchDepName, thisName
          l.deb "isMatch: false cause of false minimatch('#{matchDepName}', '#{thisName}')" if l.deb(120)
          return false

      l.deb "isMatch: true" if l.deb(110)
      true

  update: (newDep, matchDep, options)->
    if l.deb(80)
      l.deb "update: options =", options, "\n@ =", @, "\nnewDep =", newDep, "\nmatchDep =", matchDep

    newDepPaths = []

    #translate relative:'bundle' path to relative:'file'
    if (options.relative is 'bundle') and newDep.isRelative
      l.deb 110, "update: translate {relative:'bundle'} path to {relative:'file'}. Adding @modulePathToRoot = ", @modulePathToRoot
      newDepPaths.push @modulePathToRoot

    newDepPaths.push newDep.name {relative: 'file', plugin:false, ext:true} #, options

    (noPluginOptions = _.clone(options)).plugin = false
    if matchDep and matchDep.isPartial
      partialPath = @name(noPluginOptions).slice(matchDep.name(plugin:false).length + 1)
      l.deb 110, "update: adding partialPath =", partialPath

      newDepPaths.push(partialPath)

    newDepString = upath.join.apply null, newDepPaths

    if newDep.plugin
      if @plugin
        newDepString = (@plugin.update newDep.plugin, matchDep?.plugin, options) + '!' + newDepString
      else
        newDepString = newDep.pluginName + '!' + newDepString

    l.deb """Dependency.update replacing @depString '#{@depString}' with '#{newDepString}'.""" if l.deb(90)
    @depString = newDepString # also sets ASTs    

module.exports = Dependency

_.extend module.exports.prototype, {l, _, _B}