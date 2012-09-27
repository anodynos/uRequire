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
    bu = requireJSConfig.baseUrl
    if bu[0] is '/' #web root as reference
      bundleRoot = dirname + '/' + webRoot + bu + '/'
    else #bundleRoot as reference
      bundleRoot = bundleRoot + bu + '/'

  resolveAndRequire = (dep)->
    if dep[0] is '.' #relative to requiring file's dir
      res = dirname + '/' + dep
    else
      if dep[0] is '/' # web-root path
        if webRoot[0] is '.' #web root is relative to bundle root
          res = dirname + '/' + webRoot + dep # webRoot is hardwired as path-from-moduleDir
        else
          res = webRoot + dep # an OS file system dir, as-is
      else # bundleRelative, global, or requireJS baseUrl/Paths
        pathStart = dep.split('/')[0]
        if requireJSConfig?.paths?[pathStart] #eg src/
          res = bundleRoot + (dep.replace pathStart, requireJSConfig.paths[pathStart])
        else
          if dep.match /\// # relative to bundle eg 'a/b/c',
            res = bundleRoot + dep
          else # a single pathpart, like 'underscore' or 'myLib'
            res = bundleRoot + dep # bundleRelative
            altRes = dep  # or global

    #load module with native require
    try
      resMod = require res
    catch error
      errMsg = """
        uRequire: failed to load dependency: '#{dep}' in module '#{modulePath}''
        Tried  '#{res}' #{if altRes then "\n and '"+ altRes + "'" else ''}
        Quiting with process.exit(1)
        """
      if altRes
        try
          resMod = require altRes
        catch error
          console.log errMsg
          process.exit(1)
      else
        console.log errMsg
        process.exit(1)

    return resMod


  return nodeRequire = (deps, cb) ->
    if Object::toString.call(deps) is "[object String]" # just pass to node's sync require
      return resolveAndRequire deps
    else # we have an array: asynchronously load dependencies, and then callback()
      setTimeout ->
        relDeps = []
        for dep in deps
          relDeps.push resolveAndRequire(dep)

        # todo : should we check cb, before wasting time requiring modules ? Or maybe it was intentional, for caching modules asynchronously
        if (Object::toString.call cb) is "[object Function]"
          cb.apply null, relDeps
      ,0

