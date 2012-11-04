define ['b/b-lib'], (b)->
  console.log '\nstarted a'

  if false                    # not actually required at runtime,
    d = require 'b/c/d/d-lib' # but d-lib should be added to [],
                               # as fileRelative './b/c/d/d-lib' right after a 'require'

  require ['b/c/d/d-lib'], (d)->
    console.log "called SYNCHRONOUSLY, cause 'b/c/d/d-lib' is cached"

  if isNode
    console.log require 'node!../nodeNative-requiredByABC_and_rjs' #todo: make it a node-only require :-)


  console.log '\nreturning a'
  return a: 'a', b: b
