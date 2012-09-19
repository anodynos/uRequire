
#
# node's require
#
# It is used synchronoysly or synchronoysly, depending on how it was called
# - sync (blocking) when call was made the nodejs way `require('dependency')` in which case the module is returned
# - async (immediatelly returning), when the call was made the AMD/requirejs way `require(['dep1', 'dep2'], function(dep1, dep2) {})`
#   in which case the call back is called when all dependencies have been loaded asynchronously.
module.exports = (modulePath, dirname, webRoot)->
  pathRelative = require './utils/pathRelative'

  resolve = (dep)->
    if dep[0] is '.' #relative to requiring file's dir
      res = dirname + '/' + dep
    else
      if dep[0] is '/' # web-root path
        if webRoot[0] is '.' #web root is relative to bundle root
          res = dirname + '/' + webRoot + dep
        else
          res = webRoot + dep # an OS file system dir, as-is
      else # an absolute (relative to bundle) path like a/b/c
        res = dirname + '/' + pathRelative("$/#{modulePath}", "$/" + dep)

    return res

  nodeRequire = (deps, cb) ->
    if Object::toString.call(deps) is "[object String]" # just pass to node's sync require
      return require resolve deps
    else # asynchronously load dependencies, and then callback()
      setTimeout ->
        relDeps = []
        for dep in deps
          relDeps.push require resolve dep

        # todo : should we check cb, before wasting time requiring modules ? Or maybe it was intentional, for caching modules asynchronously
        if (Object::toString.call cb) is "[object Function]"
          cb.apply null, relDeps
      ,0

# TODO: make test specs!
#relativeAsyncRequire = makeRelativeAsynchRequire 'views/'
#relativeAsyncRequire ['views/PersonEditVi