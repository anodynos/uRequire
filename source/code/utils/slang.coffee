module.exports =
  # takes object o & returns a fn, that returns o[key] ? default value (with key '*')
  certain: (o)-> (key)-> o[key] ? o['*']

  ###
  # a helper to create an object literal
  # with a dynamic keys on the fly.
  # js/coffee dont like this right now :-(
  # @param {String...} keyValPairs key,value pairs
  ###
  objkv: (obj, keyValPairs...)->
    for key, idx in keyValPairs by 2
      obj[key] = keyValPairs[idx+1]
    return obj

