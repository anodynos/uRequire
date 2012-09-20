`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define ['./c/c'], (c)->
  console.log 'started b'

  _ = require "/libs/lodash/lodash.min"
  cc = require 'b/c/c' #same a listed above
  _.each [1,2,3], (v)-> console.log v

  return b: 'c'
