#`if (typeof define !== 'function') { var define = require('amdefine')(module) }`

module.exports = (js)->
  log = console.log
  _ = require 'underscore'
  parser = require("uglify-js").parser
  proc = require("uglify-js").uglify

  toCode = (astCode) ->
    code = proc.gen_code(astCode, { beautify: true })

  # helper, keeping main uglify's notation
  readAst=
    "call": (ast)->
      expr = ast[1]
      name = dot = ''
      dotExpr = expr
      while dotExpr[0] is 'dot' #extract dotted references (eg my.object.method)
        name = "#{dotExpr[2]}#{dot}#{name}"
        dotExpr = dotExpr[1]
        dot = '.'

      name = dotExpr[1] + dot + name

      return {
        callName:name
        expr:expr
        args:ast[2]
      }

  #  "function": (ast)->
  #    name:ast[0]
  #    args:ast[1]
  #    body:ast[2]
  #
  #
  #  "defun": (ast)->
  #    name:ast[0]
  #    args:ast[1]
  #    body:ast[2]

  m = {}
  stop = false
  stack = [];
  walkTree = (oa, ident)-> # ident is only used for debugging
    if not stop
      ident = if ident then ident + "    " else " "
      _.each oa, (val, key)->
        if _.isObject(val) or _.isArray(val)
          stack.push val
          walkTree(val, ident)
          stack.pop()
        else
          stacktop = stack[stack.length-1]
          if val is 'call'
  #          log '*************** \n'
  #          log stacktop, '\n'
            call = readAst['call'](stacktop)
            if call.callName in ['define', 'require']
              # check for 'standard' AMD signature
              if call.args.length is 2 and call.args[0][0] is 'array' and call.args[1][0] is 'function'
                m[call.callName] = true
                m.deps= eval toCode call.args[0] # array of deps ['dep1', 'dep2']
                m.args = call.args[1][2] # args of function - 2nd arg of define - (dep1, dep2)
                m.body = ''
                for bodyStatement in call.args[1][3] # all statements of function body
                  m.body += toCode(bodyStatement) + "\n"
                stop = true

  walkTree parser.parse(js) # recursive walker - stores in m

  return m

#log "\n## module info ##"
#log m
#log "################### \n"

