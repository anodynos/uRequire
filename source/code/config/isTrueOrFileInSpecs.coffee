_ = (_B = require 'uberscore')._

isFileInSpecs = require './isFileInSpecs'

module.exports = (val, filename)->
  _.isEqual(val, true) or (_.isArray(val) and isFileInSpecs(filename, val))

