_ = require 'lodash'
l = require './utils/logger'

class JSManipulator
  parser = require("uglify-js").parser
  proc = require("uglify-js").uglify

  constructor: (js = '', @options = {})->
    @options.beautify ?= true
    @ast = parser.parse js

  toCode: (astCode = @ast) ->
    proc.gen_code astCode, beautify: @options.beautify

  # helpers, reading from AST
  readAst:
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

    function: (ast)->
      name:ast[0]
      args:ast[1]
      body:ast[2]

    defun: (ast)->
      name:ast[0]
      args:ast[1]
      body:ast[2]

  # A 'seeker' method, that recursivelly walks a tree
  # trying to find 'matches' of the `seeker` and then call the 'retriever'
  # to gather the found data
  # (not very generic tied to AST for now!)
  #
  # Theoretically, we could parse JavaScript, JSON and anything else, extracting information
  # via selectors/matchers & retrievers, just like we do with jQuery on the DOM!
  # Well, this is version 0.0.1 of it!
  #
  # A 'seeker' is mainly a 'matcher' & a 'retriever'.
  # Think of a 'matcher' as a super-duper selector in jQuery, or the where clause in SQL.
  # Similarly 'retriever' is the select part, but in anabolics!
  # todo: make it more generic, a pattern perhaps ?
  # todo: DOCUMENT IT!
  # example
  #
  # matcher:
  #   call:
  #     name: (it)->it in ['require', 'define']
  #     args: (it)->it.length is 2
  # retriever: (name, expr, args):->
  #   log 'got a function with name #{name} and 2 args #{args}'

  extractAST: (seekers, ast = @ast, _level = 0, _continue = true, _stack = [])->
    _level++
    if _level is 1 #some inits
      if not _(seekers).isArray() then seekers = [seekers] # just one, make it an array!

    if _continue
      _(ast).each (astItem)->
        if _(astItem).isObject() or _(astItem).isArray()
          _stack.push astItem
          @extractAST seekers, astItem, _level, _continue, _stack
          _stack.pop()
        else # do we have an interesting astItem, eg 'call', 'function' etc
          stacktop = _stack[_stack.length-1]
#          log '*************** \n', _level, '\n', stacktop
          deadSeekers = []
          for skr in seekers
            if _level <= (skr.options?.maxLevel ? 999999) and #should be enough ;-)
            _level >= (skr.options?.minLevel ? 0)

              if skr.matcher[astItem] and  # does matcher regard astItem, eg 'call' ?
              @readAst[astItem]  # todo: just cause we haven't defined all of em in readAst!
                astRead = @readAst[astItem](stacktop)
                isMatch = true # optimistic
                for filterKey, filter of skr.matcher[astItem] when isMatch
                  itemToFilter = astRead[filterKey] # eg 'args'
    #              log 'filter key:', selectorKey, ' filter:', fltr, ' ast:', astRead[selectorKey]
                  isMatch =
                    if _(filter).isArray()
                      itemToFilter in filter
                    else
                      if _(filter).isFunction()
                        filter itemToFilter
                      else #eg 'string'
                        filter is itemToFilter
                if isMatch # all filters where satisfied
                  if not (skr.retriever.apply @, _.map astRead, (v)->v) # callback with the read astItem found. _stop if cb is false
                    deadSeekers.push skr # retriever killed you

          seekers = _.difference seekers, deadSeekers
          _continue = not _(seekers).isEmpty() # return true for lodash's each to go on
      , @ #bind this for each

class AMDModuleManipulator extends JSManipulator
  constructor: (js, @options = {})->
    super
    @options.extractFactory ?= true
    @moduleInfo = {}
    @ast_factoryFunction = null
#    log options

  extractModuleInfoHeaderAndRequires:->
    seekers = [
      name: "define AMD module header"
      options:
        maxLevel: 4 # just save on recursion. Not-nested define is level 4

      matcher:
        'call':                         # Matcher 'head'. A matcher has filters, all must be satisfied
          name: ['define', '!!!require']   # a filter: can be string, array, function. NI: object? another matcher/filter?
          args: (rgs)->                # another filter, function this time
            switch rgs.length
              when 1
                rgs[0][0] is 'function'
              when 2 # *standard* anomynous AMD signature
                rgs[0][0] is 'array' and rgs.args[1][0] is 'function' # factoryFunction
              when 3 # *named* AMD signature (not recommended: http://requirejs.org/docs/api.html#modulename)
              # (moduleName, array dependencies, factoryFunction)
                rgs[0][0] is 'string' and rgs[1][0] is 'array' and rgs[2][0] is 'function'
              else false

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
        @moduleInfo.factoryBody = @toCode ['block', amdFactoryFunction[3] ]

        false #kill it, found what we wanted!
    ,

      name: "require('..') calls seeker"
      matcher:
        'call':
          name: 'require'
          args: (args)-> args.length is 1

      retriever: (name, expr, args)->
        if args[0][0] is 'string'
          (@moduleInfo.requireDependencies or= []).push args[0][1]
          args[0][1] = 'DIDITRE' + args[0][1] + 'DIDITRE'  ## <<<<<<<<<<<<<<<<<<-----------
        else
          (@moduleInfo.wrongDependencies or= []).push @toCode args[0]

        true # dont kill it, we want them all!
    ,

      name: "uRequire json options header"
      matcher:
        'object': ### not working ### ??? <<<<<<<<<<<<<<<<<<-----------
          name: 'uRequire'
          args: (args)-> args.length is 1

      retriever: (name, expr, args)->

    ]

    @extractAST seekers
    # some tidying up
    # keep unique requireDeps & extra to 'dependencies'
    @moduleInfo.requireDependencies = _.difference (_.uniq @moduleInfo.requireDependencies), @moduleInfo.dependencies
    log @toCode @ast

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
modMan.extractModuleHeaderAndRequires()
log modMan.moduleInfo

log "################### \n"
