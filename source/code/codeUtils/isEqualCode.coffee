toAST = require './toAST'

module.exports = isEqualCode = (code1, code2) ->
  _B.isEqual toAST(code1, 'Program'), toAST(code2, 'Program'), exclude: ['raw', 'sourceType']
