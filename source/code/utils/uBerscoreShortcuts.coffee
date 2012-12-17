_ = require 'lodash'
_B = require 'uberscore'

# some uBerscore shortcuts / higher level abstractios
# some day they might graduate and become generic

class uBerscoreShortcuts # class cause its easy :-)
  ###

  Convert from Source
     Array<String>
   to
     Object with Source Values as Keys & a new Array as Value
   []<String> -> '{
                   key: (k,v)-> v
                   val: (k,v)-> []
                 }'
  @param arr []<String> or []<Stringable>
  @return {
    string1: []
    string2: []
  }
  @todo:2 make generic ?
  ###
  arrayToObjectWithValuesAsKeys: (arr)->
    obj = {}
    _B.go arr, grab: (v)-> obj[v.toString()] = []
    obj

  ###
  Crap name, I know, but :
    it converts 'imperfect' input like
      'str1' or ['str1', 'str2']
    to
      {str1:[], str2:[]}

    or
      {key: 'stringVal'}
    to
      {key: ['stringVal']}
  ###
  toObjectKeysWithArrayValues: (input)->
    input = _B.arrayize input, _.isString

    if _.isArray input # change ['str1', 'str2'] to {str1:[], str2:[]}
      input = @arrayToObjectWithValuesAsKeys input
    else
      if _.isObject input # change `key: 'string'` to `key: ['string']`
        _B.mutate input, _B.arrayize, _.isString

    input

module.exports = new uBerscoreShortcuts

#@todo : specs
#_Bs = module.exports
#
#console.log _Bs.toObjectKeysWithArrayValues 'lalakis'
#console.log _Bs.toObjectKeysWithArrayValues ['str1', 'str2']
#console.log JSON.stringify (_Bs.toObjectKeysWithArrayValues {key1: 'lalakis', key2: ['ok','yes']}), null, ' '
