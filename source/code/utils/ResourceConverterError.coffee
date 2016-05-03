# see http://stackoverflow.com/questions/1382107/whats-a-good-way-to-extend-error-in-javascript
UError = require './UError'
module.exports =
  class ResourceConverterError extends UError
    constructor: (@message, props) -> super
