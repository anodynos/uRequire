esprima = require 'esprima'

CodeMerger = require '../../code/codeUtils/CodeMerger'

toAST = require "../../code/codeUtils/toAST"
toCode = require "../../code/codeUtils/toCode"
isLikeCode = require "../../code/codeUtils/isLikeCode"
isEqualCode = require "../../code/codeUtils/isEqualCode"
replaceCode = require "../../code/codeUtils/replaceCode"

describe 'replaceCode:', ->
  jsCode = """
    var b = 0;

    if (l.deb(10)) {
      b = 1;
      if (l.deb(20) && true) {
        b = 2;
        if (l.deb(30)) {
          b = 3;
        }
      }
    }

    if (l.deb(40)) {
      b = 4;
    }

    c = 3;
  """

  astCode = null
  beforeEach -> astCode = toAST jsCode

  describe "replaces matched code, with param replCode as:", ->


    for replType in ['AST', 'String'] then do (replType)->

      replCode = "if (l.deb(300)) { changed = 50; }"
      replCode = toAST replCode if replType is 'AST'

      it "a #{replType}", ->

        replaceCode astCode, 'if (l.deb(30)){}', replCode

        tru isEqualCode astCode, """
          var b = 0;

          if (l.deb(10)) {
            b = 1;
            if (l.deb(20) && true) {
              b = 2;
              if (l.deb(300)) { // here's what changed
                changed = 50;
              }
            }
          }

          if (l.deb(40)) {
            b = 4;
          }

          c = 3;
        """

      it "function callback that returns #{replType}", ->

        replaceCode astCode, 'if (l.deb()){}', (matchedAST)->
          matchedAST.test.arguments[0].value++; # change the AST
          if replType is 'AST'
            matchedAST        # return changed AST
          else
            toCode matchedAST # return changed AST as String code

        tru isEqualCode astCode, """
          var b = 0;

          if (l.deb(11)) {
            b = 1;
            if (l.deb(20) && true) { // not changing cause `if (l.deb()){}` doesn't match it
              b = 2;
              if (l.deb(31)) {
                b = 3;
              }
            }
          }

          if (l.deb(41)) {
            b = 4;
          }

          c = 3;
          """

  describe "deletes matched code:", ->
    cnt = 0

    it "with param replCode == null", ->
      replaceCode astCode, 'if (l.deb()){}', -> cnt++; null
      isEqualCode astCode, "var b=0; c=3;"

    it "is traversing only outers", ->
      equal cnt, 2
