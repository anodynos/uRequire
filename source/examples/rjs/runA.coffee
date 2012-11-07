requirejs = require 'requirejs'

requirejs.config
  nodeRequire: require
  paths:
    text: "../../../libs/requirejs_plugins/text"
    json: "../../../libs/requirejs_plugins/json"

console.log 'before requirejs call : typeof module == ',  (typeof module)

requirejs ['a-lib'], (a)->
  console.log a
  console.log 'inside requirejs call : typeof module == ',  (typeof module)
