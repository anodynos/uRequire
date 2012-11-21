logger = (baseMsg, color, cons)->
  ->
    args = Array.prototype.slice.call arguments
    args.unshift baseMsg
    args.unshift color
#    args.unshift '\n'
    args.push '\u001b[0m' #reset
    cons.apply null, args
    null

module.exports.log = logger "\n", '\u001b[0m', console.log
module.exports.verbose = logger "\n", '\u001b[32m', console.log
module.exports.debug = logger "\nDEBUG:", '\u001b[36m', console.log
module.exports.warn = logger "\nWARNING:", '\u001b[33m', console.log #yellow
module.exports.err = logger "\nERROR:", '\u001b[31m', console.log #red
