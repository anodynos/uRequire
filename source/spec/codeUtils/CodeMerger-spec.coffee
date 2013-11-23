_ = (_B = require 'uberscore')._
l = new _B.Logger 'urequire/CodeMerger-spec'
chai = require 'chai'
expect = chai.expect

{ equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
  ixact, notIxact, like, notLike, likeBA, notLikeBA } = require '../spec-helpers'

CodeMerger = require '../../code/codeUtils/CodeMerger'
Module = require '../../code/fileResources/Module'

esprima = require 'esprima'

toAST = require "../../code/codeUtils/toAST"
isLikeCode = require "../../code/codeUtils/isLikeCode"
isEqualCode = require "../../code/codeUtils/isEqualCode"

simpleCodes = [
  """
    var a = 'a';
    Backbone.ORM = require('Backbone-orm');
  """, """
    var _ = require('lodash');
  """, """
    var __hasProp = {}.hasOwnProperty;
  """, """
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

  describe "merges code:", ->
    cm = new CodeMerger

    it "from string code", ->
      cm.add code for code in simpleCodes

      tru isEqualCode cm.toCode(), expectedCode # @todo equalCode test should show where discrepancy is

    it "from body of statements/declarations", ->
      cm.add toAST(code).body for code in simpleCodes

      tru isEqualCode cm.toCode(), expectedCode # @todo equalCode test should show where discrepancy is

    it "from single AST nodes", ->
      for code in simpleCodes
        for bodyNode in toAST(code).body
          cm.add bodyNode

      tru isEqualCode cm.toCode(), expectedCode # @todo equalCode test should show where discrepancy is

    it "from ASTProgram", ->
      cm.add toAST code for code in simpleCodes

      tru isEqualCode cm.toCode(), expectedCode # @todo equalCode test should show where discrepancy is






