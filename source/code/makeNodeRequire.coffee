# node's require
#
# It resolves and loads module, synchronoysly or synchronoysly, depending on how it was called
# - sync (blocking) when call was made the nodejs way `require('dependency')` in which case the module is returned
# - async (immediatelly returning), when called the AMD/requirejs way `require(['dep1', 'dep2'], function(dep1, dep2) {})`
#   in which case the call back is called when all dependencies have been loaded asynchronously.
# TODO: make testeable with specs!
# TODO: mimic the inconsistent requireJS behaviour on the require [..],->
#       where if all deps are loaded before, then the call is SYNCRONOUS :-(
#       Refactor & make it a shared instance among modules: save memory & also note what modules have been loaded.
# todo: prepare for inline version - is it feasible ?
module.exports = (modulePath, dirname, webRoot)->
  pathRelative = require './utils/pathRelative'
  _path = require 'path'
  bundleRoot = dirname + '/' + (pathRelative "$/#{_path.dirname modulePath}", "$/") + '/'

  try
    rjsc = require('fs').readFileSync bundleRoot + 'requireJSConfig.json', 'utf-8'
  catch error
    #do nothing
  if rjsc
    try
      requireJSConfig = JSON.parse rjsc
    catch error
      console.error "uRequire: error parsing requireJSConfig.json from #{bundleRoot + 'requireJSConfig.json'}"

  if requireJSConfig?.baseUrl
    baseUrl = requireJSConfig.baseUrl
    if baseUrl[0] is '/' #web root as reference
      bundleRoot = dirname + '/' + webRoot + baseUrl + '/'
    else #bundleRoot as reference
      bundleRoot = bundleRoot + baseUrl + '/'

  resolveAndRequire = (dep)->
    resolved = []
    if dep[0] is '.' #relative to requiring file's dir
      resolved.push dirname + '/' + dep
    else
      if dep[0] is '/' # web-root path
        if webRoot[0] is '.' #web root is relative to bundle root
          resolved.push dirname + '/' + webRoot + dep # webRoot is hardwired as path-from-moduleDir
        else
          resolved.push webRoot + dep # an OS file system dir, as-is
      else # requireJS baseUrl/Paths
        pathStart = dep.split('/')[0]
        if requireJSConfig?.paths?[pathStart] #eg src/
          paths = requireJSConfig.paths[pathStart]
          if Object::toString.call(paths) is "[object String]" #avoiding dependency with _
            paths = [ paths ] #else _(paths).isArray()

          for path in paths # add them all
            resolved.push bundleRoot + (dep.replace pathStart, path)
        else
          if dep.match /\// # relative to bundle eg 'a/b/c',
            resolved.push bundleRoot + dep
          else # a single pathpart, like 'underscore' or 'myLib'
            resolved.push bundleRoot + dep # bundleRelative
            resolved.push dep              # or global eg 'underscore'

    #load module with native require
    resMod = null
    for res in resolved when resMod is null
      try
        resMod = require res
      catch error

    if resMod is null
      console.error """
        uRequire: failed to load dependency: '#{dep}' in module '#{modulePath}'
        Tried : #{'\n' + res for res in resolved }
        Quiting with process.exit(1)
        """
      process.exit(1)

    return resMod


  return nodeRequire = (deps, cb) ->
    if Object::toString.call(deps) is "[object String]" # just pass to node's sync require
      return resolveAndRequire deps
    else # we have an array: asynchronously load dependencies, and then callback()
      process.nextTick ->
        relDeps = []
        for dep in deps
          relDeps.push resolveAndRequire(dep)

        # todo : should we check cb, before wasting time requiring modules ? Or maybe it was intentional, for caching modules asynchronously
        if (Object::toString.call cb) is "[object Function]"
          cb.apply null, relDeps