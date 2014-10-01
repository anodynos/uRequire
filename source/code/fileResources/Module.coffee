_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/Module'#, 100
_.mixin (require 'underscore.string').exports()
fs = require 'fs'
util = require 'util'
When = require 'when'

# uRequire
upath = require '../paths/upath'
ModuleGeneratorTemplates = require '../templates/ModuleGeneratorTemplates'
TextResource = require './TextResource'
Dependency = require "./Dependency"
UError = require '../utils/UError'

isTrueOrFileInSpecs = require '../config/isTrueOrFileInSpecs'

isLikeCode = require "../codeUtils/isLikeCode"
isEqualCode = require "../codeUtils/isEqualCode"
replaceCode = require "../codeUtils/replaceCode"

toAST =  require "../codeUtils/toAST"
toCode = require "../codeUtils/toCode"

# Represents a Javascript nodejs/commonjs or AMD module
class Module extends TextResource

  # override @dstFilename, save modules in build.template._combinedFileTemp if it exists
  Object.defineProperties @::,
    dstPath: get:->
      if @bundle?.build.template._combinedFileTemp
        @bundle.build.template._combinedFileTemp
      else
        if @bundle?.build.dstPath
          @bundle.build.dstPath
        else
          ''
  # @todo: infer 'booleanOrFilespecs' from blendConfigs (with 'arraysConcatOrOverwrite' BlenderBehavior ?)
  for bof in ['useStrict', 'bare', 'globalWindow',
              'runtimeInfo', 'noRootExports',
              'allNodeRequires', 'dummyParams'
              'scanAllow', 'injectExportsModule',
              'noLoaderUMD', 'warnNoLoaderUMD']
    do (bof)->
      Object.defineProperty Module::, 'is'+ _.capitalize(bof),
        get: -> isTrueOrFileInSpecs @bundle?.build?[bof], @path

  ###
    Check if `super` in TextResource has spotted changes and thus has a possibly changed @converted (javascript code)
    & call `@adjust()` if so.

    It does not actually convert to any template - the bundle building does that

    But the module info needs to provide dependencies information (eg to inject Dependencies etc)
  ###
  refresh: ->
    When.promise (resolve, reject)=> # @todo: can this be simplified ?
      super.then( (superRefreshed)=>
        if not superRefreshed
          resolve false # no change in parent, why should I change ?
        else
          if @sourceCodeJs isnt @converted # @converted is produced by TextResource's refresh
            @sourceCodeJs = @converted
            @extract()
            @prepare()
            resolve @hasChanged = true
          else
            l.debug "No changes in compiled sourceCodeJs of module '#{@srcFilename}' " if l.deb 90
            resolve @hasChanged = false
      ).catch (err)-> l.err err; reject err
#      ).catch l.err

  reset:->
    super
    delete @sourceCodeJs
    @resetModuleInfo()

  # init / clear stuff & create those on demand
  resetModuleInfo:->
    @flags = {}
#    delete @[dv] for dv in @AST_data
    @[dv] = [] for dv in @keys_extractedDepsAndVarsArrays
    delete @defineArrayDeps
    delete @parameters

  # keep a reference to our data, easy to init & export
  AST_data: [
    'AST_top', 'AST_body', 'AST_factoryBody'
    'AST_preDefineIIFENodes'
  ]

  keys_extractedDepsAndVarsArrays: [
    'ext_defineArrayDeps',  'ext_defineFactoryParams'
    'ext_requireDeps',      'ext_requireVars'
    'ext_asyncRequireDeps', 'ext_asyncFactoryParams'
  ]

  keys_resolvedDependencies: [
    'defineArrayDeps', 'nodeDeps'
  ]

  # info for debuging / testing (empties are eliminated)
  info: ->
    info = {}
    for p in _.flatten [
      @keys_extractedDepsAndVarsArrays,
      @keys_resolvedDependencies, [
        'flags', 'name', 'kind', 'path'
        'factoryBody', 'preDefineIIFEBody', 'parameters']
      ]
      if !_.isEmpty @[p]
        if _.isArray @[p]
          info[p] = _.map @[p], (x)=>
            if p in @keys_resolvedDependencies
              x.name()      # return fileRelative, with plugin & ext if exists
            else
              x.toString()  # return as is
        else
          info[p] = @[p]
    info

  # Read the AST of defineArrayDeps & factory params and add them to the corresponding arrays
  readArrayDepsAndVars: (arrayAst, arrayDeps, paramsAst, factoryParams)->
    for astArrayDep, idx in arrayAst.elements
      param = paramsAst[idx]?.name

      if _B.isLike {type: 'Literal'}, astArrayDep # astArrayDep is { type: 'Literal', value: 'someString' }
        arrayDep = new Dependency astArrayDep.value, @,
                    AST_requireLiterals: [ astArrayDep ] # store refs to ASTs of this dep for quick replacements
      else
        arrayDep = new Dependency (@toCode astArrayDep), @, {
                                    untrusted:true,
                                    AST_requireUntrustedDep: [astArrayDep]} # useless for now

      arrayDeps.push arrayDep if arrayDep
      factoryParams.push param if param

    # add excessive params as they are
    for excParamIdx in [arrayAst.elements.length..paramsAst.length-1] by 1
      factoryParams.push paramsAst[excParamIdx]?.name
    @

  # called at each AST node as the AST tree is traversed
  requireFinder: (prop, src, dst, blender)=> # bind to this instance
    # do we have a `require()` CallExpression nested somewhere ?
    if _B.isLike {type:"CallExpression", callee: {type: "Identifier", name: "require"}}, src[prop]

      if _B.isLike {arguments: [type: 'Literal']}, src[prop] # require('aStringLiteral')
        requireDep = new Dependency src[prop].arguments[0].value, @,
                                    AST_requireLiterals: [ src[prop].arguments[0] ]

      else # require( non literal expression ) #@todo: warn for wrong signature
        #  signature of async `require([dep1, dep2], function(dep1, dep2){...})`
        if _B.isLike [{type: 'ArrayExpression'}, {type: 'FunctionExpression'}], src[prop].arguments
          args = src[prop].arguments
          @readArrayDepsAndVars(args[0],        (@ext_asyncRequireDeps or= []),    # async require deps array, at pos 0
                                args[1].params, (@ext_asyncFactoryParams or= []) ) # async factory function, at pos 1

        else
          requireDep = new Dependency (@toCode src[prop].arguments[0]), @, untrusted:true

      # store the assigned or declared requireVar
      if _B.isLike({type: 'AssignmentExpression', left: type:'Identifier'}, src) or
         _B.isLike({type: 'VariableDeclarator', id: type: 'Identifier'}, src)

        requireVar =
          if _B.isLike type: 'AssignmentExpression', src
            src.left.name
          else # assigned as a declaration
            src.id.name

        # warn if `require('string literal')` signature is wrong
        if src[prop].arguments.length > 1  #@todo: improve
          l.warn """Wrong require() signature in #{@toCode src[prop]}
                    Use the proper AMD `require([dep1, dep2], function(dep1, dep2){...})` for the asnychronous AMD require."""

      # keep dep & var together - insert at the index of last var
      # push deps without a var to the end
      if requireDep
        if requireVar
          (@ext_requireVars or= []).push requireVar
          (@ext_requireDeps or= []).splice @ext_requireVars.length-1, 0, requireDep
        else
          (@ext_requireDeps or= []).push requireDep

    return null

  extract: ->
    l.debug "@extract for '#{@srcFilename}'" if l.deb 70
    @resetModuleInfo()
    try
      @AST_top = toAST @sourceCodeJs #, {comment:true, range:true}
    catch err
      throw new UError "Error while parsing top Module's javascript.", nested: err

    # retrieve bare body, i.e without coffeescript IIFE (function(){..body..}).call(this);
    if isLikeCode('(function(){}).call()', @AST_top.body) or
       isLikeCode('(function(){}).apply()', @AST_top.body)
      @AST_body = @AST_top.body[0].expression.callee.object.body.body
      @AST_preDefineIIFENodes = []   # store all nodes along IIFEied define()
    else
      if isLikeCode '(function(){})()', @AST_top.body
        @AST_body = @AST_top.body[0].expression.callee.body.body
        @AST_preDefineIIFENodes = []   # store all nodes along IIFEied define()
      else
        @AST_body = @AST_top.body

    # we now have our @AST_body, with no IIFE
    defines = [] # should contain max one define()
    for bodyNode, idx in @AST_body
      # look for a) single define call b) flags
      # store preDefineIIFENodes, but exclude flags and amdefine :-)
      if bodyNode.expression and isLikeCode 'define()', bodyNode
        defines.push bodyNode.expression
        if defines.length > 1
          throw new UError "Each AMD file shoule have one (top-level or IIFE) define call - found #{defines.length} `define` calls"
      else
        # grab flags - dont add to @AST_preDefineIIFENodes
        if isLikeCode '({urequire:{}})', bodyNode
          @flags = (eval @toCode bodyNode).urequire
        else
          # omit 'amdefine' from @AST_preDefineIIFENodes
          if not (isLikeCode('var define;', bodyNode)  or
             isLikeCode('if(typeof define!=="function"){define=require("amdefine")(module);}', bodyNode) or
             isLikeCode('if(typeof define!=="function"){var define=require("amdefine")(module);}', bodyNode)) and
             not isLikeCode(';', bodyNode) and @AST_preDefineIIFENodes
               @AST_preDefineIIFENodes.push bodyNode

    # AMD module
    if defines.length is 1
      define = defines[0]
      args = define.arguments

      AMDSignature = ['Literal', 'ArrayExpression', 'FunctionExpression']
      for i in [0..args.length-1]
        if args[i].type isnt AMDSignature[i+(3-args.length)]
          throw new UError "Invalid AMD define() signature with #{args.length} args: got a '#{args[i].type}' as arg #{i}, expected a '#{AMDSignature[i+(3-args.length)]}'."

      @kind = 'AMD'
      @name = args[0].value if args.length is 3
      if args.length >=2
        @readArrayDepsAndVars args[args.length-2],        @ext_defineArrayDeps,     # deps array : either at pos 0 or 1, followed by factory function
                              args[args.length-1].params, @ext_defineFactoryParams  # factory function, always last argument

      else # just 1 factory arg - pluck name
        @ext_defineFactoryParams = _.map args[args.length-1].params, 'name'

      @AST_factoryBody = args[args.length-1].body
    else
      @kind = 'nodejs'

      @AST_factoryBody =
        if _.isEmpty @AST_preDefineIIFENodes
          @AST_body
        else
          @AST_preDefineIIFENodes #use instead of @AST_body, as it ommits flags

      delete @AST_preDefineIIFENodes

    _B.traverse @AST_factoryBody, @requireFinder # store info from `require()` calls

    l.debug "'#{@srcFilename}' extracted module .info():\n", _.omit @info(), ['factoryBody', 'preDefineIIFEBody'] if l.deb 90
    @

  # leave basic extracted as is, but create the Dependency arrays actually used on template
  prepare: ->
    l.debug "@prepare for '#{@srcFilename}'\n" if l.deb 70

    # Store @parameters removing *redundant* ones (those in excess of @ext_defineArrayDeps):
    # RequireJS doesn't like them if require is 1st param!
    @parameters =
      if @ext_defineArrayDeps.length is 0
        []
      else
        @ext_defineFactoryParams[0..@ext_defineArrayDeps.length-1]

    if (@ext_defineArrayDeps.length < @ext_defineFactoryParams.length)
      l.deb "module `#{@path}`: Discarding redundant define factory parameters", @ext_defineFactoryParams[@ext_defineArrayDeps.length..] if l.deb 5

    # add dummy params for deps without corresponding params
    if @isDummyParams
      if (lenDiff = @ext_defineArrayDeps.length - @parameters.length) > 0
        @parameters.push "___dummy___param__#{pi}" for pi in [1..lenDiff]

    # Our final' defineArrayDeps will eventually have -in this order-:
    #   - original ext_defineArrayDeps, each instantiated as a Dependency
    #   - all dependencies.exports.bundle, if template is not 'combined'
    #   - module injected dependencies
    #   - Add all deps in `require('dep')`, from @module.ext_requireDeps are added
    # @see adjust
    @defineArrayDeps = (dep.clone() for dep in @ext_defineArrayDeps)

    # 'require' & associates are *fixed* in UMD template (if needed), so remove 'require' as dep & arg
    # @todo: check template and with module, exports
    if ar1 = (@parameters[0] is 'require') | ar2 = (@defineArrayDeps[0]?.isEqual? 'require')
      if ar1 and (ar2 or @defineArrayDeps[0] is undefined)
        @parameters.shift()
        @defineArrayDeps.shift()
      else
        throw new UError("Module '#{@path}':" +
          if ar1 then "1st define factory argument is 'require', but 1st dependency is '#{@defineArrayDeps[0]}'"
          else "1st dependency is 'require', but 1st define factory argument is '#{@parameters[0]}'")

    @

  ###
  Produce final template information:

  - bundleRelative deps like `require('path/dep')` in factory, are replaced with their fileRelative counterpart

  - injecting dependencies?.exports?.bundle

  - add @ext_requireDeps to @defineArrayDeps
  @todo: decouple from build, use calculated (cached) properties, populated at convertWithTemplate(@build) step
  ###
  adjust: (@build)->
    l.debug "@adjust for '#{@srcFilename}'" if l.deb 70

    if @build?.template?.name isnt 'combined' # 'combined doesn't need them - they are added to the define that calls the factory
      @injectDeps @bundle?.dependencies?.exports?.bundle

    # add exports.root, i.e {'models/PersonModel': ['persons', 'personsModel']}`
    # is like having a `{rootExports: ['persons', 'personsModel'], noConflict:true}` in 'models/PersonModel' module.
    @flags.rootExports = _B.arrayize @flags.rootExports if @flags.rootExports
    if rootExports = @bundle?.dependencies?.exports?.root?[@path]
      (@flags.rootExports or= []).push rt for rt in _B.arrayize rootExports
      @flags.noConflict = true

    @webRootMap = @bundle?.webRootMap || '.'

    #  Add all deps in `require('dep')`, from @module.ext_requireDeps(those not already there)
    #  Reason: execution stucks on require('dep') if its not loaded (i.e not present in ext_defineArrayDeps).
    #         see https://github.com/jrburke/requirejs/issues/467
    #  Even if there are no other arrayDependencies, we still add them all to prevent RequireJS scan @ runtime
    #  (# RequireJs disables runtime scan if even one dep exists in []).
    #  We dont add them only if _.isEmpty and `--scanAllow` and we dont have a `rootExports`
    addToArrayDependencies = (reqDep)=>
      if (not reqDep.isNode )
        foundDeps = _.filter @defineArrayDeps, (dep)->dep.isEqual reqDep
        if _.isEmpty foundDeps # if not already there
          #reqDep = reqDep.clone() # clone, to keep ext_XXX intact #lo longer needed
          @defineArrayDeps.push reqDep
        else
          for rl in (reqDep.AST_requireLiterals or [])   # pass any ASTs to a foundDep so its gets updated.
            _.last(foundDeps).AST_requireLiterals.push rl

    if not (_.isEmpty(@defineArrayDeps) and @isScanAllow and not @flags.rootExports)
      for reqDep in @ext_requireDeps
        addToArrayDependencies reqDep

    @updateRequireLiteralASTs()

    for newDep, oldDeps of (@bundle?.dependencies?.replace or {})
      for oldDep in oldDeps
        @replaceDep oldDep, newDep, relative: 'bundle'

    @

  # update dependencies in AST
  # It by default replaces each bundleRelative dep in require('someDir/someDep') calls
  # with the fileRelative path eg '../someDir/someDep' -that works everywhere-, remove 'node' fake pluging etc
  updateRequireLiteralASTs: ->
    for dep in _.flatten [ @defineArrayDeps, @ext_asyncRequireDeps ]
      if dep and not dep.untrusted
        dep.updateAST()

  # inject [depVars] Dependencies to defineArrayDeps
  # and their corresponding parameters (infered if not found)
  injectDeps: (depVars)->
    if l.deb(40)
      if not _.isEmpty depVars
        l.debug("#{@path}: injecting dependencies: ", depVars)

    {dependenciesBindingsBlender} = require '../config/blendConfigs' # circular reference delayed loading
    return if _.isEmpty depVars = dependenciesBindingsBlender.blend depVars

    @bundle?.inferEmptyDepVars? depVars, "Infering empty depVars from injectDeps for '#{@path}'"
    for depName, varNames of depVars
      dep = new Dependency depName, @
      if not dep.isEqual @path
        for varName in varNames # add for all corresponding vars, BEFORE the deps not corresponding to params!
          if not (varName in @parameters)
            @defineArrayDeps.splice @parameters.length, 0, dep
            @parameters.push varName
            l.debug("#{@path}: injected dependency '#{depName}' as parameter '#{varName}'") if l.deb 70
          else
            l.warn("#{@path}: NOT injecting dependency '#{depName}' as parameter '#{varName}' cause it already exists.") #if l.deb 90
      else
        l.debug("#{@path}: NOT injecting dependency '#{depName}' on self'") if l.deb 50

    null

  ###
  Replaces one or more Dependencies with another dependency on the Module (not the whole Bundle).

  It makes the replacements on

     * All Dependency instances in `@defineArrayDeps` array (which is also where @nodeDeps are derived)

     * All AST Literals in code, in deps array ['literal',...] or require('literal') calls,
       **always leaving the fileRelative replaceDep string **

  @param matchDep {String|RegExp|Function|Dependency} The dependency/ies to match,
       @see Dependency::isMatch about dep matching in general

       When a partial search is used for matching (noted with `|` at end of dep, for example `'../../lib|'`),
       then a partial replacement (i.e translation) is also performed:
       All deps that pass `_(dep).startsWith('../../lib')` will get only their '../../lib' path replaced with newDep, instead of a whole replacement.
       Hence `mod.replaceDep '../../some2/external/lib|', '../other/wow/lib/'` will do the obvious, translate the first part all mactching deps, i.e `'../../some2/external/lib/DEPENDENCY'` will become `'../other/wow/lib/DEPENDENCY'`.

       @see options below for matching & replacing in `relative:'file'` (default) or `relative:'bundle'`

  @param replaceDep {Dependency|String|Undefined} The dependency to replace the old with.
    * If `replaceDep` is empty, it removes all `matchDep`s from @defineArrayDeps
      (BUT NOT FROM THE AST @todo: why not - it can be costly but optional?)
    * if its a partial matchDep, then its only the matched part that will be replaced

    properly copy & spec of all its properties, plugin etc.

  @param options: {relative, plugin, ext} Whether to have these considered

    relative: @todo: explain
  ###
  replaceDep: (matchDep, newDep, options = {})->

    l.deb debugHead = """
        Module.replaceDep #{ if newDep then 'REPLACING' else ' DELETING'}: #{
        util.inspect options } #{util.inspect matchDep}, #{util.inspect newDep}""" if l.deb 70

    if _.isString matchDep
      matchDep = new Dependency matchDep, @ # set temporarily, cause we need plugin, resourceName, extension etc extraction

    if matchDep instanceof Dependency
      if (not options.relative) and    # if no specified relative: 'bundle|file'
         (not matchDep.isRelative)     # if matching a matchDep not starting with '.'
           options.relative = 'bundle' # then default to bundle, since we are searching for matchDep within bundle
                                       # otherwise use defaults
    if newDep
      if not (newDep instanceof Dependency)
        if _.isString newDep
          newDep = new Dependency newDep, @ # new dep
        else
          if not _.isFunction newDep
            l.er err = "#{debugHead} Wrong new dependency type '#{newDep}' in module #{@path} - should be String|Dependency|Undefined."
            throw new UError err

    #  both matchDep & newDep are Dependency instances now (if newDep exists)

    # find & update (or remove) all matching deps in defineArrayDeps
    removeArrayIdxs = []

    for dep, depIdx in (@defineArrayDeps or [])
      depName = dep.name options # relative: options.relative # plugin:false

      if isMatch = (if _.isFunction matchDep
                     matchDep depName, dep, options # dep has plugin, @module, @module.bundle etc
                   else
                     dep.isMatch matchDep, options)

        if not newDep # just mark idx for lazy removal
          l.debug 90, "mark depIdx for lazy removal '#{depIdx}'"
          removeArrayIdxs.push depIdx
        else # replace part
          if matchDep isnt newDep  # if matchDep IS newDep no replacement
            updDep = if _.isFunction(newDep)
                      newDep depName, dep
                    else
                      newDep

            updDep = new Dependency updDep, @ if _.isString updDep  # temporary to extract info

            if updDep
              if not (updDep instanceof Dependency)
                l.er err = "Wrong newDep dependency type '#{matchDep}' in module #{@path} - should be String|Function|Dependency."
                throw new UError err
              else
                dep.update updDep, matchDep, options
            else
              l.deb 90, "mark idx for lazy removal, returned from Function newDep '#{depIdx}'"
              removeArrayIdxs.push depIdx

    # lazy remove found old deps
    for rai in removeArrayIdxs by -1 # in reverse order so idxs stay meaningful
      l.deb "delete dependency '#{@defineArrayDeps[rai]}'" if l.deb(80)
      @defineArrayDeps.splice rai, 1
      @parameters.splice rai, 1


    null

  ###
  Returns all deps in this module along with their corresponding parameters (variable names)
  @param {Function} depFltr optional callback filtering dependency, called with dep (defaults to all-true fltr)
  @return {Object}
      {
        jquery: ['$', 'jQuery']
        lodash: ['_']
        'models/person': ['pm']
      }
  ###
  getDepsVars: (depFltr=->true)->
    varNames = {}
    depVarArrays = # use the Array<Dependency> ones, cause they talk 'bundleRelative'
      'defineArrayDeps'        : 'parameters'
      'ext_requireDeps'        : 'ext_requireVars'
      'ext_asyncRequireDeps'   : 'ext_asyncFactoryParams'

    for depsArrayName, varsArrayName of depVarArrays
      for dep, idx in (@[depsArrayName] or []) when depFltr(dep)
        bundleRelativeDep = dep.name relative:'bundle'
        dv = (varNames[bundleRelativeDep] or= [])
        # store the variable(s) associated with dep
        if @[varsArrayName][idx] and not (@[varsArrayName][idx] in dv )
          dv.push @[varsArrayName][idx] # if there is a var, add once
    varNames


  replaceCode: (matchCode, replCode)->
    replaceCode @AST_factoryBody, matchCode, replCode

  # add report data after all deps manipulations are done (adjust, & beforeTemplate RCs)
  addReportData:->
    for dep in _.flatten [ @defineArrayDeps
                           @ext_asyncRequireDeps
                           _.filter(@ext_requireDeps, (dep)-> dep.isNode) ]
      if dep.type not in ['bundle', 'system'] # ignore 'normal' ones
        @bundle?.reporter.addReportData _B.okv(dep.type, dep.name relative:'bundle'), @path # build a `{'local':['lodash']}`

  # Actually converts the module to the target @build options.
  convertWithTemplate: (@build) -> #set @build 'temporarilly': options like scanAllow & noRootExports are needed to calc deps arrays
    l.verbose "Converting '#{@path}' with template = '#{@build.template.name}'"
    l.debug("'#{@path}' adjusted module.info() = \n",
      _.pick @info(), _.flatten [@keys_resolvedDependencies, 'parameters', 'kind', 'name', 'flags']) if l.deb 60

    @moduleTemplate or= new ModuleGeneratorTemplates @
    @converted = @moduleTemplate[@build.template.name]() # @todo: (3 3 3) pass template, not its name

    # apply `optimize` (i.e minification) - uglify2 only
  optimize: (@build)->
    if @build.template.name isnt 'combined'
      if @build.optimize
        if @build.optimize is 'uglify2'
          l.verbose "Optimizing '#{@path}' with UglifyJS2..."
          @UglifyJS2 or= require 'uglify-js'
          (options = @build.uglify2 or {}).fromString = true
          @converted = (@UglifyJS2.minify @converted, options).code
        else
          l.warn "Not using `build.optimize` with '#{@build.optimize}' - only 'uglify2' works for Modules."
    @converted

  Object.defineProperties @::,

    nodeDeps: get: ->
      if @isAllNodeRequires
        @defineArrayDeps
      else
        # all deps with params
        if not @parameters?.length
          nds = []
        else
          nds = @defineArrayDeps?[0..@parameters?.length-1] or []

        # plus those without params AND not present as require('depX') #todo: simplify in @adjust
        if @defineArrayDeps
          for remainingDep in @defineArrayDeps[@parameters?.length..@defineArrayDeps.length-1]
            if not _.any((@ext_requireDeps or []), (rdep)-> rdep.isEqual remainingDep)
              nds.push remainingDep
        nds

    path: get:-> upath.trimExt @srcFilename if @srcFilename # filename (bundleRelative) without extension eg `models/PersonModel`

    factoryBody: get:->
      @updateRequireLiteralASTs() #ensure our AST is up to date with deps
      fb = @toCode @AST_factoryBody
      fb = fb[1..fb.length-2].trim() if @kind is 'AMD'
      fb

    # 'body' / statements BEFORE define (coffeescript & family gencode `__extend`, `__slice` etc)
    'preDefineIIFEBody': get:->
      @updateRequireLiteralASTs() #ensure our AST is up to date with deps
      @toCode @AST_preDefineIIFENodes if @AST_preDefineIIFENodes

  toCode: (astCode=@AST_body, codegenOptions = @codegenOptions)->
    @updateRequireLiteralASTs() #ensure our AST is up to date with deps
    toCode astCode, codegenOptions

module.exports = Module

_.extend module.exports.prototype, {l, _, _B}