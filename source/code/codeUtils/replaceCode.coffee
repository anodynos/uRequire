_ = (_B = require 'uberscore')._
l = new _B.Logger 'urequire/codeUtils/replaceCode'

toCode = require   "./toCode"
toAST = require   "./toAST"
isLikeCode = require  "./isLikeCode"
isEqualCode = require "./isEqualCode"

replaceCode = (AST, matchCode, replCode)->

    matchCode = toAST(matchCode, 'Program')?.body?[0]
    replCode = toAST(replCode, 'Program')?.body?[0]
    
    deletions = []

    replCodeAction = (prop, src)->
      if _B.isLike matchCode, src[prop]
        _replCode =
          if _.isFunction replCode
            toAST(replCode(src[prop]), 'Program')?.body?[0]
          else
            replCode

        if _replCode # not undefined
          l.debug("""
            Replacing code:
            ```````````````````
            #{toCode src[prop]}
            ```` with code: ```
            #{toCode _replCode}
            ```````````````````""") if l.deb 50
          src[prop] = _replCode

        else # remove toCode src[prop] code
          if _.isArray src
            l.debug("Deleting code:\n  `#{toCode src[prop]}`") if l.deb 50
            deletions.push {src, prop}
          else
            l.debug("Delete code (replacing with EmptyStatement):\n`#{toCode src[prop]}`") if l.deb 50
            src[prop] = {type: 'EmptyStatement'}
          return false # 'stop traversing deepr'

    _B.traverse AST, replCodeAction

    # deletions in reverse order to preserve array order
    for deletion in deletions by -1
      deletion.src.splice(deletion.prop, 1)

    @

module.exports = replaceCode