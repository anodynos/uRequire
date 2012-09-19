`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

define (require)->
  console.log 'started c'
  return c:'c'