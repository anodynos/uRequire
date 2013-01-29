#todo: add tests
resolvePathToFromModuleRoot = (moduleName, pathFromModuleRoot)->
  pathRelative = require './pathRelative'
  _path = require 'path'

  stepsToBundleRoot = pathRelative "$/#{_path.dirname moduleName}", '$/', {dot4Current:true}

  if pathFromModuleRoot
    if pathFromModuleRoot[0] is '.' # a path relative to bundleRoot. Pass it as relative to this module
      res = _path.normalize stepsToBundleRoot + '/' + pathFromModuleRoot
    else
      res = pathFromModuleRoot # absolute OS path
  else #default is bundle's root
    res = stepsToBundleRoot

  return res.replace /\\/g, '/'


module.exports = resolvePathToFromModuleRoot