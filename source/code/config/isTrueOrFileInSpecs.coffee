_ = (_B = require 'uberscore')._

isFileIn = require 'is_file_in'

module.exports = (val, filename)->
  _.isEqual(val, true) or (_.isArray(val) and isFileIn(filename, val))

