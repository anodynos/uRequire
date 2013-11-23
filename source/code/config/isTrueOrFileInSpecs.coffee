isFileInSpecs = require './isFileInSpecs'
_ = require 'lodash'

module.exports = (val, filename)->
  _.isEqual(val, true) or (_.isArray(val) and isFileInSpecs(filename, val))

