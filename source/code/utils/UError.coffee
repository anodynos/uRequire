# see http://stackoverflow.com/questions/1382107/whats-a-good-way-to-extend-error-in-javascript
module.exports =
  class UError extends Error
    constructor: (@message, props)->
      super
      @[p] = v for p, v of props #copy all props to @
#      @stack = (new Error()).stack.replace(/\n[^\n]*/,'') # dev mode only!


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