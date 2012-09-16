
#
# node's require
#
# It is used synchronoysly or synchronoysly, depending on how it was called
# - sync (blocking) when call was made the nodejs way `require('dependency')` in which case the module is returned
# - async (immediatelly returning), when the call was made the AMD/requirejs way `require(['dep1', 'dep2'], function(dep1, dep2) {})`
#   in which case the call back is called when all dependencies have been loaded asynchronously.
module.exports = (modulePath, dirname)->
  _path = require 'path'

  resolve = (dep)->
    dirname + '/' + _path.relative("$/#{modulePath}", "$/" + dep)

  nodeRequire = (deps, cb) ->

    if Object::toString.call(deps) is "[object String]" # just pass to node's a sync only require
      return require resolve deps
    else # asynchronously load dependencies, and then call the call back
      setTimeout ->
        relDeps = []
        for dep in deps
          relDeps.push require resolve deps

        # todo : should we check cb, before wasting time requiring modules ? Or maybe it was intentional, for caching modules asynchronously
        if Object::toString.call(cb) is "[object Function]"
          cb.apply null, relDeps
      ,0





# TODO: make test specs!
#relativeAsyncRequire = makeRelativeAsynchRequire 'views/'
#relativeAsyncRequire ['views/PersonEditVi