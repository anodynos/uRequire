esprima =  require 'esprima'
# @param codeOrAST {String|AST}
# @return an AST that can be generated to code
#     either as type: 'Program' or type: 'BlockStatement'
#todo: split/configure to 'strict mode', no undefined, no AST etc
module.exports = toAST = (codeOrAST, type)->
  # some type checking!
  validTypes = ['Program', 'BlockStatement']
  if type and type not in validTypes
    throw new UError "Invalid `toAST()` type - validTypes are ['#{validTypes.join(', ')}']."

  if _.isString codeOrAST
    try
      codeOrAST = esprima.parse codeOrAST #, raw:false #raw is ignored in >1.1
    catch err
      if l.deb(90) #todo: print fragment only around error
        throw new UError "*esprima.parse* in toAST while parsing javascript fragment: \n #{codeOrAST}.", nested:err
      else
        throw err

  if _.isArray codeOrAST
    # an array of statements/declarations, i.e a body array
    # body array can not genCode, so change to type or default to 'Program'
    type: type or 'Program'
    body: codeOrAST
  else
    if _.isObject codeOrAST # a program or a single node
      if not type
        codeOrAST  # leave node AS is
      else
        # set or change type
        if codeOrAST.type in validTypes
          codeOrAST.type = type # change type
          codeOrAST
        else
          type: type            # enclose in type
          body: [ codeOrAST ]
    else
      codeOrAST                        # AS-IS (eg undefined)