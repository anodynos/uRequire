_ = require 'lodash'
l = require './../utils/logger'
seekr = require './seekr'

#todo: node : tolerate 'return' statements when parsing - enclose in fake function

class JSManipulator
  parser = require("uglify-js").parser
  proc = require("uglify-js").uglify
  slang = require './../utils/slang'

  constructor: (@js = '', @options = {})->
    @options.beautify ?= false
    @AST = parser.parse @js
    that: this

  toCode: (astCode = @AST) ->
    proc.gen_code astCode, beautify: @options.beautify

  evalByType: slang.certain {
    'string': (val)-> (@toCode val).replace /\"|\'/g, ''
    #'array': (val)->
    #'object': (val)->
    '*': (val)-> @toCode val
    }

  safeEval: (elem)=>
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
      name: ast[1]
      args: ast[2]
      body: ast[3]

    'defun': (ast)->
      name: ast[1]
      args: ast[2]
      body: ast[3]

class AMDModuleManipulator extends JSManipulator
  constructor: (js, @options = {})->
    super
    @options.extractFactory ?= false
    @moduleInfo = {} #store all returned info here
    @AST_FactoryBody = null # a ref to the factoryBody, used to produce factBody & l8r to mutate requires

  _gatherItemsInSegments: (astArray, segments)->
    astArray = [astArray] if not _(astArray).isArray()
    for elem in astArray
      elType = elem[0] #eg 'string'
      if not segments[elType]
        if segments['*'] then elType = '*' else break

      (@moduleInfo[segments[elType]] or= []).push @safeEval elem

  extractModuleInfo: ->
    uRequireJsonHeaderSeeker =
      level: min: 4, max: 4
      '_object': (o)->
        if o.top is 'uRequire'
          properties = eval "(#{@toCode o.props})" # todo read with safeEval
          @moduleInfo = _.extend @moduleInfo, properties
          'stop' #kill this seeker!

    defineAMDSeeker =
      level: min: 4, max: 4
      '_call': (c)->
        if c.name in ['define', 'require']
          if c.args.length is 3 and # *named* AMD signature define 'name', [], ->
          c.args[0][0] is 'string' and
          c.args[1][0] is 'array' and
          c.args[2][0] is 'function'
            @moduleInfo.moduleName = @safeEval c.args[0]
            amdDeps = c.args[1][1]
            factoryFn = c.args[2]
          else
            if c.args.length is 2 and # *standard* anomynous AMD signature define [],->
            c.args[0][0] is 'array' and
            c.args[1][0] is 'function'
              amdDeps = c.args[0][1]
              factoryFn = c.args[1]
            else
              if c.args.length is 1 and
              c.args[0][0] is 'function' #define ->
                amdDeps = []
                factoryFn = c.args[0]

          if factoryFn # found AMD, otherwise its null
            fn = @readAST['function'] factoryFn

            @moduleInfo.parameters = fn.args if not _(fn.args).isEmpty() # args of function (dep1, dep2)
            @AST_FactoryBody = ['block', fn.body ] #needed l8r for replacing body require deps

#            @moduleInfo.parameters = factoryFn[2] if not _(factoryFn[2]).isEmpty() # args of function (dep1, dep2)
#            @AST_FactoryBody = ['block', factoryFn[3] ] #needed l8r for replacing body require deps
            if @options.extractFactory #just save toCode for to-be-replaced-factoryBody
              @moduleInfo.factoryBody = @toCode @AST_FactoryBody
              @moduleInfo.factoryBody = @moduleInfo.factoryBody[1..@moduleInfo.factoryBody.length-2] #drop '{', '}'
            @_gatherItemsInSegments amdDeps, {'string':'arrayDependencies', '*':'untrustedArrayDependencies'}
            @moduleInfo.moduleType = 'AMD'
            @moduleInfo.amdCall = c.name # amd call name, ie 'define' or 'require'
            'stop' #kill it, found what we wanted!
    seekr [ uRequireJsonHeaderSeeker, defineAMDSeeker], @AST, @readAST, @ #

    if @moduleInfo.moduleType isnt 'AMD'
      UMDSeeker =
        level: min: 4, max: 5
        '_function': (f)->
          if _(f.args).isEqual ['root', 'factory']
            @moduleInfo.moduleType = 'UMD'
            @AST_FactoryBody = null
            'stop'
      seekr [ UMDSeeker ], @AST, @readAST, @

      if @moduleInfo.moduleType isnt 'UMD'
        @moduleInfo.moduleType = 'node'
        @AST_FactoryBody = @AST
        if @options.extractFactory
          @moduleInfo.factoryBody = @js

    # find all require '' and require ['..'],-> calls. String params are ok, all others are untrusted
    if @AST_FactoryBody
      requireCallsSeeker =
        '_call': (c)->
          if  c.name is 'require'
            if c.args[0][0] is 'array'
              @_gatherItemsInSegments c.args[0][1], {'string':'asyncDependencies', '*':'untrustedAsyncDependencies'}
            else # 'string', 'binary' etc
              @_gatherItemsInSegments c.args, {'string':'requireDependencies', '*':'untrustedRequireDependencies'}

      seekr [ requireCallsSeeker ], @AST_FactoryBody, @readAST, @
      # some tidying up : keep only 1) unique requireDeps & 2) extra to 'dependencies'
      if not _(@moduleInfo.requireDependencies).isEmpty()
        @moduleInfo.requireDependencies = _.difference (_.uniq @moduleInfo.requireDependencies), @moduleInfo.arrayDependencies

    return @moduleInfo

  _replaceASTStringElements: (astArray, replacements)->
    astArray = [astArray] if not _(astArray).isArray()
    for elem in astArray
      if elem[0] is 'string' # i.e elType
        if replacements[elem[1]]
          elem[1] = replacements[elem[1]]

  #replace bundleRelative to fileRelative require('..') and
  getFactoryWithReplacedRequires: (requireReplacements)->
    if @AST_FactoryBody
      requireCallsReplacerSeeker =
        '_call': (c)->
          if  c.name is 'require'
            if c.args[0][0] is 'array'
              @_replaceASTStringElements c.args[0][1], requireReplacements
            else if c.args[0][0] is 'string' #ignore others, eg 'binary' etc
              @_replaceASTStringElements c.args, requireReplacements
      seekr [ requireCallsReplacerSeeker ], @AST_FactoryBody, @readAST, @

      fb = @toCode @AST_FactoryBody
      if @moduleInfo.moduleType is 'AMD'
        fb = fb[1..fb.length-2] #drop '{', '}'

      return @moduleInfo.factoryBody = fb



module.exports = AMDModuleManipulator

#log = console.log
#log "\n## inline test - module info ##"
#theJs = """
#//({uRequire: {rootExport: 'papari'}})
#
#if (typeof define !== 'function') { var define = require('amdefine')(module); };
#
#define('moduleName', ['require', marika, 'underscore', 'depdir2/dep1'], function(require, _, dep1) {
#  _ = require('lodash');
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
#  require(['asyncDep1', 'asyncDep2'], function(asyncDep1, asyncDep2) {
#    if (require('underscore')) {
#      require(['asyncDepOk', 'async' + crap2], function(asyncDepOk, asyncCrap2) {
#        return asyncDepOk + asyncCrap2;
#      });
#    }
#
#    return asyncDep1 + asyncDep2;
#  });
#
#
#  return {require: require('finalRequire')};
#});
#"""
#
#theJs = """
#  b = require('b/b-lib');
#  module.exports = {b:'b'}
#"""
#
#modMan = new AMDModuleManipulator theJs, beautify:false
#modMan.extractModuleInfo()
#log modMan.moduleInfo
