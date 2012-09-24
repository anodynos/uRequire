module.exports =
  # takes object o & returns a fn, that returns o[key] ? default value (with key '*')
  certain: (o)-> (key)-> o[key] ? o['*']

  # a helper to create an object literal
  # with a dynamic keys on the fly.
  # js/coffee dont like this right now :-(
  # @param {String...} key,value pairs
  objkv: (ob, keyValuePairs...)->
    for key, idx in keyValuePairs by 2
      ob[key] = keyValuePairs[idx+1]
    return ob

