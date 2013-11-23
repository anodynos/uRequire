_ = require 'lodash'
_B = require 'uberscore'

chai = require "chai"
expect = chai.expect

Module = require "../../code/fileResources/Module"
UError = require "../../code/utils/UError"

l = new _B.Logger 'spec/codeUtils/isEqualCode_isLikeCode-spec'

{ equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
  ixact, notIxact, like, notLike, likeBA, notLikeBA } = require '../spec-helpers'

coffee = require 'coffee-script'
esprima = require 'esprima'

isLikeCode = require "../../code/codeUtils/isLikeCode"
isEqualCode = require "../../code/codeUtils/isEqualCode"

describe "`isEqualCode` & `isLikeCode` compare code structure:", ->

  it "`isLikeCode` handles undefined", ->
    tru isLikeCode undefined, undefined
    fals isLikeCode "a = {}", undefined
    fals isLikeCode undefined, "a = {}"

  it "`isEqualCode` handles undefined", ->
    tru isEqualCode undefined, undefined
    fals isEqualCode "a = {}", undefined
    fals isEqualCode undefined, "a = {}"

  codes = _B.okv {},
    '(function(){}).call()',  '(function(someParam, anotherParam){var someVar = 1;}).call(this, that)',
    '(function(){})()',       '(function(param){}())',
    'require()',              "require('someDep')",
    'if (l.deb()){}',         "if(l.deb(90)){debug('Hello')}",
    'if (l.deb()){} else {}', "if(l.deb(90)){debug('Hello')} else {debug('goodbuy')}",
    "a = {}",                 "a = {a:1}",

    # @todo: it "works with multiple statements", ->
    "var a = {}; b = []",     "var a = {a: 1}; b = [a, {a1: 1}];"

  count = 0
  for code1, code2 of codes
    do (code1, code2, count=count++)->

      code1AST = esprima.parse code1
      code2AST = esprima.parse code2
      
      describe "_.isLike compares:", ->

        describe "two strings of javascript code ##{count}:", ->

          it "is true if 1st is a 'subset' of 2nd ##{count}", ->
            tru isLikeCode code1, code2

          it "is is false otherwise ##{count}", ->
            fals isLikeCode code2, code1

        describe 'with string of code OR AST:', ->

          describe "AST program: ##{count}", ->

            it "is true if 1st is a 'subset' of 2nd ##{count}", ->
              tru isLikeCode code1, code2AST
              tru isLikeCode code1AST, code2
              tru isLikeCode code1AST, code2AST

            it "is is false otherwise ##{count}", ->
              fals isLikeCode code2, code1AST
              fals isLikeCode code2AST, code1
              fals isLikeCode code2AST, code1AST

          describe "AST body :##{count}", ->

            it "is true if 1st is a 'subset' of 2nd ##{count}", ->
              tru isLikeCode code1, code2AST.body
              tru isLikeCode code1AST.body, code2
              tru isLikeCode code1AST, code2AST.body
              tru isLikeCode code1AST.body, code2AST
              tru isLikeCode code1AST.body, code2AST.body

            it "is is false otherwise ##{count}", ->
              fals isLikeCode code2, code1AST.body
              fals isLikeCode code2AST.body, code1
              fals isLikeCode code2AST, code1AST.body
              fals isLikeCode code2AST.body, code1AST
              fals isLikeCode code2AST.body, code1AST.body

        describe 'with string of code OR AST:', ->

          describe "AST program: ##{count}", ->

            it "is true if 1st is a 'subset' of 2nd ##{count}", ->
              tru isLikeCode code1, code2AST
              tru isLikeCode code1AST, code2
              tru isLikeCode code1AST, code2AST

            it "is is false otherwise ##{count}", ->
              fals isLikeCode code2, code1AST
              fals isLikeCode code2AST, code1
              fals isLikeCode code2AST, code1AST

          describe "AST body :##{count}", ->

            it "is true if 1st is a 'subset' of 2nd ##{count}", ->
              tru isLikeCode code1, code2AST.body
              tru isLikeCode code1AST.body, code2
              tru isLikeCode code1AST, code2AST.body
              tru isLikeCode code1AST.body, code2AST
              tru isLikeCode code1AST.body, code2AST.body

            it "is is false otherwise ##{count}", ->
              fals isLikeCode code2, code1AST.body
              fals isLikeCode code2AST.body, code1
              fals isLikeCode code2AST, code1AST.body
              fals isLikeCode code2AST.body, code1AST
              fals isLikeCode code2AST.body, code1AST.body              
              
      describe "_.isEqual compares:", ->
        
        describe "two strings of javascript code ##{count}:", ->

          it "is true for same code ##{count}", ->
            tru isEqualCode code1, code1
            tru isEqualCode code2, code2
          
          it "is false in any order ##{count}", ->
            fals isEqualCode code1, code2
            fals isEqualCode code2, code1        
        
        describe 'with string of code OR AST:', ->

          describe "AST program: ##{count}", ->

            it "is true for same code ##{count}", ->
              tru isEqualCode code1, code1AST
              tru isEqualCode code1AST, code1
              tru isEqualCode code1AST, code1AST

              tru isEqualCode code2, code2AST
              tru isEqualCode code2AST, code2
              tru isEqualCode code2AST, code2AST

            it "is is false otherwise ##{count}", ->
              fals isEqualCode code1, code2AST
              fals isEqualCode code1AST, code2
              fals isEqualCode code1AST, code2AST

              fals isEqualCode code2, code1AST
              fals isEqualCode code2AST, code1
              fals isEqualCode code2AST, code1AST

          describe "AST body :##{count}", ->

            it "is true for same code1 ##{count}", ->
              tru isEqualCode code1, code1AST.body
              tru isEqualCode code1AST.body, code1
              tru isEqualCode code1AST, code1AST.body
              tru isEqualCode code1AST.body, code1AST
              tru isEqualCode code1AST.body, code1AST.body

            it "is true for same code2 ##{count}", ->
              tru isEqualCode code2, code2AST.body
              tru isEqualCode code2AST.body, code2
              tru isEqualCode code2AST, code2AST.body
              tru isEqualCode code2AST.body, code2AST
              tru isEqualCode code2AST.body, code2AST.body

            it "is false otherwise (code1 1st) ##{count}", ->
              fals isEqualCode code1, code2AST.body
              fals isEqualCode code1AST.body, code2
              fals isEqualCode code1AST, code2AST.body
              fals isEqualCode code1AST.body, code2AST
              fals isEqualCode code1AST.body, code2AST.body

            it "is false otherwise (code2 1st) ##{count}", ->
              fals isEqualCode code2, code1AST.body
              fals isEqualCode code2AST.body, code1
              fals isEqualCode code2AST, code1AST.body
              fals isEqualCode code2AST.body, code1AST
              fals isEqualCode code2AST.body, code1AST.body