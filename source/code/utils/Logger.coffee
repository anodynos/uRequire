# a `var VERSION = "x.x.x"` is placed here by grant:concat
_ = require 'lodash'

class Logger
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor:->@_constructor.apply @, arguments

  # default Logger::debugLevel
  debugLevel: 0
  VERSION: if not VERSION? then '{VERSION}' else VERSION # 'VERSION' variable is added by grant:concat

  _constructor: (@title)->

  @getALog: (baseMsg, color, cons)->
    ->
      args = Array.prototype.slice.call arguments
      args.unshift "[#{@title or '?title?'}] #{baseMsg}:"
      args.unshift "#{color}\n"
      args.push '\u001b[0m' #reset color
      cons.apply null, args
      null

  err:  Logger.getALog "ERROR", '\u001b[31m', console.error #red
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

  prettify: do (inspect = require('util').inspect)->
    (o)->
      "\u001b[0m#{(inspect o, false, null, true)}".replace /\n/g, ''

module.exports = Logger