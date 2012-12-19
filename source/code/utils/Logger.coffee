_ = require 'lodash'

class Logger
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor:->@_constructor.apply @, arguments

  _constructor: (@title, @debugLevel = Logger.debugLevel)->

  # default Logger.debugLevel
  @debugLevel = 100

  @getALog: (baseMsg, color, cons)->
    ->
      args = Array.prototype.slice.call arguments
      args.unshift "#{color}[#{@title or '?title?'}] #{baseMsg}:"
      args.push '\u001b[0m' #reset color
      cons.apply null, args
      null

  err:  Logger.getALog "ERROR", '\u001b[31m', console.log #red
  log: Logger.getALog "", '\u001b[0m', console.log
  verbose: Logger.getALog "", '\u001b[32m', console.log
  warn: Logger.getALog "WARNING", '\u001b[33m', console.log #yellow

  debug: do ->
    log = Logger.getALog "DEBUG:", '\u001b[36m', console.log
    return (level, msgs...)->
      if _.isString level
        msgs.unshift level
        msgs.unshift '(-)'
        level = 1 # debug unless debugLevel is 0
      else
        msgs.unshift "(#{level})"

      if level <= @debugLevel
        log.apply @, msgs

module.exports = Logger
