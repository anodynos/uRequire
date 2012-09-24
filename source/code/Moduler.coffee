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
      name: name
      expr: expr
      args: ast[2]


    'object': (ast)->
      top: ast[1][0]?[0]
      props: ast[1][0][1]

    'function': (ast)->
      name: ast[0]
      args: ast[1]
      body: ast[2]

    'defun': (ast)->
      name: ast[0]
      args: ast[1]
      body: ast[2]

class AMDModuleManipulator extends JSManipulator
  constructor: (js, @options = {})->
    super
    @options.extractFactory ?= true
    @moduleInfo = {}
    @ast_factoryFunction = null
  #    log options

  extractModuleInfoHeaderAndRequires: ->
    uRequireJsonHeaderSeeker =
      level:
        min: 4, max: 4
      '_object': (o)->
        if o.top is 'uRequire'
          properties = eval "(#{@toCode o.props})"
          @moduleInfo = _.extend @moduleInfo, properties
          'stop'
    #kill this seeker!

    defineAMDSeeker =
      level:
        min: 4, max: 4
      '_call': (c)->
        if c.name in ['define', 'require']
          if c.args.length is 3 and # *named* AMD signature
          c.args[0][0] is 'string' and c.args[1][0] is 'array' and c.args[2][0] is 'function'
            @moduleInfo.moduleName = c.args[0][1]
            @moduleInfo.dependencies = eval @toCode c.args[1]
            amdFactoryFunction = c.args[2]
          else
            if c.args.length is 2 and # *standard* anomynous AMD signature
            c.args[0][0] is 'array' and c.args[1][0] is 'function'
              @moduleInfo.dependencies = eval @toCode c.args[0]
              amdFactoryFunction = c.args[1]
            else
              if c.args.length is 1 and
              c.args[0][0] is 'function'
                @moduleInfo.dependencies = []
                amdFactoryFunction = c.args[0]

          if amdFactoryFunction # found AMD, otherwise its null
            @moduleInfo.type = c.name
            # function name, ie 'define' or 'require'
            @moduleInfo.parameters = amdFactoryFunction[2] || []
            # args of function (dep1, dep2)
            @AST_FactoryBody = ['block', amdFactoryFunction[3] ]
            @moduleInfo.factoryBody = @toCode @AST_FactoryBody
            'stop'
    #kill it, found what we wanted!

    requireCallsSeeker =
      level:
        min: 4
      '_call': (c)->
        if  c.name is 'require'
          if c.args.length is 1
            if c.args[0][0] is 'string'
              (@moduleInfo.requireDependencies or= []).push c.args[0][1]
              #args[0][1] = 'DIDITRE' + args[0][1] + 'DIDITRE'  ## mutate ! <<<<<<<<<<<<<<<<<<-----------
            else
              (@moduleInfo.wrongDependencies or= []).push @toCode c.args[0]

    seekr [ defineAMDSeeker, uRequireJsonHeaderSeeker], @ast, @readAST, @ #
    #
    if @AST_FactoryBody
      seekr [ requireCallsSeeker ], @AST_FactoryBody, @readAST, @
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

modMan = new AMDModuleManipulator theJs, beautify:false
modMan.extractModuleInfoHeaderAndRequires()
log modMan.moduleInfo







