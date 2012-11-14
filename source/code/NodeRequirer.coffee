_ = require 'lodash'
_fs = require 'fs'
upath = require './paths/upath'
pathRelative = require './paths/pathRelative'
Dependency = require './Dependency'

###
The `nodejs`'s require facility.

An instance of `NodeRequirer` is created for each UMD module, when running on node. Its purpose is to resolve and load modules, synchronoysly or asynchronoysly, depending on how it was called:

  * sync (blocking): when call was made the nodejs way `require('dependency')` in which case the module is simply loaded & returned.

  * async (immediatelly returning): when called the AMD/requirejs way `require(['dep1', 'dep2'], function(dep1, dep2) {})` in which case the callback function is called, when all modules/dependencies have been loaded asynchronously.

@note: it used to mimic the inconsistent RequireJS 2.0.x behaviour on the `require([..],->`, where if all deps are loaded before, then the call is SYNCHRONOUS :-(. It is now reverted to the [always asynch 2.1.x behaviour](https://github.com/jrburke/requirejs/wiki/Upgrading-to-RequireJS-2.1#wiki-breaking-async)

@author Agelos Pikoulas

@todo: make testeable with specs!
###
class NodeRequirer
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props
  Function::staticProperty = (props) => Object.defineProperty @::, name, descr for name, descr of props

  ###
  Create a NodeRequirer instance, passing paths resolution information.

  @param {String} modyle `module` name of current UMD module (that calls 'require'). Relative to bundle, eg 'models/Person', as hardcoded in generated uRequire UMD.
  @param {String} dirname `__dirname` passed at runtime from the UMD module, poiniting to its self (i.e filename of the .js file).
  @param {String} webRootMap where '/' is mapped when running on nodejs, as hardcoded in uRequire UMD (relative to bundleRoot).
  ###
  constructor: (@modyle, @dirname, @webRootMap)->
    @bundleRoot = upath.normalize (
      @dirname + '/' + (pathRelative "$/#{upath.dirname @modyle}", "$/") + '/'
    )

    if @getRequireJSConfig().baseUrl
      oldBundleRoot = @bundleRoot
      baseUrl = @getRequireJSConfig().baseUrl
#      if baseUrl[0] is '/' #web root as reference
#        @bundleRoot = upath.normalize @webRoot + '/' + baseUrl + '/'
#      else #bundleRoot as reference
#        @bundleRoot = upath.normalize @bundleRoot + '/' + baseUrl + '/'

      @bundleRoot = upath.normalize (
        if baseUrl[0] is '/'  #web root as reference
          @webRoot
        else                  #bundleRoot as reference
          @bundleRoot
        ) + '/' + baseUrl + '/'

      if oldBundleRoot isnt @bundleRoot # store requireJSConfig for this new @bundleRoot
        NodeRequirer::requireJSConfigs[@bundleRoot] = NodeRequirer::requireJSConfigs[oldBundleRoot]

  @property
    webRoot:
      get: -> upath.normalize "#{
        if @webRootMap[0] is '.' # hardwired as path from bundleRoot
          @bundleRoot + '/' + @webRootMap
        else
          @webRootMap # an OS file system dir, as-is
        }"

  ###
  @property {Function}
  A @staticProperty (class variable) that defaults to node's `require`.
  It can be swaped with another/mock version (eg by spec tests).
  ###
  nodeRequire: undefined # only for Codo's sake! Its properly defined below as a static property

  @staticProperty
    nodeRequire:
      get: => @_nodeRequire or require
      set: (@_nodeRequire)=>


  ###
  @property {Set<module>}
  Stores all modules loaded so far. Its `static` i.e a class variable, shared among all instances.
  ###
  cachedModules: {}

  ###
  Load 'requirejs.config.json' for @bundleRoot & cache it with @bundleRoot as key.
  @return {RequireJSConfig object} the requireJSConfig for @bundleRoot (or {} if 'requirejs.config.json' not found/not valid json)
  ###
  getRequireJSConfig: ->
    NodeRequirer::requireJSConfigs ?= {}  # static / store in class

    if NodeRequirer::requireJSConfigs[@bundleRoot] is undefined
      try
        rjsc = require('fs').readFileSync @bundleRoot + 'requirejs.config.json', 'utf-8'
      catch error
        # console.error "urequire: error loading requirejs.config.json from #{@bundleRoot + 'requirejs.config.json'}"
        #do nothing, we just dont have a requirejs.config.json

      if rjsc
        try
          NodeRequirer::requireJSConfigs[@bundleRoot] = JSON.parse rjsc
        catch error
          console.error "urequire: error parsing requirejs.config.json from #{@bundleRoot + 'requirejs.config.json'}"

      NodeRequirer::requireJSConfigs[@bundleRoot] ?= {} # if still undefined, after so much effort

    return NodeRequirer::requireJSConfigs[@bundleRoot]

  ###
  Load the [Requirejs](http://requirejs.org/) system module (as npm installed), & cache for @bundleRoot as key.

  Then cache it in static NodeRequirer::requirejsLoaded[@bundleRoot], so only one instance
  is shared among all `NodeRequirer`s for a given @bundleRoot. Hence, its created only once,
  first time it's needed (for each distinct @bundleRoot).

  It is configuring rjs with resolved paths, for each of the paths entry in `requirejs.config.json`.
  Resolved paths are relative to `@bundleRoot` (instead of `@dirname`).

  @return {requirejs} The module `RequireJS` for node, configured for this @bundleRoot.
  ###
  getRequirejs: ->
    NodeRequirer::requirejsLoaded ?= {}  # static / store in class

    if not NodeRequirer::requirejsLoaded[@bundleRoot]
      requirejs = @nodeRequire 'requirejs'

      requireJsConf =
        nodeRequire: @nodeRequire
        baseUrl: @bundleRoot

      # resolve each path, as we do in modules - take advantage of webRoot etc.
      if @getRequireJSConfig().paths
        requireJsConf.paths = {}
        for pathName, pathEntries of @getRequireJSConfig().paths
          if not _(pathEntries).isArray()
            pathEntries = [ pathEntries ]

          requireJsConf.paths[pathName] or= []

          for pathEntry in pathEntries
            for resolvedPath in @resolvePaths(new Dependency(pathEntry), @bundleRoot) #rjs paths are relative to bundleRoot, not some file
              requireJsConf.paths[pathName].push resolvedPath if not (resolvedPath in requireJsConf.paths[pathName])

      requirejs.config requireJsConf

      NodeRequirer::requirejsLoaded[@bundleRoot] = requirejs

    return NodeRequirer::requirejsLoaded[@bundleRoot]

  ###
  For a given `Dependency`, resolve *all possible* paths to the file.

  `resolvePaths` is respecting:
       - The `Dependency`'s own semantics, eg `webRoot` if `dep` is relative to web root (i.e starts with `\`) and similarly for isRelative etc. See <code>Dependency</code>
       - `@relativeTo` param, which defaults to the module file calling `require` (ie. @dirname), but can be anything eg. @bundleRoot.
       - `requirejs` config, if it exists in this instance of NodeRequirer

  @param {Dependency} dep The Dependency instance whose paths we are resolving.
  @param {String} relativeTo Resolve relative to this path. Default is `@dirname`, i.e the module/file that called `require`

  @return {Array<String>} The resolved paths of the Dependency
  ###
  resolvePaths: (dep, relativeTo = @dirname)->
    depName = dep.name plugin:no, ext:yes

    resPaths = []
    if dep.isFileRelative() #relative to requiring file's dir
      resPaths.push relativeTo + '/' + depName
    else
      if dep.isWebRoot() # web-root path
        resPaths.push @webRoot + depName
      else # requireJS baseUrl/Paths
        pathStart = depName.split('/')[0]
        if @getRequireJSConfig().paths?[pathStart] #eg src/
          paths = @getRequireJSConfig().paths[pathStart]
          if not _(paths).isArray()
            paths = [ paths ] #else _(paths).isString()

          for path in paths # add them all
            resPaths.push @bundleRoot + (depName.replace pathStart, path)
        else
          if dep.isRelative()  # relative to bundle eg 'a/b/c',
            resPaths.push @bundleRoot + depName
          else # a single pathpart, like 'underscore' or 'myLib'
            resPaths.push depName     # global eg 'underscore' (most likely)
            resPaths.push @bundleRoot + depName  # or bundleRelative (unlikely)

    return resPaths

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
  loadModule: (dep)=>
    cacheName = dep.name plugin:yes, relativeType:'bundle', ext:yes
    if @cachedModules[cacheName]
      @cachedModules[cacheName]
    else #load module either via nodeRequire OR requireJS if it needs a plugin or if it fails!
      attempts = []
      modulePaths = @resolvePaths dep
      loadedModule = null
      for modulePath in modulePaths when not loadedModule
        if dep.pluginName in [undefined, 'node'] # load a simple node or UMD module
          try
            loadedModule = @nodeRequire modulePath
          catch err
            attempts.push {
              urequireError: "Error loading node or UMD module through node's require."
              modulePath: modulePath, requireUsed: 'nodeRequire', error: err}
            try
              loadedModule = @getRequirejs() modulePath + '.js'
            catch err
              attempts.push {
                urequireError: "Error loading module through RequireJS; it previously failed with node's require."
                modulePath: modulePath, requireUsed: 'RequireJS', error: err}

        else # load a plugin!module, through RequireJS for node
          try
            loadedModule = @getRequirejs() "#{dep.pluginName}!#{modulePath}"
          catch err
            attempts.push {
              urequireError: "Error loading plugin module through RequireJS.", plugin: dep.pluginName
              pluginPaths: @requireJSConfig?.paths[dep.pluginName]
              pluginResolvedPaths: @requirejs?.s?.contexts?._?.config?.paths[dep.pluginName]
              modulePath: "#{dep.pluginName}!#{modulePath}", requireUsed: 'RequireJS', error: err}


      if not loadedModule
        console.error """
            urequire: failed to load dependency: '#{dep}' in module '#{@modyle}'
            Quiting with process.exit(1)

            Detailed attempts:
          """
        console.log 'loadedModule = ', loadedModule
        console.log att for att in attempts

        process.exit(1)
      else
        return @cachedModules[cacheName] = loadedModule

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
    if _(strDeps).isString() # String - synchronous call
      return @loadModule new Dependency strDeps, @modyle
    else
      if _(strDeps).isArray() # we have an []<String>:
        deps = [] # []<Dependency>

        #isAllCached = true # not needed anymore
        for strDep in strDeps
          deps.push dep = new Dependency strDep, @modyle
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
          if _(callback).isFunction()
            callback.apply null, loadedDeps

#            if isAllCached #load *synchronously* (matching RequireJS's behaviour, when all modules are already loaded/cached!)
#              loadDepsAndCall()
#            else
        process.nextTick -> #load asynchronously
          loadDepsAndCall()

    undefined

module.exports = NodeRequirer