#todo: add tests
resolveWebRoot = (modyle, webRootMap)->
  pathRelative = require './utils/pathRelative'
  _path = require 'path'

  stepsToBundleRoot = pathRelative "$/#{_path.dirname modyle}", '$/', {dot4Current:true}
  if webRootMap
    if webRootMap[0] is '.' # a path relative to bundle. Pass it as relative to this module
      res = _path.normalize stepsToBundleRoot + '/' + webRootMap
    else
      res = webRootMap # absolute OS path
  else #default is bundle's root
    res = stepsToBundleRoot

  return res.replace /\\/g, '/'


module.exports = resolveWebRoot