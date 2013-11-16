_B = require 'uberscore'
l = new _B.Logger 'spec/helpers'
chai = require 'chai'
expect = chai.expect

# Mimic & extend http://api.qunitjs.com/category/assert/

#A STRICT comparison assertion, like qunits strictEqual.

equal = (a, b)-> expect(a).to.equal(b)
notEqual = (a, b)-> expect(a).to.not.equal(b)

#A boolean assertion, equivalent to CommonJS’s assert.ok() and JUnit’s assertTrue(). Passes if the first argument is truthy.
ok = (a)-> expect(a).to.be.ok

tru = (a)-> expect(a).to.be.true
fals = (a)-> expect(a).to.be.false

### using _B.isXXX to construct some helpers ###

# helper _B.isEqual & _B.isLike that prints the path where discrepancy was found
are = (name, asEqual=true)->
  (a, b)->
    isEq = _B[name] a, b, {path:(path=[]), allProps:true, exclude:['inspect']}

    if asEqual
      if !isEq
        l.warn "Discrepancy, expected true from _B.#{name} \n at path: ", path.join('.'),
          '\n left Object = ', _B.getp(a, path), '\n right Object =', _B.getp(b, path)
    else
      if isEq
        l.warn "Discrepancy, expected false from _B.#{name},",
          '\n left Object = ', _B.getp(a, path), '\n right Object =', _B.getp(b, path)

    if asEqual
      expect(isEq).to.be.true
    else
      expect(isEq).to.be.false

#A deep recursive comparison assertion, working on primitive types, arrays, objects, regular expressions, dates and functions.
deepEqual = are 'isEqual'
notDeepEqual = are 'isEqual', false

exact = are 'isExact'
notExact = are 'isExact', false

iqual = are 'isIqual'
notIqual= are 'isIqual', false

ixact = are 'isIxact'
notIxact = are 'isIxact', false

like = are 'isLike'
notLike = are 'isLike', false

likeBA = (a,b)-> like(b,a) # reverse a,b
notLikeBA = (a,b)-> notLike(b,a) # reverse a,b

module.exports = {
  equal, notEqual #strictEqual
  tru, fals
  ok              #truthy

  deepEqual, notDeepEqual
  exact, notExact
  iqual, notIqual
  ixact, notIxact

  like, notLike
  likeBA, notLikeBA
}
