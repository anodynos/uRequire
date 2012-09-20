logger = (baseMsg, color, cons)->
  ->
    args = Array.prototype.slice.call arguments
    args.unshift baseMsg
    args.unshift color
#    args.unshift '\n'
    args.push '\u001b[0m' #reset
    cons.apply null, args
    null

module.exports.log = logger("", '\u001b[0m', console.log)
module.exports.verbose = logger("", '\u001b[3m', console.log)
module.exports.warn = logger("WARNING:", '\u001b[33m', console.log) #yellow
module.exports.err = logger("ERROR:", '\u001b[31m', console.log) #red
