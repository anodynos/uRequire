_ = require 'lodash'
l = require('./utils/logger')

extractModuleInfo = (js, options)->
  options = options || {}
  if options.beautifyFactory is undefined
    options.beautifyFactory = false

  if options.extractRequires is undefined
    options.extractRequires = true

  parser = require("uglify-js").parser
  proc = require("uglify-js").uglify

  toCode = (astCode) ->
    code = proc.gen_code(astCode, { beautify: options.beautifyFactory })

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
  #
  #  "defun": (ast)->
  #    name:ast[0]
  #    args:ast[1]
  #    body:ast[2]

  moduleInfo = {}
  hasFoundAMD = false
  amdFactoryFunction = '' #store it outside, we will extract deps from it `require('dep')` if options.extractRequires
  stack = []; # keep each AST element we visit
  extractModuleHeader = (oa, level)-> # level used for debugging & stop crawiling the tree, since we only need top-level info
    level = if not level then 1 else level + 1
    if not hasFoundAMD and level <= 4
      _.each oa, (val, key)->
        if _.isObject(val) or _.isArray(val)
          stack.push val
          extractModuleHeader(val, level)
          stack.pop()
        else
          stacktop = stack[stack.length-1]
          #l.log '*************** \n', level, stacktop, '\n'
          #top-level 'uRequire' : '...' info
          if val is 'object' and
            stacktop[1][0]?[0] is 'uRequire' and
            level is 4 # for safety!
              moduleAst = stacktop[1][0][1]
              moduleInfo = _.extend moduleInfo, eval("(#{toCode(moduleAst)})")

          # extract call to 'define' or 'require'
          if val is 'call'
            call = readAst['call'](stacktop)
            if call.callName in ['define'] # 'require' todo: test 'require'
              # check for 'standard' *anomynous* AMD signature
              if  call.args.length is 2 and
                  call.args[0][0] is 'array' and # array of dependeencies
                  call.args[1][0] is 'function' # factoryFunction
                    moduleInfo.dependencies = eval toCode call.args[0] # array of deps ['dep1', 'dep2']
                    amdFactoryFunction = call.args[1]
                    hasFoundAMD = true
              else # check for *named* AMD signature (not recommended: http://requirejs.org/docs/api.html#modulename)
                if  call.args.length is 3 and
                    call.args[0][0] is 'string' and # module name
                    call.args[1][0] is 'array' and # array of dependeencies
                    call.args[2][0] is 'function' # factoryFunction
                      moduleInfo.moduleName = call.args[0][1]
                      moduleInfo.dependencies = eval toCode call.args[1] # array of deps ['dep1', 'dep2']
                      amdFactoryFunction = call.args[2]
                      hasFoundAMD = true
                else # check for factory-function only AMD signature
                  if  call.args.length is 1 and
                      call.args[0][0] is 'function' # factoryFunction
                        moduleInfo.dependencies = []
                        amdFactoryFunction = call.args[0]
                        hasFoundAMD = true

              if hasFoundAMD
                moduleInfo.type = call.callName # 'define' or 'require'
                moduleInfo.parameters = amdFactoryFunction[2] || [] # args of function (dep1, dep2)

                # factoryBody without the {...}
                fb = toCode(['block', amdFactoryFunction[3] ])
                moduleInfo.factoryBody = fb[1..fb.length-2]


  extractFactoryRequires = (oa, level)-> # level used for debugging & stop crawiling the tree, since we only need top-level info
    level = if not level then 1 else level + 1
    _.each oa, (val, key)->
      if _.isObject(val) or _.isArray(val)
        stack.push val
        extractFactoryRequires(val, level)
        stack.pop()
      else
        stacktop = stack[stack.length-1]
        #l.log '*************** \n', level, stacktop, '\n'
        # extract call to 'require'
        if val is 'call'
          call = readAst['call'](stacktop)
          if call.callName in ['require'] # 'require' todo: test 'require'
            # check for 'standard' *anomynous* AMD signature
            if call.args.length is 1 # require('dep')
              if call.args[0][0] is 'string' #accept only require('dep'), not require('dep' + someVar)
                moduleInfo.requireDependencies.push call.args[0][1]
              else
                #l.err "extractModuleInfo @ extractFactoryRequires : #{toCode stacktop} is a require() without a string as param - IGNORED!"
                if moduleInfo.wrongDependencies is undefined
                  moduleInfo.wrongDependencies = []
                moduleInfo.wrongDependencies.push toCode stacktop


  extractModuleHeader parser.parse js  # recursive walker - stores in moduleInfo

  if options.extractRequires and not _.isEmpty(moduleInfo)
    moduleInfo.requireDependencies = []
    extractFactoryRequires amdFactoryFunction
    # keep only unique requireDeps & only those not in original dependencies
    moduleInfo.requireDependencies = _.difference (_.uniq moduleInfo.requireDependencies), moduleInfo.dependencies

  return moduleInfo

module.exports = extractModuleInfo

#console.log "\n## inline test - module info ##"
#console.log extractModuleInfo """
#({uRequire: {rootExport: 'papari'}})
#
#if (typeof define !== 'function') { var define = require('amdefine')(module); };
#
#define('moduleName', ['require', 'underscore', 'depdir1/dep1'], function(require, _, dep1) {
#  _ = require('underscore');
#  var i = 1;
#  var r = require('someRequire');
#  if (require === 'require') {
#   for (i=1; i < 100; i++) {
#      require('myOtherRequire');
#   }
#   require('myOtherRequire');
#  }
#  console.log("\n main-requiring starting....");
#  var crap = require("crap" + i); //not read
#
#  return {require: require('finalRequire')};
#});
#"""
#console.log "################### \n"

