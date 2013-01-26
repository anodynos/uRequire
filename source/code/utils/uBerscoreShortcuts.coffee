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
  @todo:(2 5 6) make generic ?
  ###
  arrayToObjectWithValuesAsKeys: (arr)->
    obj = {}
    _B.go arr, grab: (v)-> obj[v + ''] = []
    obj

  ###
    it converts 'imperfect' input like
      'str1' or ['str1', 'str2']
    to
      {str1:[], str2:[]}

    or
      {key: 'stringVal'}
    to
      {key: ['stringVal']}
  @todo:(2 5 6) Crap name again, an not generic enough, I know that too :
  todo :

  ###
  toObjectKeysWithArrayValues: (input)->
    result = _B.arrayize input, _.isString

    if _.isArray result # change ['str1', 'str2'] to {str1:[], str2:[]}
      result = @arrayToObjectWithValuesAsKeys result
    else
      if _.isObject result # change `key: 'string'` to `key: ['string']`
        _B.mutate result, _B.arrayize, _.isString

    result





  ###
  @todo:(2 3 6) Crap name again, an not generic enough, I know that too :
    it converts 'imperfect' input like
      'str1' or ['str1', 'str2']
    to
      {str1:{name:str1} , str2:{name:str2} }

    or
      {key1: {}, key1: {}}
    to
      {key1: {name: 'key1'}, {key2: {name: 'key1'}}

  @todo:(2 3 7) Generalize this and the above!
  ###
  toObjectKeysWithNameAttributeAsKey: (input, name='name')->
    result = _B.arrayize input, _.isString

    # change ['str1', 'str2'] to {str1:{}, str2:{}}
    if _.isArray result
      obj = {}
      _B.go result, grab: (v)-> obj[v + ''] = {}
      result = obj

    if _.isObject result # change `key: {} to `key: {name:key}'
      for key, val of result
        result[key][name] = key

    result

module.exports = new uBerscoreShortcuts

##@todo : specs
#_Bs = module.exports
#
#console.log _Bs.toObjectKeysWithArrayValues 'lalakis'
#console.log _Bs.toObjectKeysWithArrayValues ['str1', 'str2']
#console.log _Bs.toObjectKeysWithArrayValues {key1: 'lalakis', key2: ['ok','yes']}
#
#
#console.log _Bs.toObjectKeysWithNameAttributeAsKey 'UMD'
#console.log _Bs.toObjectKeysWithNameAttributeAsKey ['UMD', 'nodejs']
#console.log _Bs.toObjectKeysWithNameAttributeAsKey(AMD: {}, nodejs: {})
