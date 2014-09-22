_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/codeUtils/CodeMerger'

UError = require '../utils/UError'

toCode = require   "./toCode"
toAST = require   "./toAST"
isLikeCode = require  "./isLikeCode"
isEqualCode = require "./isEqualCode"

dfb = new _B.DeepDefaultsBlender

class CodeMerger

  @options:
    uniqueDeclarations: true

  constructor: (@options = CodeMerger.options)->
    if options isnt CodeMerger.options
      dfb.blend @options, CodeMerger.options

    @declarations or= []
    @statements or= []

  reset:->
    @declarations = []
    @statements = []

  addbodyNode: (node)->
    if node.type is 'VariableDeclaration'
      for decl in node.declarations
        if not _.any(@declarations, (fd)-> _.isEqual decl, fd)
          if dublicateDecl = _.find(@declarations, (fd)-> isLikeCode {type:decl.type, id:decl.id}, fd)
            if @options.uniqueDeclarations
              throw new UError """
                Duplicate var declaration while merging code:\n
                #{toCode decl}\n
                is a duplicate of\n
                #{toCode dublicateDecl}
              """
            else
              l.debug 90, "Replacing declaration of '#{decl.id.name}'"
              dublicateDecl.init = decl.init
          else
            l.debug 90, "Adding declaration of '#{decl.id.name}'"
            @declarations.push decl
    else
      if not _.any(@statements, (fd)-> _.isEqual node, fd)
        @statements.push node

    null

  ###
    add `code`, which can be:
      * String: a string of parsable Javascript code
      * Array: of body nodes
      * Object: a single node OR a program
  ###
  add: (code)->
    if !_.isEmpty code
      @addbodyNode node for node in toAST(code, 'Program')?.body or []

  Object.defineProperties @::,

    'AST': get: ->
      if _.isEmpty @declarations
        @statements
      else # join all declarations on top of statements
        [{type: 'VariableDeclaration', @declarations, kind: 'var'}].concat @statements

    'code': get: -> toCode @AST

module.exports = CodeMerger