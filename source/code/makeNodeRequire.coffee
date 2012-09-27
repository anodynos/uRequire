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

  resolveAndRequire = (dep)->
    altRes = dep # not really needed at all, but BBSTS
    if dep[0] is '.' #relative to requiring file's dir
      res = dirname + '/' + dep
    else
      if dep[0] is '/' # web-root path
        if webRoot[0] is '.' #web root is relative to bundle root
          res = dirname + '/' + webRoot + dep
        else
          res = webRoot + dep # an OS file system dir, as-is
      else # relative to bundle eg 'a/b/c', OR global eg 'underscore' todo: global is not handled!
        res = dep # global most probable
        altRes = dirname + '/' + pathRelative("$/#{modulePath}", "$/" + dep)
        [res, altRes] = [altRes, res] if res.match /\//
    #load module with native require
    try
      resMod = require res
    catch error
      try
        resMod = require altRes
      catch error
        console.log 'uRequire: failed to load module:', dep, ' from:', res, ' and ', altRes

    return resMod

  nodeRequire = (deps, cb) ->
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

