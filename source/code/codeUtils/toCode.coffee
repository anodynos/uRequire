_ = require 'lodash'
_B = require 'uberscore'
l = new _B.Logger 'urequire/codeUtils/toCode'#  100

escodegen =  require 'escodegen'

dfb = new _B.DeepDefaultsBlender

UError = require '../utils/UError'
toAST = require './toAST'

# returns the AST of the 1st statement/expression if its a String, as-is otherwise
# @todo: return whole body / all statements

module.exports = toCode = (astCode, options=toCode.options)->
  return '' if _.isEmpty astCode

  if options isnt toCode.options
    dfb.blend options, toCode.options

  astCode = toAST astCode, options.type

  try
    escodegen.generate astCode, options
  catch err
    l.er err
    throw new UError "Error generating code from AST in Module's toCode - AST = \n", astCode: astCode

toCode.options =
  format: # escodegen default options
    indent:
      style: '  '
      base: 0
    json: false
    renumber: false
    hexadecimal: false
    quotes: 'double'
    escapeless: true
    compact: false
    parentheses: true
    semicolons: true
