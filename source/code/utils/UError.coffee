_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/UError'#, 100
# see http://stackoverflow.com/questions/1382107/whats-a-good-way-to-extend-error-in-javascript
module.exports =
  class UError extends Error
    constructor: (@message, props)->
      super
      @[p] = v for p, v of props #copy all props to @
      @stack = (new Error()).stack.replace(/\n[^\n]*/,'') if l.deb 100 # dev mode only!

#    @todo: finish this - perhaps do toString ?
#    Object.defineProperties @::,
#        message:
#          get: ->
#            (run = (err)=>
#
#              if err is @
#                @_message + if @nested then '\n\n Nested:' + run @nested else ''
#              else
#                if err instanceof UError
#                  err.message
#                else
#                  err.message + if err?.nested then run err.nested else ''
#            ) @
#
#          set: (msg)-> @_message = msg
# todo
# https://github.com/petkaantonov/bluebird/issues/5#issuecomment-25747355
#As for creating custom errors, the correct pattern (derived from "A String is Not an Error" but with some extra tweaks) is something like this:
#
#function ImageAlreadyExistsError(message) {
#Error.call(this);
#Error.captureStackTrace(this, ImageAlreadyExistsError);
#this.message = message;
#}
#ImageAlreadyExistsError.prototype = Object.create(Error.prototype);
#ImageAlreadyExistsError.prototype.constructor = ImageAlreadyExistsError;
#ImageAlreadyExistsError.prototype.name = "ImageAlreadyExistsError";