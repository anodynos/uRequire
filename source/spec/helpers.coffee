_B = require 'uberscore'
l = new _B.Logger 'spec/helpers'
chai = require 'chai'
expect = chai.expect

# helper _B.isEqual & _B.isLike that prints the path where discrepancy was found
are = (name)->
  (a, b)->
    isEq = _B[name] a, b, {path:(path=[]), allProps:true, exclude:['inspect']}
    if !isEq
      l.warn "Discrepancy _B.#{name} at path", path,
        '\n', _B.getp(a, path), '\n', _B.getp(b, path)
    expect(isEq).to.be.true

deepEqual = are('isEqual')

likeAB = are('isLike')
likeBA = (a,b)-> likeAB(b,a) # reverse a,b

# qunit adapters
ok = (a)-> expect(a).to.be.true
equal = (a, b)-> expect(a, b).to.be.equal
notEqual = (a, b)-> expect(a, b).to.not.be.equal

module.exports = {deepEqual, likeAB, likeBA, ok, equal, notEqual, notEqual}