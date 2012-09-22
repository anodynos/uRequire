_ = require 'lodash'
l = require './utils/logger'
seekr = require './utils/seekr'

class JSManipulator
  parser = require("uglify-js").parser
  proc = require("uglify-js").uglify

  constructor: (js = '', @options = {})->
    @options.beautify ?= true
    @ast = parser.parse js

  toCode: (astCode = @ast) ->
    proc.gen_code astCode, beautify: @options.beautify

  # helpers, reading from AST, keeping notation loosely close to uglify's process.js
  readAST:
    'call': (ast)->
      expr = ast[1]
      name = dot = ''
      dotExpr = expr
      while dotExpr[0] is 'dot' #extract dotted references (eg my.object.method)
        name = "#{dotExpr[2]}#{dot}#{name}"
        dotExpr = dotExpr[1]
        dot = '.'
      name = dotExpr[1] + dot + name

      #return
      name:name
      expr:expr
      args:ast[2]

    'object': (ast)->
      top: ast[1][0]?[0]
      props : ast[1][0][1]

    'function': (ast)->
      name:ast[0]
      args:ast[1]
      body:ast[2]

    'defun': (ast)->
      name:ast[0]
      args:ast[1]
      body:ast[2]

class AMDModuleManipulator extends JSManipulator
  constructor: (js, @options = {})->
    super
    @options.extractFactory ?= true
    @moduleInfo = {}
    @ast_factoryFunction = null
#    log options

  extractModuleInfoHeaderAndRequires:->

    uRequireJsonHeaderSeeker =
      name: "uRequire json options header"
      options:
        maxLevel:4
        minLevel:4
      matcher:
        'object':
          top: 'uRequire'
      filtersReader: @readAST['object']
      retriever: (top, props)->
        properties = eval "(#{@toCode props})"
        @moduleInfo = _.extend @moduleInfo, properties
        false #kill this seeker!


    defineAMDSeeker =
      name: "define [], -> AMD module header"
      options:
        maxLevel: 4 # just save on recursion. Not nested 'define' is @ level 4
        minLevel: 4
      matcher:
        'call':  # Matcher 'head'. If matched, filtersReader returns key:values, that all must be satisfied for retriever to be called.
          'name': ['define', 'require']   # a filter: can be string, array, function. NI: object? another matcher/filter?
          'args': (rgs)->                 # another filter, function this time
            switch rgs.length
              when 1
                rgs[0][0] is 'function'
              when 2 # *standard* anomynous AMD signature
                rgs[0][0] is 'array' and rgs[1][0] is 'function' # factoryFunction
              when 3 # *named* AMD signature (not recommended: http://requirejs.org/docs/api.html#modulename)
                # (moduleName, array dependencies, factoryFunction)
                rgs[0][0] is 'string' and rgs[1][0] is 'array' and rgs[2][0] is 'function'
              else false
          #_filter: (name, expr, args)->

      filtersReader: @readAST['call']

      retriever: (name, expr, args)-> # matching a 'call' returns these 3 args
        switch args.length
          when 1
            @moduleInfo.dependencies = []
            amdFactoryFunction = args[0]
          when 2
            @moduleInfo.dependencies = eval @toCode args[0]
            amdFactoryFunction = args[1]
          when 3
            @moduleInfo.moduleName = args[0][1]
            @moduleInfo.dependencies = eval @toCode args[1]
            amdFactoryFunction = args[2]

        @moduleInfo.type = name # function name, ie 'define' or 'require'
        @moduleInfo.parameters = amdFactoryFunction[2] || [] # args of function (dep1, dep2)
        @AST_FactoryBody = ['block', amdFactoryFunction[3] ]
        @moduleInfo.factoryBody = @toCode @AST_FactoryBody

        false #kill it, found what we wanted!

    requireCallsSeeker =
      minLevel:4
      name: "require('..') calls seeker"
      matcher:
        'call':
          name: 'require'
          args: (args)-> args.length is 1

      filtersReader: @readAST['call']

      retriever: (name, expr, args)->
        if args[0][0] is 'string'
          (@moduleInfo.requireDependencies or= []).push args[0][1]
          #args[0][1] = 'DIDITRE' + args[0][1] + 'DIDITRE'  ## mutate ! <<<<<<<<<<<<<<<<<<-----------
        else
          (@moduleInfo.wrongDependencies or= []).push @toCode args[0]

        true # dont kill it, we want them all!



    seekr [ uRequireJsonHeaderSeeker, defineAMDSeeker], @ast, @
    seekr [ requireCallsSeeker ], @AST_FactoryBody , @
    # some tidying up : keep unique requireDeps & extra to 'dependencies'
    @moduleInfo.requireDependencies = _.difference (_.uniq @moduleInfo.requireDependencies), @moduleInfo.dependencies


log = console.log
log "\n## inline test - module info ##"
theJs = """
({uRequire: {rootExport: 'papari'}})

if (typeof define !== 'function') { var define = require('amdefine')(module); };

define('moduleName', ['require', 'underscore', 'depdir2/dep1'], function(require, _, dep1) {
  _ = require('underscore');
  var i = 1;
  var r = require('someRequire');
  if (require === 'require') {
   for (i=1; i < 100; i++) {
      require('myOtherRequire');
   }
   require('myOtherRequire');
  }
  console.log("\n main-requiring starting....");
  var crap = require("crap" + i); //not read

  return {require: require('finalRequire')};
});
"""

#theJs = """
#define('moduleName', ['underscore', 'depdir2/dep1'], function define( _, dep1) {
#  var i = 1;
#});
#"""

modMan = new AMDModuleManipulator theJs, beautify:false
modMan.extractModuleInfoHeaderAndRequires()
log "################### \n"
log modMan.moduleInfo
log "################### \n"


