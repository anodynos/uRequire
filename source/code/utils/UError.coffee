# see http://stackoverflow.com/questions/1382107/whats-a-good-way-to-extend-error-in-javascript
module.exports =
  class UError extends Error
    constructor: (@message, props)->
      @[p] = v for p, v of props #copy all props to @
      #@stack = (new Error()).stack.replace(/\n[^\n]*/,'') # dev mode only!