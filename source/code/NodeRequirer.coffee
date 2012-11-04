# node's require
#
# It resolves and loads module, synchronoysly or synchronoysly, depending on how it was called
# - sync (blocking) when call was made the nodejs way `require('dependency')` in which case the module is returned
# - async (immediatelly returning), when called the AMD/requirejs way `require(['dep1', 'dep2'], function(dep1, dep2) {})`
#   in which case the call back is called when all dependencies have been loaded asynchronously.
# TODO: make testeable with specs!
# DONE: mimic the inconsistent requireJS behaviour on the require [..],->
#       where if all deps are loaded before, then the call is SYNCRONOUS :-(
#       Refactor & make it a shared instance among modules: save memory & also note what modules have been loaded.
pathRelative = require './utils/pathRelative'
_path = require 'path'
Dependency = require './Dependency'
_ = require 'lodash'

class NodeRequirer
  constructor: (@modyle, @dirname, @webRoot)->
    @bundleRoot = dirname + '/' + (pathRelative "$/#{_path.dirname @modyle}", "$/") + '/'

    try
      rjsc = require('fs').readFileSync @bundleRoot + 'requirejs.config.json', 'utf-8'
    catch error
      #do nothing

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

  resolveAndRequire: (dep)=>
    depName = dep.name plugin:no, ext:yes
    cacheName = dep.name plugin:yes, relativeType:'bundle', ext:yes

    if @cachedModules[cacheName]
      return @cachedModules[cacheName]

    resolved = []
    if dep.isFileRelative() #relative to requiring file's dir
      resolved.push @dirname + '/' + depName
    else
      if dep.isWebRoot() # web-root path
        if @webRoot[0] is '.' #web root is relative to bundle root
          resolved.push @dirname + '/' + @webRoot + depName   # webRoot is hardwired as path-from-moduleDir
        else
          resolved.push @webRoot + depName  # an OS file system dir, as-is
      else # requireJS baseUrl/Paths
        pathStart = depName.split('/')[0]
        if @requireJSConfig?.paths?[pathStart] #eg src/
          paths = @requireJSConfig.paths[pathStart]
          if Object::toString.call(paths) is "[object String]" #avoiding dependency with _
            paths = [ paths ] #else _(paths).isArray()

          for path in paths # add them all
            resolved.push @bundleRoot + (depName.replace pathStart, path)
        else
          if dep.isRelative()  # relative to bundle eg 'a/b/c',
            resolved.push @bundleRoot + depName
          else # a single pathpart, like 'underscore' or 'myLib'
            resolved.push depName     # global eg 'underscore' (most likely)
            resolved.push @bundleRoot + depName  # or bundleRelative (unlikely)

    #load module with native require
    resMod = null
    for res in resolved when resMod is null
      try
        resMod = @cachedModules[cacheName] = require res
      catch error

    if resMod is null
      console.error """
          urequire: failed to load dependency: '#{dep}' in module '#{@modyle}'
          Tried : #{'\n' + res for res in resolved }
          Quiting with process.exit(1)
        """
      process.exit(1)

    return resMod

  require: (strDeps, cb) =>
#    console.log "##### require(#{strDeps}) \n @dependencies=", _.keys @cachedModules
    if Object::toString.call(strDeps) is "[object String]" # just pass to node's sync require
      return @resolveAndRequire(new Dependency strDeps, @modyle)
    else # we have an array<string>:
      loadDepsAndCall = => # load dependencies and then callback()
        loadedDeps = []
        for dep in deps
          loadedDeps.push @resolveAndRequire(dep)

        # todo: should we check cb, before wasting time requiring modules ? Or maybe it was intentional, for caching modules asynchronously
        if (Object::toString.call cb) is "[object Function]"
          cb.apply null, loadedDeps


      deps = [] # array<Dependency>
      isAllCached = true
      for strDep in strDeps
        deps.push dep = new Dependency strDep, @modyle
        depName = dep.name plugin:yes, relativeType:'bundle', ext:yes
        if @cachedModules[depName] is undefined # not if all deps are already loaded/cached ]
          isAllCached = false

      if isAllCached #load *synchronously* (matching RequireJS's behaviour, when all modules are already loaded/cached!)
        loadDepsAndCall()
      else
        process.nextTick -> #load asynchronously
          loadDepsAndCall()

module.exports = NodeRequirer