console.log 'starting a-lib'
define ['require', 'b/b-lib'], (require, b1)->

  b2 = require './b/b-lib'

  console.log require '../nodeNative-toBeRequired' # this fails, cause its a node-native module

  return a:'a', b: b1
