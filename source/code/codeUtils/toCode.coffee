_ = (_B = require 'uberscore')._
l = new _B.Logger 'urequire/codeUtils/toCode'#  100

escodegen =  require 'escodegen'

dfb = new _B.DeepDefaultsBlender

UError = require '../utils/UError'
toAST = require './toAST'

# returns the AST of the 1st statement/expression if its a String, as-is otherwise
# @todo: return whole body / all statements
#todo: split/configure to 'strict mode', no undefined, no string etc
module.exports = toCode = (astCode, options=toCode.options)->
  return '' if _.isEmpty astCode

  if options isnt toCode.options
    dfb.blend options, toCode.options

  ast = toAST astCode, options.type

  try
    escodegen.generate ast, options
  catch err
    throw new UError "toCode: Error generating code from AST with escodegen: #{err}.", nested: err

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
