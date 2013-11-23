_ = require 'lodash'
_B = require 'uberscore'
l = new _B.Logger 'urequire/codeUtils/CodeMerger'

toCode = require   "./toCode"
toAST = require   "./toAST"
isLikeCode = require  "./isLikeCode"
isEqualCode = require "./isEqualCode"

module.exports = class CodeMerger

  constructor: (data)->
    _.extend @, data
    @declarations or= []
    @statements or= []

  addbodyNode: (node)->
    if node.type is 'VariableDeclaration'
      for decl in node.declarations
        if not _.any(@declarations, (fd)-> _.isEqual decl, fd)
          if dublicateDecl = _.find(@declarations, (fd)-> isLikeCode {type:decl.type, id:decl.id}, fd)
            throw new Error """
              Duplicate var declaration while merging code:\n
              #{toCode decl}\n
              is a duplicate of\n
              #{toCode dublicateDecl}
            """
          else
            l.debug 90, "Adding declaration of '#{decl.id.name}'"
            @declarations.push decl
    else
      if not _.any(@statements, (fd)-> _.isEqual node, fd)
        @statements.push node

  ###
    add `code`, which can be:
      * String: a string of parsable Javascript code
      * Array: of body nodes
      * Object: a single node OR a program
  ###
  add: (code)->
    @addbodyNode node for node in toAST(code, 'Program').body

  toCode:->
    if not _.isEmpty @declarations
      if @statements[0]?.type isnt 'VariableDeclaration'
        @statements.unshift {}

      _.extend @statements[0], {
        type: 'VariableDeclaration'
        @declarations
        kind: 'var'
      }

    toCode @statements
#
#cm = new CodeMerger
#cm.add """
#    var l = 'l';
#    l = 1;
#  """
#
#cm.add """
#    var m = 'm';
#    l = 2;
#  """
#
#l.log ' \n', cm.toCode()
#l.log ' \n', cm.toCode()