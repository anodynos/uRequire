_ = require 'lodash'



class Logger
  debugLevel = 1000

  logger = (baseMsg, color, cons)->
    ->
      args = Array.prototype.slice.call arguments
      args.unshift baseMsg
      args.unshift color
  #    args.unshift '\n'
      args.push '\u001b[0m' #reset
      cons.apply null, args
      null

  log: logger "\n", '\u001b[0m', console.log

  verbose: logger "\n", '\u001b[32m', console.log

  warn: logger "\nWARNING:", '\u001b[33m', console.log #yellow

  err:  logger "\nERROR:", '\u001b[31m', console.log #red

  debug: do ()->
    log = logger "\nDEBUG:", '\u001b[36m', console.log
    return (level, msgs...)->
      msgs.unshift level
      level = 100 if _.isString level
      if level <= debugLevel
        log.apply null, msgs

module.exports = new Logger