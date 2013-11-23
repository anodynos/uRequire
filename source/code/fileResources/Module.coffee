# externals
_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
_B = require 'uberscore'
l = new _B.Logger 'urequire/fileResources/Module'#  100
fs = require 'fs'

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

  for bof in ['useStrict', 'bare', 'globalWindow', 'runtimeInfo', 'allNodeRequires', 'noRootExports', 'scanAllow'] # @todo: find 'boolOrFilez' from blendConfigs (with 'arraysConcatOrOverwrite' BlenderBehavior ?)
    do (bof)->
      Object.defineProperty Module::, 'is'+ _.capitalize(bof),
        get: -> isTrueOrFileInSpecs @bundle?.build?[bof], @dstFilename

        # @todo: enable setting it, after documenting (kept across multi builds)
        # set: (val)-> @_[bof] =  val
        # get: ->
        #   if _.isUndefined @_[bof]
        #     isTrueOrFileInSpecs @?bundle?.build?[bof], @dstFilename
        #   else
        #     @_[bof]

  ###
    Check if `super` in TextResource has spotted changes and thus has a possibly changed @converted (javascript code)
    & call `@adjust()` if so.

    It does not actually convert to any template - the bundle building does that

    But the module info needs to provide dependencies information (eg to inject Dependencies etc)
  ###
  refresh: ->
    if not super
      return false # no change in parent, why should I change ?
    else
      if @sourceCodeJs isnt @converted # @converted is produced by TextResource's refresh
        @sourceCodeJs = @converted
        @extract()
        @prepare()
        return @hasChanged = true
      else
        l.debug "No changes in compiled sourceCodeJs of module '#{@srcFilename}' " if l.deb 90
        return @hasChanged = false

  reset:->
    super
    delete @sourceCodeJs
    @resetModuleInfo()

  # init / clear stuff & create those on demand
  resetModuleInfo:->
    @flags = {}
#    delete @[dv] for dv in @AST_data
    @[dv] = [] for dv in @keys_depsAndVarsArrays
    delete @[dv] for dv in @keys_resolvedDependencies
    delete @parameters

  # keep a reference to our data, easy to init & export
  AST_data: [
    'AST_top', 'AST_body', 'AST_factoryBody'
    'AST_preDefineIIFENodes', 'AST_requireReplacementLiterals'
  ]

  keys_depsAndVarsArrays: [
    'ext_defineArrayDeps',  'ext_defineFactoryParams'
    'ext_requireDeps',      'ext_requireVars'
    'ext_asyncRequireDeps', 'ext_asyncFactoryParams'
  ]

  keys_resolvedDependencies: [
    'defineArrayDeps'
    'nodeDeps'
  ]

  # info for debuging / testing (empties are eliminated)
  info: ->
    info = {}
    for p in _.flatten [
      @keys_depsAndVarsArrays,
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

      if _B.isLike {type: 'Literal'}, astArrayDep
        arrayDep = new Dependency astArrayDep.value, @             # astArrayDep is { type: 'Literal', value: 'someString' }
        (@AST_requireReplacementLiterals or= []).push astArrayDep  # store it for quick replacements later
      else
        arrayDep = new Dependency (@toCode astArrayDep), @, true # untrusted = true

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
        requireDep = new Dependency src[prop].arguments[0].value, @
        # store literal of `require()`s needing replacement
        (@AST_requireReplacementLiterals or= []).push src[prop].arguments[0]

      else # require( non literal expression ) #@todo: warn for wrong signature
        #  signature of async `require([dep1, dep2], function(dep1, dep2){...})`
        if _B.isLike [{type: 'ArrayExpression'}, {type: 'FunctionExpression'}], src[prop].arguments
          args = src[prop].arguments
          @readArrayDepsAndVars args[0],        (@ext_asyncRequireDeps or= []),    # async require deps array, at pos 0
                                args[1].params, (@ext_asyncFactoryParams or= [])  # async factory function, at pos 1

        else
          requireDep = new Dependency (@toCode src[prop].arguments[0]), @, true

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

    null

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
      @AST_preDefineIIFENodes = []   # store all nodes preceding IIFEied define()
    else
      if isLikeCode '(function(){})()', @AST_top.body
        @AST_body = @AST_top.body[0].expression.callee.body.body
        @AST_preDefineIIFENodes = []   # store all nodes preceding IIFEied define()
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
             not isLikeCode(';', bodyNode) and
             (defines.length is 0) and @AST_preDefineIIFENodes # if no define found yet & were in IIFE
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

    # Store @parameters removing *reduntant* ones (those in excess of @ext_defineArrayDeps):
    # RequireJS doesn't like them if require is 1st param!
    @parameters = @ext_defineFactoryParams[0..@ext_defineArrayDeps.length-1]

    # add dummy params for deps without corresponding params
#    if (lenDiff = @ext_defineArrayDeps.length - @parameters.length) > 0
#      @parameters.push "__dummyParam#{pi}__" for pi in [1..lenDiff]

    # Our final' defineArrayDeps (& @nodeDeps) will eventually have -in this order-:
    #   - original ext_defineArrayDeps, each instanciated as a Dependency
    #   - all dependencies.exports.bundle, if template is not 'combined'
    #   - module injected dependencies
    #   - Add all deps in `require('dep')`, from @module.ext_requireDeps are added
    # @see adjust
    @defineArrayDeps = _.clone @ext_defineArrayDeps

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

    @nodeDeps = _.clone @defineArrayDeps # shallow clone
    @

  ###
  Produce final template information:

  - bundleRelative deps like `require('path/dep')` in factory, are replaced with their fileRelative counterpart

  - injecting dependencies?.exports?.bundle

  - add @ext_requireDeps to @defineArrayDeps (& perhaps @nodeDeps)

  @todo: decouple from build, use calculated (cached) properties, populated at convertWithTemplate(@build) step

  ###
  adjust: (@build)->
    l.debug "\n@adjust for '#{@srcFilename}'" if l.deb 70

    for newDep, oldDeps of (@bundle?.dependencies?.replace or {})
      @replaceDep oldDep, newDep for oldDep in oldDeps

    # replace each bundleRelative dep in require('string literal') calls
    # with the fileRelative path -that work everywhere- and remove 'node' fake pluging
    for dep in _.flatten [ @defineArrayDeps, @ext_requireDeps, @ext_asyncRequireDeps ] when dep and not dep.untrusted
      @replaceDep dep, dep # replaces all `bundleRelative` deps with their `fileRelative` in AST

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
    #  Even if there are no other arrayDependencie, we still add them all to prevent RequireJS scan @ runtime
    #  (# RequireJs disables runtime scan if even one dep exists in []).
    #  We dont add them only if _.isEmpty and `--scanAllow` and we dont have a `rootExports`
    addToArrayDependencies = (reqDep)=>
      if (reqDep.pluginName isnt 'node') and # 'node' is a fake plugin signaling nodejs-only executing modules.
        (reqDep.name(plugin:false) not in (@bundle?.dependencies?.node or [])) and
        (not _.any @defineArrayDeps, (dep)->dep.isEqual reqDep) # and not already there
          @defineArrayDeps.push reqDep
          @nodeDeps.push reqDep if @isAllNodeRequires

    if not (_.isEmpty(@defineArrayDeps) and @isScanAllow and not @flags.rootExports)
      addToArrayDependencies reqDep for reqDep in @ext_requireDeps
    @

  # inject [depVars] Dependencies to defineArrayDeps, nodeDeps
  # and their corresponding parameters (infered if not found)
  injectDeps: (depVars)->
    l.debug("#{@path}: injecting dependencies: ", depVars) if l.deb 40

    {dependenciesBindingsBlender} = require '../config/blendConfigs' # circular reference delayed loading
    return if _.isEmpty depVars = dependenciesBindingsBlender.blend depVars

    @bundle?.inferEmptyDepVars? depVars, "Infering empty depVars from injectDeps for '#{@path}'"
    for depName, varNames of depVars
      dep = new Dependency depName, @
      if not dep.isEqual @path
        for varName in varNames # add for all corresponding vars, BEFORE the deps not corresponding to params!
          if not (varName in @parameters)
            @defineArrayDeps.splice @parameters.length, 0, dep
            @nodeDeps.splice @parameters.length, 0, dep
            @parameters.push varName
            l.debug("#{@path}: injected dependency '#{depName}' as parameter '#{varName}'") if l.deb 70
          else
            l.warn("#{@path}: NOT injecting dependency '#{depName}' as parameter '#{varName}' cause it already exists.") #if l.deb 90
      else
        l.debug("#{@path}: NOT injecting dependency '#{depName}' on self'") if l.deb 50

    null


  # Replaces a Dependency with another dependency on the Module.
  # It makes the replacements on
  #
  #   * All Dependency instances on @keys_resolvedDependencies arrays
  #
  #   * All AST Literals in code, in deps array ['literal',...] or require('literal') calls,
  #     always leaving the fileRelative newDep string
  #
  # @param oldDep {Dependency|String} The old dependency, expressed either a Dependency instance
  #                                   or String (file or bundleRelative)
  #
  # @param newDep {Dependency|String|Undefined} The dependency to replace the old with.
  #        If its empty, it removes the oldDep from all keys_resolvedDependencies Arrays
  #       (BUT NOT THE AST)
  replaceDep: (oldDep, newDep)->
    if not (oldDep instanceof Dependency)
      if _.isString oldDep
        oldDep = new Dependency oldDep, @
      else
        l.er "Module.replaceDep: Wrong old dependency type '#{oldDep}' in module #{@path} - should be String|Dependency."
        throw new UError "Module.replaceDep: Wrong old dependency type '#{oldDep}' in module #{@path} - should be String|Dependency."

    if newDep
      if not (newDep instanceof Dependency)
        if _.isString newDep
          newDep = new Dependency newDep, @
        else
          throw new UError("Module.replaceDep: Wrong new dependency type '#{newDep}' in module #{@path} - should be String|Dependency|Undefined.")
    else
      removeArrayIdxs = []
    # both deps are Dependency instances now (if newDep exists)

    # find & replace (or remove) all matching deps in all keys_resolvedDependencies arrays (with Dependency instances)
    if oldDep isnt newDep # if oldDep IS newDep, no need to replace resolved deps array, only literals in AST code
      for rdArrayName in @keys_resolvedDependencies
        for dep, depIdx in (@[rdArrayName] or []) when dep.isEqual(oldDep)
          if newDep
            @[rdArrayName][depIdx] = newDep
            l.debug(80, "Module.replaceDep in '#{rdArrayName}', replaced '#{oldDep}' with '#{newDep}'.")
          else # mark idx for removal
            removeArrayIdxs.push {rdArrayName, depIdx}

      # actually remove found old deps
      if not newDep
        for rai in removeArrayIdxs by -1 # in reverse order so idxs stay meaningful
          l.debug(80, "Module.replaceDep in '#{rai.rdArrayName}', removing '#{@[rai.rdArrayName][rai.depIdx]}'.")
          @[rai.rdArrayName].splice rai.depIdx, 1

          # also remove from @parameters for defineArrayDeps
          if rai.rdArrayName is 'defineArrayDeps'
            @parameters.splice rai.depIdx, 1

    # replace dep literals in AST code (bundleRelative to fileRelative) OR warn if it was just removed
    for depLiteral in (@AST_requireReplacementLiterals or []) when (depLiteral?.value isnt newDep?.name?())
      if oldDep.isEqual new Dependency depLiteral.value, @
        if newDep
          l.debug(80, "Replacing AST literal '#{depLiteral.value}' with '#{newDep.name()}'")
          depLiteral.value = newDep.name()
        # else # this is wrong - the AST might be removed from the body, we dont know about it. To search is costly!
        # l.warn "Removed dependency '#{oldDep.name(relative:'bundle')}', but AST literal '#{depLiteral.value}' is still in the code!"

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
    for dep in _.flatten [ @defineArrayDeps, @ext_asyncRequireDeps ]
      if dep.type not in ['bundle', 'system']
        @bundle?.reporter.addReportData _B.okv(dep.type, dep.name relative:'bundle'), @path # build a `{'local':['lodash']}`

  # Actually converts the module to the target @build options.
  convertWithTemplate: (@build) -> #set @build 'temporarilly': options like scanAllow & noRootExports are needed to calc deps arrays
    l.verbose "Converting '#{@path}' with template = '#{@build.template.name}'"
    l.debug("'#{@path}' adjusted module.info() with keys_resolvedDependencies = \n",
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
    path: get:-> upath.trimExt @srcFilename if @srcFilename # filename (bundleRelative) without extension eg `models/PersonModel`

    factoryBody: get:->
      fb = @toCode @AST_factoryBody
      if @kind isnt 'AMD' then fb else fb[1..fb.length-2].trim()

    # 'body' / statements BEFORE define (coffeescript & family gencode `__extend`, `__slice` etc)
    'preDefineIIFEBody': get:-> @toCode @AST_preDefineIIFENodes if @AST_preDefineIIFENodes

  toCode: (astCode=@AST_body)->
    toCode astCode, @codegenOptions

module.exports = Module

