# node's require
#
# It resolves and loads module, synchronoysly or synchronoysly, depending on how it was called
# - sync (blocking) when call was made the nodejs way `require('dependency')` in which case the module is returned
# - async (immediatelly returning), when called the AMD/requirejs way `require(['dep1', 'dep2'], function(dep1, dep2) {})`
#   in which case the call back is called when all dependencies have been loaded asynchronously.

# DONE: mimic the inconsistent requireJS behaviour on the require [..],->
#       where if all deps are loaded before, then the call is SYNCHRONOUS :-(

# DONE: Refactor & make it a shared instance among modules: save memory & also note what modules have been loaded.

# TODO: make testeable with specs!

# TODO: document it!

_ = require 'lodash'
_fs = require 'fs'
_path = require 'path'
pathRelative = require './utils/pathRelative'
Dependency = require './Dependency'

class NodeRequirer

  constructor: (@modyle, @dirname, @webRoot)->
    @bundleRoot = dirname + '/' + (pathRelative "$/#{_path.dirname @modyle}", "$/") + '/'

    try
      rjsc = require('fs').readFileSync @bundleRoot + 'requirejs.config.json', 'utf-8'
    catch error
      #do nothing, we just dont have a requirejs.config.json

    if rjsc
      try
        @requireJSConfig = JSON.parse rjsc
      catch error
        console.error "urequire: error parsing requirejs.config.json from #{@bundleRoot + 'requirejs.config.json'}"

      if @requireJSConfig?.baseUrl
        baseUrl = @requireJSConfig.baseUrl
        if baseUrl[0] is '/' #web root as reference
          @bundleRoot = @dirname + '/' + @webRoot + baseUrl + '/'
        else #bundleRoot as reference
          @bundleRoot = @bundleRoot + baseUrl + '/'

  ###
    For a given `Dependency`, resolve (all possible) path for the file,
    respecting
      * `relativeTo` param, which usually is the module file calling ie. @dirname, but can be anything eg. @bundleRoot.
      * webRoot if given
      * requirejs config, if it exists.

  @param dep Dependency
  @param relativeTo String resolve relative to (default @dirname, i.e calling file )

  ###
  resolvePaths: (dep, relativeTo=@dirname )->
    depName = dep.name plugin:no, ext:yes
    
    resPaths = []
    if dep.isFileRelative() #relative to requiring file's dir
      resPaths.push relativeTo + '/' + depName
    else
      if dep.isWebRoot() # web-root path
        if @webRoot[0] is '.' #web root is relative to bundle root
          resPaths.push relativeTo + '/' + @webRoot + depName   # webRoot is hardwired as path-from-moduleDir
        else
          resPaths.push @webRoot + depName  # an OS file system dir, as-is
      else # requireJS baseUrl/Paths
        pathStart = depName.split('/')[0]
        if @requireJSConfig?.paths?[pathStart] #eg src/
          paths = @requireJSConfig.paths[pathStart]
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
  Simply load the Requirejs system, first time its needed.
  Its `static`, i.e one shared instance among all `NodeRequirer`s.

  It mainly @resolvePaths for each paths entry in `requirejs.config.json`
  creating one or more resolved paths for each.

  Since this is a shared instance, its always relative to @bundleRoot

  ###
  getRequireJS: ->
    if not @requirejs                               # setup requireJS for the first time
#      console.log "#### setup requireJS for the first time"
      NodeRequirer::requirejs = require 'requirejs' # shared among all instances of NodeRequirers, with a common config

      requireJsConf =
        nodeRequire: require
        baseUrl: @bundleRoot

      # resolve each path, as we do in modules - take advantage of webRoot etc.
      if @requireJSConfig?.paths
        requireJsConf.paths = {}
        for pathName, pathEntries of @requireJSConfig?.paths
          if not _(pathEntries).isArray()
            pathEntries = [ pathEntries ]

          requireJsConf.paths[pathName] or= []

          for pathEntry in pathEntries
            for resolvedPath in @resolvePaths(new Dependency(pathEntry), @bundleRoot) #rjs paths are relative to bundleRoot, not some file
              requireJsConf.paths[pathName].push resolvedPath if not (resolvedPath in requireJsConf.paths[pathName])

      @requirejs.config requireJsConf

    return @requirejs

  ###
    Stores all modules loaded so far.
    Static / class variable, shared among all instances
  ###
  cachedModules: {}

  ###
  #Actually loads *one* module.

  Uses either node's `require` or the synchronous version of `RequireJs`'s for modules that :
    * either have a plugin (eg "text!module.txt" )
    * or modules that fail to load with node's require (assumed to be native AMD)

  It makes more than one attempts to find the module and
  if any fails it notes loading errors
  and QUITS with process.exit(1) if all fail.

  @param dep The Dependency to be load.
  @returns loaded module (or quits if it fails)

  ###
  loadModule: (dep)=>
    cacheName = dep.name plugin:yes, relativeType:'bundle', ext:yes
    if @cachedModules[cacheName]
      @cachedModules[cacheName]
    else #load module either via node require OR requireJS if it needs a plugin or if it fails!
      attempts = []
      modulePaths = @resolvePaths dep
      loadedModule = null
      for modulePath in modulePaths when not loadedModule
        if dep.pluginName in [undefined, 'node'] # load a simple node or UMD module
          try
            loadedModule = require modulePath
          catch err
            attempts.push {
              urequireError: "Error loading node or UMD module through node's require."
              modulePath: modulePath, require: 'nodejs', error: err}
            try
              loadedModule = @getRequireJS() modulePath + '.js'
            catch err
              attempts.push {
                urequireError: "Error loading module through RequireJS; it previously failed with node's require."
                modulePath: modulePath, require: 'RequireJS', error: err}

        else # load a plugin!module, through RequireJS for node
          try
            loadedModule = @getRequireJS() "#{dep.pluginName}!#{modulePath}"
          catch err
            attempts.push {
              urequireError: "Error loading plugin module through RequireJS.", plugin: dep.pluginName
              pluginPaths: @requireJSConfig?.paths[dep.pluginName]
              pluginResolvedPaths: @requirejs?.s?.contexts?._?.config?.paths[dep.pluginName]
              modulePath: "#{dep.pluginName}!#{modulePath}", require: 'RequireJS', error: err}


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

  @param strDeps type: [ String, []<String> ]
      As `String`, its a single dependency to load *synchronously*, eg "models/person" or 'text!abc.txt'
      As `[]<String>`, its an array of dependencies to load *asynchronously*, eg [ "models/person" or 'text!abc.txt' ]

  @param callback The function to call whwn all dependencies are loaded, called asynchronously by default
          (or synchronously if all dependencies were cached, to match RequireJs's behaviour as of 2.0.x (check 2.1.?)
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

            isAllCached = true
            for strDep in strDeps
              deps.push dep = new Dependency strDep, @modyle
              cacheName = dep.name plugin:yes, relativeType:'bundle', ext:yes
              if @cachedModules[cacheName] is undefined
                isAllCached = false # note if any dep not already loaded/cached

            loadDepsAndCall = => # load dependencies and then callback()
              loadedDeps = []
              for dep in deps
                loadedDeps.push @loadModule(dep)

              # todo: should we check cb, before wasting time requiring modules ?
              # Or maybe it was intentional, for caching modules asynchronously
              if _(callback).isFunction()
                callback.apply null, loadedDeps

            if isAllCached #load *synchronously* (matching RequireJS's behaviour, when all modules are already loaded/cached!)
              loadDepsAndCall()
            else
              process.nextTick -> #load asynchronously
                loadDepsAndCall()

module.exports = NodeRequirer