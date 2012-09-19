`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define [], (require)->
  console.log 'started a'
  rnd = (Math.random() * 100)
  console.log rnd
  if rnd > 10
    b = require 'b/b'
  else
    c = require 'b/c/c'

  if rnd > 50
    require ['b/b'], (b)-> #if 'require' is present in deps, requirejs halts here
      console.log 'got ./b/b = ', b
  else
    require ['b/c/c'], (c)->
      console.log 'got b/c/c = ', c

  c = require 'b/c/c'

  return a: 'a'
