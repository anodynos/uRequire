module.exports = (modulePath, dirname)->
  _path = require 'path'

  nodeRequire = (deps, cb) ->
    relDeps = []

    #todo trigger a sync-only call
    if Object::toString.call(deps) is "[object String]"
      deps = [deps]

    for dep in deps
      relDeps.push require dirname + '/' + _path.relative("$/#{modulePath}", "$/" + dep)

    if Object::toString.call(cb) is "[object Function]"
      cb.apply null, relDeps
    else
      relDeps[0]



# TODO: make test specs!
#relativeAsyncRequire = makeRelativeAsynchRequire 'views/'
#relativeAsyncRequire ['views/PersonEditVi