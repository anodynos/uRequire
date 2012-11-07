###
  This is meant to be run in **nodejs** through RequireJs npm package,
  to highlight some hiccups that occur when running AMD modules in node
  and wish to access node functionality that is not available:
    * access nodejs variables
    * run native nodejs/commonjs modules
###

console.log 'starting a-lib'
define [
    'require'
    'b/b-lib'
#    'text'
    'text!../data/abc.txt'
    'json!../data/abc.json'
  ], (
    require
    b1
#    textPlugin
    abcText
    abcJson
  )->
    console.log "inside module 'a-lib'."

    console.log '\nabcText = ', abcText
    console.log '\nabcJson = ', abcJson

    # require tests
    b2 = require 'b/b-lib'
    b3 = require './b/b-lib'

    if b1 is b2 and b1 is b3
      console.log ' b1 === b2 === b3 ' # winner!
    else
      console.log ' b1 !== b2 === b3 '

    ###
      using '.js' extension fails
    ###
    try
      b4 = require './b/b-lib.js'
    catch err # "Error: Calling node's require("b/b-lib.js") failed with error: Error: Cannot find module 'b/b-lib.js'"
      console.error err


    ###
    nodejs variables (eg exports __dirname etc) are not available!
    although we run inside nodejs, through requirejs.

    So you can't check
      'if (typeof exports is 'object')
    to run only when in node.
    ###
    console.log '  typeof module == ',  (typeof module)


    ###
    Further more, (typeof define === 'function' && define.amd) returns true,
    so we still have no information whether you are on nodejs or the browser.
    ###
    console.log "  (typeof define === 'function' && define.amd) == ",  if (typeof define is 'function' and define.amd) then true else false


    ###
    One way to know we're in nodejs is
    ###
    if typeof window is 'undefined'
      console.log "   Yes, we're in nodejs!"

      ###
      node-native modules are NOT working, even though we're in nodejs :-(
      ###
      try
        console.log require '../nodeNative-requiredByABC_and_rjs'
      catch err #'Error: Evaluating path/to/moduleName.js as module "moduleName" failed with error: ReferenceError: module is not defined'
        console.error err


    return a:'a', b: b1
