umatch = require 'umatch'

module.exports = (val, filename)->
  _.isEqual(val, true) or (_.isArray(val) and umatch(filename, val))

