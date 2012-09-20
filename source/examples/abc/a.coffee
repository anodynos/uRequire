`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define ["require"], (require, b)->
  console.log 'started a'
  rnd = (Math.random() * 100)
  if rnd > 50
    require ['./b/b'], (b)->
      console.log 'got ./b/b = ', b
  else
    require ['b/c/c'], (c)->
      console.log 'got b/c/c = ', c

  amdstring = require '/libs/amd-utils-test/UMD/string.js'
  console.log amdstring.camelCase 'it-works-or-ill-make-it-work'

  return a: 'a'
