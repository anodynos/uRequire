fs = require 'fs'
upath = require 'upath'

util = require 'util'

pathRelative = require './paths/pathRelative'
Dependency = require './fileResources/Dependency'

urequire = require './urequire'

BundleBase = require './process/BundleBase'

###
The `nodejs`'s require facility.

An instance of `NodeRequirer` is created for each UMD module, when running on node. Its purpose is to resolve and load modules, synchronoysly or asynchronoysly, depending on how it was called:

  * sync (blocking): when call was made the nodejs way `require('dependency')` in which case the module is simply loaded & returned.

  * async (immediatelly returning): when called the AMD/requirejs way `require(['dep1', 'dep2'], function(dep1, dep2) {})` in which case the callback function is called, when all modules/dependencies have been loaded asynchronously.

@note: it used to mimic the inconsistent RequireJS 2.0.x behaviour on the `require([..],->`, where if all deps are loaded before, then the call is SYNCHRONOUS :-(. It is now reverted to the [always asynch 2.1.x behaviour](https://github.com/jrburke/requirejs/wiki/Upgrading-to-RequireJS-2.1#wiki-breaking-async)

@author Agelos Pikoulas

###
class NodeRequirer extends BundleBase

  ###
  Create a NodeRequirer instance, passing paths resolution information.

  @param {String} moduleNameBR `module` name of current UMD module (that calls 'require'), in bundleRelative format, eg 'models/Person', as hardcoded in generated uRequire UMD.

  @param {Object} modyle The node `module` object of the current UMD module (that calls 'require').
                  Used to issue the actual node `require` on the module, to preserve the correct `node_modules` lookup paths (as opposed to using the NodeRequirer's paths.

  @param {Function} The original module's `require`, used for debuging `require.resolve`

  @param {String} dirname `__dirname` passed at runtime from the UMD module, poiniting to its self (i.e filename of the .js file).

  @param {String} webRootMap where '/' is mapped when running on nodejs, as hardcoded in uRequire UMD (relative to path).
  ###
  constructor: (@moduleNameBR, @modyle, @moduleRequire, @dirname, @webRootMap, debugLevel) ->
    @l = new _B.Logger "uRequire/NodeRequirer `#{@moduleNameBR}`}",  debugLevel # template.debugLevel
    @path = upath.normalize (
      @dirname + '/' + (pathRelative "#{upath.dirname @moduleNameBR}", ".", assumeRoot: true) + '/'
    )

    @l.deb("""\n
      `new NodeRequirer()` instanciating
            @moduleNameBR = '#{@moduleNameBR}'
            @modyle.id = '#{@modyle.id}'
            @dirname = '#{@dirname}'
            @webRootMap = '#{@webRootMap}')
            @path = '#{@path}'
      """) if @l.deb 30

    if @getRequireJSConfig().baseUrl
      baseUrl = @getRequireJSConfig().baseUrl

      @l.deb("`baseUrl` (from requireJsConfig ) = #{baseUrl}") if @l.deb 15

      @path = upath.normalize (
        if baseUrl[0] is '/'  #web root as reference
          @webRoot
        else                  #path as reference
          @path
      ) + '/' + baseUrl + '/'

      @l.deb("Final `@path` (from requireJsConfig.baseUrl & @path) = #{@path}") if @l.deb 30

  ###
  Defaults to node's `require`, invoked on the module to preserve `node_modules` path lookup.
  It can be swaped with another/mock version (eg by spec tests).
  ###
  Object.defineProperties @::,
    nodeRequire:
      get: -> @_nodeRequire or _.bind @modyle.require, @modyle
      set: (@_nodeRequire) ->

    debugInfo:
      get:->
        di = {
          path: @path
          webRoot: @webRoot
        }

        rjsLoaded = di["requirejsLoaded[@path]"] = {}
        for pathsRjs, rjs of NodeRequirer::requirejsLoaded
          rjsConfig = rjsLoaded[pathsRjs] = {}
          rjsConfig["requirejs._.config.baseUrl"] = rjs.s?.contexts?._?.config.baseUrl
          rjsConfig["requirejs._.config.paths"] = rjs.s?.contexts?._?.config.paths

        rjsConfigs = di["requireJSConfigs[@path]"] = {}
        for pathsRjsConfig, config of NodeRequirer::requireJSConfigs
          rjsConfigs[pathsRjsConfig] = config

        @l.prettify di

    ###
    Load the [Requirejs](http://requirejs.org/) system module (as npm installed), & cache for @path as key.

    Then cache it in static NodeRequirer::requirejsLoaded[@path], so only one instance
    is shared among all `NodeRequirer`s for a given @path. Hence, its created only once,
    first time it's needed (for each distinct @path).

    It is configuring rjs with resolved paths, for each of the paths entry in `requirejs.config.json`.
    Resolved paths are relative to `@path` (instead of `@dirname`).

    @return {requirejs} The module `RequireJS` for node, configured for this @path.
    ###
    requirejs: get: ->
      NodeRequirer::requirejsLoaded ?= {}  # static / store in class

      if not NodeRequirer::requirejsLoaded[@path]
        requirejs = @nodeRequire 'requirejs'

        requireJsConf =
          nodeRequire: @nodeRequire
          baseUrl: @path

        # resolve each path, as we do in modules - take advantage of webRoot etc.
        if @getRequireJSConfig().paths
          requireJsConf.paths = {}
          for pathName, pathEntries of @getRequireJSConfig().paths
            pathEntries = _B.arrayize pathEntries

            requireJsConf.paths[pathName] or= []

            for pathEntry in pathEntries
              for resolvedPath in @resolvePaths(new Dependency(pathEntry), @path) #rjs paths are relative to path, not some file
                requireJsConf.paths[pathName].push resolvedPath if not (resolvedPath in requireJsConf.paths[pathName])

        requirejs.config requireJsConf

        NodeRequirer::requirejsLoaded[@path] = requirejs

      return NodeRequirer::requirejsLoaded[@path]


  ###
  Load 'requirejs.config.json' for @path & cache it with @path as key.
  @todo: do we really need this complexity ?
  @return {RequireJSConfig object} the requireJSConfig for @path (or {} if 'requirejs.config.json' not found/not valid json)
  ###
  getRequireJSConfig: ->
    NodeRequirer::requireJSConfigs ?= {}  # static / store in class

    if NodeRequirer::requireJSConfigs[@path] is undefined
      try
        rjsc = require('fs').readFileSync @path + 'requirejs.config.json', 'utf-8'
      catch  #do nothing, we just dont have a requirejs.config.json

      if rjsc
        try
          NodeRequirer::requireJSConfigs[@path] = JSON.parse rjsc
        catch err
          throw new UError "urequire: error parsing requirejs.config.json from #{@path + 'requirejs.config.json'}", nested: err

      NodeRequirer::requireJSConfigs[@path] ?= {} # if still undefined, after so much effort

    return NodeRequirer::requireJSConfigs[@path]

  ###
  Loads *one* module, synchronously.

  Uses either node's `require` or the synchronous version of `RequireJs`'s.
  The latter is used for modules that :
    * either have a plugin (eg `"text!module.txt"`)
    * or modules that failed to load with node's require: these are assumed to be native AMD, hence and attempt is made to load with RequireJS.

  @note If loading failures occur, it makes more than one attempts to find/load a module (alt paths & node/rjs require), noting loading errors. If all loading attempts fail, **it QUITS with process.exit(1)**.

  @param {Dependency} dep The Dependency to be load.
  @return {module} loaded module or quits if it fails
  ###
  unloaded = {}
  loadModule: (dep)=> #load module either via nodeRequire OR requireJS if it needs a plugin or if it fails!
    attempts = []
    loadedModule = unloaded # cater for module returning 'undefined/null' which is a valid value

    @l.deb 95, "called `loadModule('#{dep}')`"
    resolvedPaths = @resolvePaths(dep, @dirname)
    @l.deb "resolvedPaths = \n", resolvedPaths if @l.deb 95

    requirers =
      if hasPlugin = dep.plugin?.name?() not in [undefined, 'node'] # plugin 'node' is dummy: just signals ommit from defineArrayDeps
        ['requirejs']
      else
        ['nodeRequire', 'requirejs']

    for requirer in requirers
      for modulePath, resolvedPathNo in resolvedPaths
        if hasPlugin then modulePath = "#{dep.pluginName}!#{modulePath}"
        if @l.deb 50
          @l.deb 50, "resolvedPathNo ##{resolvedPathNo}: '#{modulePath}'"
          if @l.deb(70) and requirer is 'nodeRequire'
            try @l.deb "@moduleRequire.resolve() = `#{@moduleRequire.resolve(modulePath)}`" catch

        attempts.push {resolvedPathNo, modulePath, requirerUsed: requirer, dependency: dep.name()}
        # modulePath = upath.addExt modulePath, '.js' # RequireJS wants this for some reason ?
        @l.deb "ISSUING: #{requirer}('#{modulePath}')" if @l.deb 30
        try
          loadedModule = @[requirer](modulePath)
        catch err
          @l.warn "FAILED: `@#{requirer}('#{modulePath}')` err=\n", err if @l.deb 30
          @requirejs.undef(modulePath) if requirer is 'requirejs' # solves https://github.com/jrburke/requirejs/issues/1224

          _.extend _.last(attempts),
            urequireError: "Error loading module through requirer `#{requirer}`."
            error: {string:err.toString(), err: err}

          if hasPlugin
            _.extend _.last(attempts),
              pluginName: dep.pluginName,
              pluginPaths: @requireJSConfig?.paths[dep.pluginName],
              pluginResolvedPaths: @requirejs?.s?.contexts?._?.config?.paths[dep.pluginName]

        break if loadedModule isnt unloaded
      break if loadedModule isnt unloaded

    if loadedModule is unloaded
      @l.er """\n
        *uRequire #{urequire.VERSION}*: failed to load dependency: '#{dep}' in module '#{@moduleNameBR}'.
        Tried paths:
        #{ _.uniq("'" + att.modulePath + "'" for att in attempts).join '\n  '}

        Quiting with throwing 1st error at the end - Detailed attempts follow:
        #{("  \u001b[33m Attempt #" +  (attIdx + 1) + '\n' + @l.prettify(att) for att, attIdx in attempts).join('\n\n')}

        Debug info:\n """, @debugInfo
      throw attempts[0]?.error?.err or '1st err was undefined!'
    else
      @l.ok "`@#{requirer}` loaded dep `#{dep}` from `#{modulePath}` (resolvedPathNo ##{resolvedPathNo}) " if @l.deb 20
      loadedModule


  ###
  The actual `require` method, called as synchronous or asynchronous.

  It is the method passed to the *factoryBody* of UMD modules
    (i.e what you call on your uRequire module when running on node)
  and the one used to load all deps before entering the module's factoryBody.

  @param { String, Array<String> } strDeps
      As `String`, its a single dependency to load *synchronously*, eg `"models/person"` or `'text!abc.txt'`
      As `Array<String>`, its an array of dependencies to load *asynchronously* the AMD/RequireJS way, eg `[ "models/person" or 'text!abc.txt' ]`

  @param {Function} callback The callback function to call when all dependencies are loaded, called asynchronously by default
          (or synchronously if all dependencies were cached, when it matched RequireJs's 2.0.x behaviour
          [not needed any more in 2.1.x](https://github.com/jrburke/requirejs/wiki/Upgrading-to-RequireJS-2.1#wiki-breaking-async) )
  @return {module} module loaded if called *synchronously*, or `undefined` if it was called *asynchronously*
  ###
  require: (strDeps, callback)=> # strDeps is { 'String' | '[]<String>' }
    if _.isString strDeps
      @l.deb "`nr.require('#{strDeps}')` called - @loadModule synchronously single dep." if @l.deb 80
      @loadModule new Dependency strDeps, path: @moduleNameBR
    else
      if _.isArray(strDeps) and _.isFunction(callback) # we have an arrayDeps []<String> & cb
        @l.deb "`nr.require(#{util.inspect strDeps})` called: @loadModule called asynchronously for each dep in array." if @l.deb 50
        process.nextTick => #load asynchronously
          # load each dependency and callback()
          callback.apply null, (@loadModule(new Dependency strDep, path: @moduleNameBR) for strDep in strDeps)

module.exports = NodeRequirer
