# node's require
#
# It resolves and loads module, synchronoysly or synchronoysly, depending on how it was called
# - sync (blocking) when call was made the nodejs way `require('dependency')` in which case the module is returned
# - async (immediatelly returning), when called the AMD/requirejs way `require(['dep1', 'dep2'], function(dep1, dep2) {})`
#   in which case the call back is called when all dependencies have been loaded asynchronously.
# TODO: make testeable with specs!
# DONE: mimic the inconsistent requireJS behaviour on the require [..],->
#       where if all deps are loaded before, then the call is SYNCHRONOUS :-(
#       Refactor & make it a shared instance among modules: save memory & also note what modules have been loaded.
_ = require 'lodash'
_fs = require 'fs'
_path = require 'path'
pathRelative = require './utils/pathRelative'
Dependency = require './Dependency'
nodeLoaderPlugins = require './nodeLoaderPlugins'

class NodeRequirer
  constructor: (@modyle, @dirname, @webRoot)->
    @bundleRoot = dirname + '/' + (pathRelative "$/#{_path.dirname @modyle}", "$/") + '/'

    try
      @nodeUserLoaderPlugins = require "#{@bundleRoot}/nodeUserLoaderPlugins"
    catch error

    try
      rjsc = require('fs').readFileSync @bundleRoot + 'requirejs.config.json', 'utf-8'
    catch error
      #do nothing, we just dont have a requirejs.config.json

    if rjsc
      try
        @requireJSConfig = JSON.parse rjsc
      catch error
        console.error "urequire: error parsing requirejs.config.json from #{bundleRoot + 'requirejs.config.json'}"

      if @requireJSConfig?.baseUrl
        baseUrl = @requireJSConfig.baseUrl
        if baseUrl[0] is '/' #web root as reference
          @bundleRoot = @dirname + '/' + @webRoot + baseUrl + '/'
        else #bundleRoot as reference
          @bundleRoot = @bundleRoot + baseUrl + '/'

    
  cachedModules: {} # class / static : shared among all instances
  
  resolvePaths: (dep)->
    depName = dep.name plugin:no, ext:yes
    
    candPaths = []
    if dep.isFileRelative() #relative to requiring file's dir
      candPaths.push @dirname + '/' + depName
    else
      if dep.isWebRoot() # web-root path
        if @webRoot[0] is '.' #web root is relative to bundle root
          candPaths.push @dirname + '/' + @webRoot + depName   # webRoot is hardwired as path-from-moduleDir
        else
          candPaths.push @webRoot + depName  # an OS file system dir, as-is
      else # requireJS baseUrl/Paths
        pathStart = depName.split('/')[0]
        if @requireJSConfig?.paths?[pathStart] #eg src/
          paths = @requireJSConfig.paths[pathStart]
          if Object::toString.call(paths) is "[object String]" #avoiding dependency with _
            paths = [ paths ] #else _(paths).isArray()

          for path in paths # add them all
            candPaths.push @bundleRoot + (depName.replace pathStart, path)
        else
          if dep.isRelative()  # relative to bundle eg 'a/b/c',
            candPaths.push @bundleRoot + depName
          else # a single pathpart, like 'underscore' or 'myLib'
            candPaths.push depName     # global eg 'underscore' (most likely)
            candPaths.push @bundleRoot + depName  # or bundleRelative (unlikely)

    return candPaths
    
  ###
  @param dep The Dependency to be resolved
  @returns loaded module
  ###
  loadModule: (dep)=>
    cacheName = dep.name plugin:yes, relativeType:'bundle', ext:yes
    if @cachedModules[cacheName]
      @cachedModules[cacheName]
    else #load module with either native require or some plugin!
      errs = []
      loadedModule = null
      candPaths = @resolvePaths(dep)
      for cand in candPaths when loadedModule is null
        try
          loadedModule = @cachedModules[cacheName] =
            if dep.pluginName in [undefined, 'node']
              require cand
            else
              plugin = null
              for nlp in [@nodeUserLoaderPlugins, nodeLoaderPlugins] when plugin is null
                if _(nlp[dep.pluginName]).isFunction()
                  plugin = nlp[dep.pluginName]

              if plugin
                plugin cand
              else
                console.error """
                  urequire: unknown pluginName '#{dep.pluginName}' for dep #{dep}
                  Quiting with process.exit(1)
                """
                process.exit(1)
        catch error
          errs.push error

      if loadedModule is null
        console.error """
            urequire: failed to load dependency: '#{dep}' in module '#{@modyle}'
            Tried : #{"\n#{cand}\n#{errs[i]}\n" for cand, i in candPaths }
            Quiting with process.exit(1)
          """
        process.exit(1)
      else
        return loadedModule

  require: (
      strDeps # type: [ 'String', '[]<String>' ]
      callback  # type: '()->'
    )=>
        if Object::toString.call(strDeps) is "[object String]" # String - synch call
          return @loadModule new Dependency strDeps, @modyle
        else # we have an []<String>:
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

            # todo: should we check cb, before wasting time requiring modules ? Or maybe it was intentional, for caching modules asynchronously
            if (Object::toString.call callback) is "[object Function]"
              callback.apply null, loadedDeps

          if isAllCached #load *synchronously* (matching RequireJS's behaviour, when all modules are already loaded/cached!)
            loadDepsAndCall()
          else
            process.nextTick -> #load asynchronously
              loadDepsAndCall()

module.exports = NodeRequirer