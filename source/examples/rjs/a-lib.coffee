console.log 'starting a-lib'
define ['require', 'b/b-lib'], (require, b1)->

  b2 = require './b/b-lib'

  if not (typeof define is 'function' and define.amd) #run only when in node
    console.log require '../nodeNative-requiredByABC_and_rjs' # this fails, cause its a node-native module

  return a:'a', b: b1
