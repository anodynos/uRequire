_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
_fs = require 'fs'

upath = require './paths/upath'
pathRelative = require './paths/pathRelative'
Dependency = require './Dependency'
_B = require 'uberscore'
l = new _B.Logger 'urequire/NodeRequirer', 0 # disable runtime debug

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
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props
  Function::staticProperty = (props) => Object.defineProperty @::, name, descr for name, descr of props

  ###
  YADC wants can't grab real 'constructor'
  ###
  constructor: -> @_constructor.apply @, arguments

  ###
  Create a NodeRequirer instance, passing paths resolution information.

  @param {String} moduleNameBR `module` name of current UMD module (that calls 'require'), in bundleRelative format, eg 'models/Person', as hardcoded in generated uRequire UMD.

  @param {Object} modyle The node `module` object of the current UMD module (that calls 'require').
                  Used to issue the actual node `require` on the module, to preserve the correct `node_modules` lookup paths (as opposed to using the NodeRequirer's paths.

  @param {String} dirname `__dirname` passed at runtime from the UMD module, poiniting to its self (i.e filename of the .js file).

  @param {String} webRootMap where '/' is mapped when running on nodejs, as hardcoded in uRequire UMD (relative to bundlePath).
  ###
  _constructor: (@moduleNameBR, @modyle, @dirname, @webRootMap)->

    @bundlePath = upath.normalize (
      @dirname + '/' + (pathRelative "$/#{upath.dirname @moduleNameBR}", "$/") + '/'
    )

    l.debug("""
      new NodeRequirer(
        @moduleNameBR='#{@moduleNameBR}'
        @dirname='#{@dirname}'
        @webRootMap='#{@webRootMap}')

        Calculated @bundlePath (from @moduleNameBR & @dirname) = #{@bundlePath}
    """) if l.deb 10

    if @getRequireJSConfig().baseUrl
      oldbundlePath = @bundlePath
      baseUrl = @getRequireJSConfig().baseUrl

      l.debug("`baseUrl` (from requireJsConfig ) = #{baseUrl}") if l.deb 15

      @bundlePath = upath.normalize (
        if baseUrl[0] is '/'  #web root as reference
          @webRoot
        else                  #bundlePath as reference
          @bundlePath
        ) + '/' + baseUrl + '/'

      l.debug("Final `@bundlePath` (from requireJsConfig.baseUrl & @bundlePath) = #{@bundlePath}") if l.deb 30
#      if oldbundlePath isnt @bundlePath # store requireJSConfig for this new @bundlePath
#        l.debug("""
#          ### stroring rjs config ###
#          NodeRequirer::requireJSConfigs[#{@bundlePath}] = NodeRequirer::requireJSConfigs[#{oldbundlePath}]
#        """)
#        NodeRequirer::requireJSConfigs[@bundlePath] = NodeRequirer::requireJSConfigs[oldbundlePath]

  ###
  @property {Function}
  A @property that defaults to node's `require`, invoked on the module to preserve `node_modules` path lookup.
  It can be swaped with another/mock version (eg by spec tests).
  ###

  @property
    nodeRequire:
      get: -> @_nodeRequire or _.bind @modyle.require, @modyle
      set: (@_nodeRequire)->


  @property
    debugInfo:
      get:->
        di = {
          bundlePath: @bundlePath
          webRoot: @webRoot
        }

        rjsLoaded = di["requirejsLoaded[@bundlePath]"] = {}
        for bundlePathsRjs, rjs of NodeRequirer::requirejsLoaded
          rjsConfig = rjsLoaded[bundlePathsRjs] = {}
          rjsConfig["requirejs._.config.baseUrl"] = rjs.s?.contexts?._?.config.baseUrl
          rjsConfig["requirejs._.config.paths"] = rjs.s?.contexts?._?.config.paths

        rjsConfigs = di["requireJSConfigs[@bundlePath]"] = {}
        for bundlePathsRjsConfig, config of NodeRequirer::requireJSConfigs
          rjsConfigs[bundlePathsRjsConfig] = config

        l.prettify di


  ###
  @property {Set<module>}
  Stores all modules loaded so far. Its `static` i.e a class variable, shared among all instances.
  ###
  cachedModules: {}

  ###
  Load 'requirejs.config.json' for @bundlePath & cache it with @bundlePath as key.
  @return {RequireJSConfig object} the requireJSConfig for @bundlePath (or {} if 'requirejs.config.json' not found/not valid json)
  ###
  getRequireJSConfig: ->
    NodeRequirer::requireJSConfigs ?= {}  # static / store in class

    if NodeRequirer::requireJSConfigs[@bundlePath] is undefined
      try
        rjsc = require('fs').readFileSync @bundlePath + 'requirejs.config.json', 'utf-8'
      catch error
        # l.err "urequire: error loading requirejs.config.json from #{@bundlePath + 'requirejs.config.json'}"
        #do nothing, we just dont have a requirejs.config.json

      if rjsc
        try
          NodeRequirer::requireJSConfigs[@bundlePath] = JSON.parse rjsc
        catch error
          l.err "urequire: error parsing requirejs.config.json from #{@bundlePath + 'requirejs.config.json'}"

      NodeRequirer::requireJSConfigs[@bundlePath] ?= {} # if still undefined, after so much effort

    return NodeRequirer::requireJSConfigs[@bundlePath]

  ###
  Load the [Requirejs](http://requirejs.org/) system module (as npm installed), & cache for @bundlePath as key.

  Then cache it in static NodeRequirer::requirejsLoaded[@bundlePath], so only one instance
  is shared among all `NodeRequirer`s for a given @bundlePath. Hence, its created only once,
  first time it's needed (for each distinct @bundlePath).

  It is configuring rjs with resolved paths, for each of the paths entry in `requirejs.config.json`.
  Resolved paths are relative to `@bundlePath` (instead of `@dirname`).

  @return {requirejs} The module `RequireJS` for node, configured for this @bundlePath.
  ###
  getRequirejs: ->
    NodeRequirer::requirejsLoaded ?= {}  # static / store in class

    if not NodeRequirer::requirejsLoaded[@bundlePath]
      requirejs = @nodeRequire 'requirejs'

      requireJsConf =
        nodeRequire: @nodeRequire
        baseUrl: @bundlePath

      # resolve each path, as we do in modules - take advantage of webRoot etc.
      if @getRequireJSConfig().paths
        requireJsConf.paths = {}
        for pathName, pathEntries of @getRequireJSConfig().paths
          if not _.isArray(pathEntries)
            pathEntries = [ pathEntries ]

          requireJsConf.paths[pathName] or= []

          for pathEntry in pathEntries
            for resolvedPath in @resolvePaths(new Dependency(pathEntry), @bundlePath) #rjs paths are relative to bundlePath, not some file
              requireJsConf.paths[pathName].push resolvedPath if not (resolvedPath in requireJsConf.paths[pathName])

      requirejs.config requireJsConf

      NodeRequirer::requirejsLoaded[@bundlePath] = requirejs

    return NodeRequirer::requirejsLoaded[@bundlePath]

  ###
  Loads *one* module, synchronously.

  Uses either node's `require` or the synchronous version of `RequireJs`'s.
  The latter is used for modules that :
    * either have a plugin (eg `"text!module.txt"`)
    * or modules that failed to load with node's require: these are assumed to be native AMD, hence and attempt is made to load with RequireJS.

  @note If loading failures occur, it makes more than one attempts to find/load a module (alt paths & node/rjs require), noting loading errors. If all loading attempts fail, **it QUITS with process.exit(1)**.

  @param {Dependency} dep The Dependency to be load.
  @return {module} loaded module or quits if it fails
  @todo:2 refactor/simplify
  ###
  loadModule: (dep)=>
    #load module either via nodeRequire OR requireJS if it needs a plugin or if it fails!
    attempts = []
    isCached = false
    loadedModule = null

    for modulePath, resolvedPathNo in @resolvePaths(dep, @dirname) when not loadedModule
      _modulePath = modulePath # hack cause of coffee-forLoop advancing modulePaths, even if 'when' is falsed
      # check if already loaded
      if (loadedModule = @cachedModules[_modulePath]) # assignment, NOT equality check!
        isCached = true
      else
        # load a simple node or UMD module.
        if dep.pluginName in [undefined, 'node'] # plugin 'node' is dummy: just signals a require effective only
                                                 # on node execution, hence ommited from arrayDeps.
          l.debug("@nodeRequire '#{_modulePath}'") if l.deb 95
          attempts.push # @todo: (7 2 1) store @module.require.paths
              modulePath: _modulePath
              requireUsed: 'nodeRequire'
              resolvedPathNo: resolvedPathNo
              dependency:
                name: dep.name()
                type: dep.type
          try
            loadedModule = @nodeRequire _modulePath
          catch err
            err = {name:"`catch err` but err was UNDEFINED!"} if _.isUndefined err
            if err1 is undefined or not _.startsWith(err.toString(), "Error: Cannot find module") # prefer to keep 'generic' errors in err1
              err1 = err

            l.debug("FAILED: @nodeRequire '#{_modulePath}' \n err=\n", err) if l.deb 35
            _.extend _.last(attempts),
                urequireError: "Error loading node or UMD module through nodejs require."
                error:
                  name:err.name
                  message:err.message
                  errToString:err.toString()
                  err: err

            _modulePath = upath.addExt _modulePath, '.js' # make sure we have it WHY ? @todo: Q: can it be if global ?

            if not dep.isGlobal() # globals are loaded by node's require, even from RequireJS ?
              l.debug("FAILURE caused: @getRequirejs() '#{_modulePath}'") if l.deb 25
              attempts.push
                  modulePath: _modulePath
                  requireUsed: 'RequireJS'
                  resolvedPathNo: resolvedPathNo
                  dependency:
                    name: dep.name()
                    type: dep.type
              try
                loadedModule = @getRequirejs() _modulePath
              catch err
                err = {name:"`catch err` but err was UNDEFINED!"} if _.isUndefined err
                err2 = err
                l.debug("FAILED: @getRequirejs() '#{_modulePath}' \n err=#{err2}") if l.deb 35
                _.extend _.last(attempts),
                    urequireError: "Error loading module through RequireJS; it previously failed with node's require."
                    error:
                      name:err.name
                      message:err.message
                      errToString:err.toString()
                      err: err
        else
          _modulePath = "#{dep.pluginName}!#{_modulePath}"
          l.debug("PLUGIN caused: @getRequirejs() '#{_modulePath}'") if l.deb 25
          attempts.push
            modulePath: _modulePath
            requireUsed: 'RequireJS'
            resolvedPathNo: resolvedPathNo
            dependency:
              name: dep.name()
              type: dep.type
              pluginName: dep.pluginName
            pluginPaths: @requireJSConfig?.paths[dep.pluginName]
            pluginResolvedPaths: @requirejs?.s?.contexts?._?.config?.paths[dep.pluginName]
          try
            loadedModule = @getRequirejs() _modulePath # pluginName!modulePath
          catch err
            err = {name:"`catch err` but err was UNDEFINED!"} if _.isUndefined err
            err3 = err
            _.extend _.last(attempts),
              urequireError: "Error loading *plugin* module through RequireJS."
              error:
                name: err.name
                message: err.message
                errToString:err.toString()
                err: err

    if not loadedModule
      l.err """\n
          *uRequire #{l.VERSION}*: failed to load dependency: '#{dep}' in module '#{@moduleNameBR}' from #{_modulePath}
          Quiting with throwing 1st error - Detailed attempts follow:
          #{l.prettify att for att in attempts}

          Debug info:\n
        """, @debugInfo

      throw err1
    else
      l.debug("""
        #{if isCached then "CACHE-" else ''}loaded module: '#{dep.name()}'
                from : '#{_modulePath}' :-)
      """) if l.deb 70
      if not isCached
        l.debug("""
          debugInfo = \u001b[33m#{@debugInfo}"
        """) if l.deb 50

      return @cachedModules[_modulePath] = loadedModule # caching as 'plugin!filename' (if its plugin loaded)


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
  @return {module} module loaded if called *synchronously*, or `undefined` if it was called *asynchronously* (why?)
  ###
  require: (
      strDeps # type: [ 'String', '[]<String>' ]
      callback  # type: '()->'
  )=>
    if _.isString strDeps # String - synchronous call
      return @loadModule new Dependency strDeps, @moduleNameBR
    else
      if _.isArray strDeps # we have an []<String>:
        deps = [] # []<Dependency>

        #isAllCached = true # not needed anymore
        for strDep in strDeps
          deps.push dep = new Dependency strDep, @moduleNameBR
          # checking if all cached not needed anymore in 2.1.x
          #cacheName = dep.name plugin:yes, relativeType:'bundle', ext:yes
          #if @cachedModules[cacheName] is undefined
          #  isAllCached = false # note if any dep not already loaded/cached

        loadDepsAndCall = => # load dependencies and then callback()
          loadedDeps = []
          for dep in deps
            loadedDeps.push @loadModule(dep)

          # todo: should we check cb, before wasting time requiring modules ?
          #       Or maybe it was intentional, for caching modules asynchronously.
          if _.isFunction callback
            callback.apply null, loadedDeps

#            if isAllCached #load *synchronously* (matching RequireJS's behaviour, when all modules are already loaded/cached!)
#              loadDepsAndCall()
#            else
        process.nextTick -> #load asynchronously
          loadDepsAndCall()

    undefined

module.exports = NodeRequirer