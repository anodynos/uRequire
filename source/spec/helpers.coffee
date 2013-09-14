_B = require 'uberscore'
l = new _B.Logger 'spec/helpers'

# helper _B.isEqual & _B.isLike that prints the path where discrepancy was found
are = (name)->
  (a, b)->
    isEq = _B[name] a, b, {path:(path=[]), allProps:true, exclude:['inspect']}
    if !isEq
      l.warn "Discrepancy _B.#{name} at path", path,
        '\n', _B.getp(a, path), '\n', _B.getp(b, path)
    isEq

areEqual = are('isEqual')
areLike = are('isLike')
areRLike = (a,b)-> areLike(b,a) # reverse a,b

# replace depStrings @ indexes with a String() having 'untrusted:true` property
untrust = (indexes, depsStrings)->
  for idx in indexes
    depsStrings[idx] = new String depsStrings[idx]
    depsStrings[idx].untrusted = true
    depsStrings[idx].inspect = -> @toString() + ' (untrusted in test)'
  depsStrings

module.exports = {areEqual, areLike, areRLike,untrust }