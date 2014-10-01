When = require "./whenFull"

fs = require 'fs'

When.node.liftAll fs, (
  (pfs,  liftedFunc, name)->
    pfs["#{name}P"] =
      if name isnt 'exists'
        liftedFunc
      else
        When.node.lift require 'fs-exists'
    pfs
), fs


module.exports = fs