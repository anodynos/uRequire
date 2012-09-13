logger = (baseMsg, color)->
  ->
    args = Array.prototype.slice.call arguments
    args.unshift baseMsg
    args.unshift color
    args.push '\u001b[0m' #reset
    console.warn.apply null, args
    null

module.exports.log = logger("", '\u001b[0m')
module.exports.warn = logger("WARNING:", '\u001b[33m') #yellow
module.exports.err = logger("ERROR:", '\u001b[31m') #red
