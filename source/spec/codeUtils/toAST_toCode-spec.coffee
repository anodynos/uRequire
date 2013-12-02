_ = (_B = require 'uberscore')._
l = new _B.Logger 'codeUtils/toAST_toCode-spec'

chai = require 'chai'
expect = chai.expect
{ equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
  ixact, notIxact, like, notLike, likeBA, notLikeBA, equalSet, notEqualSet } = require '../specHelpers'

coffee = require 'coffee-script'
esprima = require 'esprima'

Module = require "../../code/fileResources/Module"
UError = require "../../code/utils/UError"

isLikeCode = require "../../code/codeUtils/isLikeCode"
isEqualCode = require "../../code/codeUtils/isEqualCode"

toAST = require "../../code/codeUtils/toAST"
toCode = require "../../code/codeUtils/toCode"

code = """
    var x = 1;
    if (param) {
      var var1 = require('dep1');
      x = function(y){ return x * 2 }
    } else {
      x = null;
    }
"""

ast = (esprima.parse code)

describe "`toCode` & `toAST`:", ->

  describe "`toCode`:", ->

    describe "produces javascript 'program' code: ", ->

      it "from String", ->
        tru isEqualCode toCode(code), code

      it "from AST", ->
        tru isEqualCode toCode(ast), code

      it "from AST body array", ->
        tru isEqualCode toCode(ast.body), code

      it "from AST node", ->
        tru isEqualCode toCode(ast.body[0]), 'var x = 1;'

    describe "produces javascript BlockStatement: ", ->

      it "from String", ->
        tru isEqualCode toCode(code, type: 'BlockStatement'), "{" + code + "}"

      it "from AST body array", ->
        tru isEqualCode toCode(ast.body, type: 'BlockStatement'), "{" + code + "}"

      it "from AST node", ->
        tru isEqualCode toCode(ast.body[0], type: 'BlockStatement'), "{ var x = 1; }"

    describe.skip "produces javascript formated code: ", ->

  describe "`toAST`:", ->

    describe "produces AST 'Program' object: ", ->

      it "from String", ->
        tru isEqualCode toAST(code), ast

      it "from AST", ->
        tru isEqualCode toAST(ast), ast

      it "from AST body array", ->
        tru isEqualCode toAST(ast.body), ast

      it "from AST node", ->
        tru isEqualCode toAST(ast.body[0]), 'var x = 1;'

    describe "produces AST 'BlockStatement' object: ", ->

      it "from String", ->
        # @todo: solve `toCode '{' + code + '}'` =
        #        { type: 'Program',
        #          body:
        #          [ { type: 'BlockStatement',
        #              body:...

        tru isEqualCode toCode(toAST(code, 'BlockStatement')), '{' + code + '}'

      it "from AST", ->
        tru isEqualCode toCode(toAST(ast, 'BlockStatement')), '{' + code + '}'

      it "from AST body array", ->
        tru isEqualCode toCode(toAST(ast.body, 'BlockStatement')), '{' + code + '}'

      it "from AST node", ->
        tru isEqualCode toCode(toAST(ast.body[0], 'BlockStatement')), '{var x = 1;}'


