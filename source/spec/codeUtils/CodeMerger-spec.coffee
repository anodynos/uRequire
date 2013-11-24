_ = (_B = require 'uberscore')._
l = new _B.Logger 'urequire/CodeMerger-spec'
chai = require 'chai'
expect = chai.expect

{ equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
  ixact, notIxact, like, notLike, likeBA, notLikeBA } = require '../spec-helpers'

CodeMerger = require '../../code/codeUtils/CodeMerger'
Module = require '../../code/fileResources/Module'
UError = require '../../code/utils/UError'

esprima = require 'esprima'

toAST = require "../../code/codeUtils/toAST"
toCode  = require "../../code/codeUtils/toCode"
isLikeCode = require "../../code/codeUtils/isLikeCode"
isEqualCode = require "../../code/codeUtils/isEqualCode"
replaceCode = require "../../code/codeUtils/replaceCode"

simpleCodes = [
  """
    var a = 'a';
    var _ = require('lodash');
    Backbone.ORM = require('Backbone-orm');
  """, """
    var _ = require('lodash');
  """, """
    var __hasProp = {}.hasOwnProperty;

    var _ = require('lodash');
  """, """
    var _ = require('lodash');

    var __extends = function (child, parent) {
      for (var key in parent) {
          if (__hasProp.call(parent, key))
              child[key] = parent[key];
      }
      function ctor() {
          this.constructor = child;
      }
      ctor.prototype = parent.prototype;
      child.prototype = new ctor();
      child.__super__ = parent.prototype;
      return child;
    };
  """
  ]

expectedCode = """
  var a = 'a',
      _ = require('lodash'),
      __hasProp = {}.hasOwnProperty,
      __extends = function (child, parent) {
        for (var key in parent) {
            if (__hasProp.call(parent, key))
                child[key] = parent[key];
        }
        function ctor() {
            this.constructor = child;
        }
        ctor.prototype = parent.prototype;
        child.prototype = new ctor();
        child.__super__ = parent.prototype;
        return child;
    };
    Backbone.ORM = require('Backbone-orm');
  """

describe 'CodeMerger:', ->
  cm = null
  beforeEach -> cm = new CodeMerger

  describe "correctly merges code & declarations:", ->

    it "from string code", ->
      cm.add code for code in simpleCodes

      tru isEqualCode cm.code, expectedCode # @todo equalCode test should show where discrepancy is

    it "from body of statements/declarations", ->
      cm.add toAST(code).body for code in simpleCodes

      tru isEqualCode cm.code, expectedCode

    it "from single AST nodes", ->
      for code in simpleCodes
        for bodyNode in toAST(code).body
          cm.add bodyNode

      tru isEqualCode cm.code, expectedCode

    it "from ASTProgram", ->
      cm.add toAST code for code in simpleCodes

      tru isEqualCode cm.code, expectedCode

  describe "handles *Duplicate var declaration*:", ->

    it "by default it throws exception if var is declared twice with different value", ->
      cm.add code for code in simpleCodes
      expect( -> cm.add "var _ = require('underscore')").to.throw UError, /Duplicate var declaration*/

    it "with `uniqueDeclarations:false` it allows it, changing the init value", ->
      cm = new CodeMerger uniqueDeclarations: false
      cm.add code for code in simpleCodes

      cm.add "var _ = require('underscore')" # the offending decl is now allowed

      # generate our expected code with changed init value
      replaceCode expectedAST = toAST(expectedCode),
        {arguments: [ { type: 'Literal', value: 'lodash' } ]},
          (ast)-> ast.arguments[0].value = 'underscore'; ast

      tru isEqualCode cm.code, expectedAST