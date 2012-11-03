define ['b/b-lib'], (b)->
  console.log 'started a'

  if false                    # not actually required at runtime,
    d = require 'b/c/d/d-lib' # but d-lib should be added to [],
                              # as fileRelative './b/c/d/d-lib' right after a 'require'

  if isNode
    console.log require 'node!../nodeNative-requiredByABC_and_rjs' #todo: make it a node-only require :-)

  return a: 'a', b: b
