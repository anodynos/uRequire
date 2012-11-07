define [
    'b/b-lib'
    'text!../data/abc.txt'
    'json!../data/abc.json'
    # 'unknown!abc.txt'
  ], (
    b
    abcText
    abcJson
    # unknown
  )->

    console.log '\nstarted a'
    console.log '\nabcText = ', abcText
    console.log '\nabcJson = ', abcJson
#    console.log '\nunknown = ', unknown


    if true                    # not actually required at runtime,
      d = require 'b/c/d/d-lib' # but d-lib should be added to [],
                                 # as fileRelative './b/c/d/d-lib' right after a 'require'

    if isNode
      console.log require 'node!../nodeNative-requiredByABC_and_rjs' #todo: make it a node-only require :-)


    console.log '\nreturning a'
    return a: 'a', b: b
