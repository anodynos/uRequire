_ = require 'lodash'
_path = require 'path'

###
  upath is a proxy to node's 'path', replacing '\' with '/' for all string results :-)
###
upath = {}
for fName, fn of _path when _.isFunction fn
  upath[fName] = do (fName)->
    (p...)->
      res = _path[fName] p...
      if _.isString res
        res.replace /\\/g, '/'
      else
        res

module.exports = upath