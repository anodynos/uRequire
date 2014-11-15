toAST = require './toAST'

module.exports = isLikeCode = (code1, code2)->
  _B.isLike toAST(code1, 'Program')?.body,
            toAST(code2, 'Program')?.body