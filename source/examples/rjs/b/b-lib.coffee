console.log 'starting b-lib'
define ['require', 'c/c-lib'], (require)->

  c2 = require '../c/c-lib'
  return b:'b', c: c2

#
#c2 = require '../c/c-lib'
#module.exports = b:'b', c: c2
