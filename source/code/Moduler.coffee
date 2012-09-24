_ = require 'lodash'
l = require './utils/logger'
seekr = require './utils/seekr'

class JSManipulator
  parser = require("uglify-js").parser
  proc = require("uglify-js").uglify
  slang = require './utils/slang'

  constructor: (js = '', @options = {})->
    @options.beautify ?= true
    @ast = parser.parse js
    that: this

  toCode: (astCode = @ast) ->
    proc.gen_code astCode, beautify: @options.beautify

  evalByType: slang.certain {
    'string': (val)-> (@toCode val).replace /\"|\'/g, ''
    #'array': (val)->
    #'object': (val)->
    '*': (val)-> @toCode val
    }

  safeEval: (elem)=>
    log 'elem:', elem
    @evalByType(elem[0]).call this, elem #todo change call pattern, bind to instance otherwise


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

  gatherItemsInSegments: (astArray, segments)->
    astArray = [astArray] if not _(astArray).isArray()
    for elem in astArray
      elType = elem[0] #eg 'string'
      if not segments[elType]
        if segments['*'] then elType = '*' else break

      (@moduleInfo[segments[elType]] or= []).push @safeEval elem  #elType)(@toCode elem)

  extractModuleInfoHeaderAndRequires: ->
    uRequireJsonHeaderSeeker =
      level: min: 4, max: 4
      '_object': (o)->
        if o.top is 'uRequire'
          properties = eval "(#{@toCode o.props})" # todo read with safeEval
          @moduleInfo = _.extend @moduleInfo, properties
          'stop'
    #kill this seeker!

    defineAMDSeeker =
      level: min: 4, max: 4
      '_call': (c)->
        if c.name in ['define', 'require']
          if c.args.length is 3 and # *named* AMD signature define 'name', [], ->
          c.args[0][0] is 'string' and
          c.args[1][0] is 'array' and
          c.args[2][0] is 'function'
            @moduleInfo.moduleName = @safeEval c.args[0]
            amdDependencies = c.args[1][1]
            amdFactoryFunction = c.args[2]
          else
            if c.args.length is 2 and # *standard* anomynous AMD signature define [],->
            c.args[0][0] is 'array' and
            c.args[1][0] is 'function'
              amdDependencies = c.args[0][1]
              amdFactoryFunction = c.args[1]
            else
              if c.args.length is 1 and
              c.args[0][0] is 'function' #define ->
                amdDependencies = []
                amdFactoryFunction = c.args[0]

          if amdFactoryFunction # found AMD, otherwise its null
            @moduleInfo.type = c.name # function name, ie 'define' or 'require'
            @gatherItemsInSegments amdDependencies, {'string':'dependencies', '*':'untrustedDependencies'}
            @moduleInfo.parameters = amdFactoryFunction[2] || [] # args of function (dep1, dep2)
            @AST_FactoryBody = ['block', amdFactoryFunction[3] ]
            @moduleInfo.factoryBody = @toCode @AST_FactoryBody
            'stop'
    #kill it, found what we wanted!

    requireCallsSeeker =
      level: min: 4
      '_call': (c)->
        if  c.name is 'require'
          switch c.args[0][0] #type, eg 'array', 'string'
            when 'array'
              @gatherItemsInSegments c.args[0][1], {'string':'asyncDependencies', '*':'untrustedAsyncDependencies'}
            when 'string'
              @gatherItemsInSegments c.args, {'string':'requireDependencies', '*':'unresolvedRequireDependencies'}

    seekr [ defineAMDSeeker, uRequireJsonHeaderSeeker], @ast, @readAST, @ #
    #
    if @AST_FactoryBody
      seekr [ requireCallsSeeker ], @AST_FactoryBody, @readAST, @
      # some tidying up : keep only 1) unique requireDeps & 2) extra to 'dependencies'
      @moduleInfo.requireDependencies = _.difference (_.uniq @moduleInfo.requireDependencies), @moduleInfo.dependencies


log = console.log
log "\n## inline test - module info ##"
theJs = """
({uRequire: {rootExport: 'papari'}})

if (typeof define !== 'function') { var define = require('amdefine')(module); };

define('moduleName', ['require', marika, 'underscore', 'depdir2/dep1'], function(require, _, dep1) {
  _ = require('lodash');
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

  require(['asyncDep1', 'asyncDep2'], function(asyncDep1, asyncDep2) {
    return asyncDep1 + asyncDep2;
  });

  require(['asyncDepOk', 'async' + crap2], function(asyncDep1, asyncDep2) {
    return asyncDep1 + asyncDep2;
  });

  return {require: require('finalRequire')};
});
"""

modMan = new AMDModuleManipulator theJs, beautify:false
modMan.extractModuleInfoHeaderAndRequires()
log ('#' for i in [1..25]).join('')
log modMan.moduleInfo








