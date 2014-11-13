_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/UError'#, 100
# see http://stackoverflow.com/questions/1382107/whats-a-good-way-to-extend-error-in-javascript
module.exports =
  class UError extends Error
    constructor: (@message, props)->
      super
      @[p] = v for p, v of props #copy all props to @
      @stack = @stack if l.deb 10