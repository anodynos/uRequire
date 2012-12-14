_ = require 'lodash'
_B = require 'uberscore'
upath = require '../paths/upath'

ModuleGeneratorTemplates = require '../templates/ModuleGeneratorTemplates'
ModuleManipulator = require "../moduleManipulation/ModuleManipulator"
Dependency = require "../Dependency"
Logger = require '../utils/Logger'
l = new Logger 'UModule'

module.exports =

class UModule
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor:->@_constructor.apply @, arguments

  _constructor: (
    @bundle      # `Bundle` where it belongs
    @filename    # full filename of module, eg 'models/PersonModel.coffee'
    @sourceCode # Module sourceCode, AS IS (might be coffee, coco, livescript, typescript etc)
  )->
    # @adjustModuleInfo() is called on sourceCode.set

  ### @return {String} the filename extension of this module, eg `.js` or `.coffee`###
  @property extname: get:-> upath.extname @filename

  ### @return {String} filename, as read from filesystem (i.e bundleRelative) without extension eg `models/PersonModel` ###
  @property modulePath: get:-> upath.trimExt @filename

  ###
    Module sourceCode, AS IS (might be coffee, coco, livescript, typescript etc)

    Everytime it is set, it checks to see if new & adjusts the module information (require's etc).

    It does not convert, as it waits for instructions from the bundle (eg add some injected Dependencies etc)
  ###
  @property sourceCode:
    enumerable: false
    get: -> @_sourceCode
    set: (src)->
      if src isnt @_sourceCode
        @_sourceCode = src
        @_sourceCodeJs = false # mark for compilation to Js might be needed
        @adjustModuleInfo()

  ### Module source code, compiled to JavaScript if it aint already so ###
  @property sourceCodeJs: get: ->
    if not @_sourceCodeJs
      if @extname is '.js'
        @_sourceCodeJs = @sourceCode
      else # compile to coffee, iced, coco etc
        if @extname is '.coffee'
          l.debug 95, "Compiling coffeescript '#{@filename}'"
          cs = require 'coffee-script'
          try
            @_sourceCodeJs = cs.compile @sourceCode, bare:true
          catch err
            err.uRequire = "Coffeescript compilation error:\n"
            l.err err.uRequire, err
            throw err

    return @_sourceCodeJs

  convert: (@build) -> #set @build temporarilly: options like scanAllow & noRootExports are needed to calc deps arrays
    if @isConvertible

      # inject *Dependency Injection* information to arrayDependencies & parameters
      if bundleExports = @bundle?.dependencies?.bundleExports # @todo:5 add a 'see link to bundleExports fixer'

        # fix bundleExports format once and for all!
        if _.isString bundleExports then bundleExports = [ bundleExports ]

        if _.isArray bundleExports
          b = {}
          _B.go bundleExports, grab:(v)->b[v]=[]
          @bundle.dependencies.bundleExports = bundleExports = b
          l.debug 30, "fixed format of '@bundle.dependencies.bundleExports' = \n", bundleExports

        for depName, varNames of bundleExports
          varNames = _B.arrayize varNames
          if _.isEmpty varNames
            varNames = @bundle.globalDepsVars[depName]

          if _.isEmpty varNames # @todo : throw error. Also, where else do we need to bail out on globals with no vars ??
            l.err """No variables can be identified for global dependency '#{depName}'.
                     You should add it at 'bundle.dependencies.bundleExports' or 'bundle.dependencies.variableNames'"""
          else
            for varName in varNames
              if not (varName in @parameters) # add for all corresponding vars
                @arrayDependencies.push depName
                @nodeDependencies.push depName
                @parameters.push varName
                l.debug 80, "#{@modulePath}: injected dependency '#{depName}' as parameter '#{varName}'"

      # Execution stucks on require('dep') if its not loaded (i.e not present in arrayDependencies).
      # see https://github.com/jrburke/requirejs/issues/467
      #
      # So load ALL require('dep') fileRelative deps on AMD.

      # Even if there are no other arrayDependenciesm, we still add them all to prevent RequireJS scan @ runtime
      # (# RequireJs disables runtime scan if even one dep exists in []).
      # We allow them only if `--scanAllow` or if we have a `rootExports`

      if not (_.isEmpty(@arrayDependencies) and @build?.scanAllow and not @moduleInfo.rootExports)
        for reqDep in @requireDeps
          if reqDep.pluginName isnt 'node' and # 'node' is a fake plugin: signaling nodejs-only executing modules. Hence dont add to arrayDeps!
            not (reqDep.toString() in @arrayDependencies)
              @arrayDependencies.push reqDep.toString()
              @nodeDependencies.push reqDep.toString() if @build?.allNodeRequires

      ti = @templateInfo

      if build?.noRootExports
        delete ti.rootExports
      else
        ti.rootExports = ti.rootExport if ti.rootExport and not ti.rootExports #backwards compatible:-)
        ti.rootExports = _B.arrayize ti.rootExports if ti.rootExports

      l.debug 10, "Converting uModule #{@modulePath} with template: #{build.template}"
      @convertedJs = (new ModuleGeneratorTemplates ti)[build.template]()
    else
      @convertedJs = @sourceCodeJs

  reportDeps: ->
    if @bundle.reporter
      for repData in [ (_.pick @depenenciesTypes, @bundle.reporter.interestingDepTypes) ]
        @bundle.reporter.addReportData repData, @filename

  ###
  Finds all `global`s in this module and stores their parameter/variable names

  @return {Object} It creates, caches and returns
      @_globalDepsVars =
        jquery: ['$', 'jQuery']
        lodash: ['_']
  ###
  @property globalDepsVars:
    get: ->
      if @isConvertible
        if _.isEmpty @_globalDepsVars # reset at @adjustModuleInfo()
          for d, idx in @arrayDependencies
            d = new Dependency d, @filename, @bundle.filenames # @todo:3 store these elsewhere ?
            if d.isGlobal() # store the variable(s) associated with it (if there is one & not exists!)
              gdv = (@_globalDepsVars[d.resourceName] or= [])
              gdv.push @parameters[idx] if @parameters[idx] and not (@parameters[idx] in gdv )

        @_globalDepsVars
      else {}


  # Extract AMD/module information fpr this module, and augment this instance.
  # This following code is kinda weird to break into smaller pieces
  # @todo:4 refactor / simpify it / test it
  adjustModuleInfo: ->
    # reset info holders
    @depenenciesTypes = {} # eg `globals:{'lodash':['file1.js', 'file2.js']}, externals:{'../dep':[..]}` etc
    @_globalDepsVars = {} # store { jquery: ['$', 'jQuery'] }
    @isConvertible = false
    @convertedJs = ''


    moduleManipulator = new ModuleManipulator @sourceCodeJs, beautify:true
    @moduleInfo = moduleManipulator.extractModuleInfo() # keeping original @moduleInfo

    if _.isEmpty @moduleInfo
      l.warn "Not AMD/nodejs module '#{@filename}', copying as-is."
    else if @moduleInfo.moduleType is 'UMD'
        l.warn "Already UMD module '#{@filename}', copying as-is."
    else if @moduleInfo.untrustedArrayDependencies
        l.err "Module '#{@filename}', has untrusted deps #{d for d in @moduleInfo.untrustedDependencies}: copying as-is."
    else
      @isConvertible = true
      @moduleInfo.parameters or= [] #default
      @moduleInfo.arrayDependencies or= [] #default

      # remove *reduntant parameters* (those in excess of the arrayDeps),
      # requireJS doesn't like them if require is 1st param!
      if _.isEmpty @moduleInfo.arrayDependencies
        @moduleInfo.parameters = []
      else
        @moduleInfo.parameters = @moduleInfo.parameters[0..@moduleInfo.arrayDependencies.length-1]

      # 'require' & associates are *fixed* in UMD template (if needed), so remove 'require'
      for pd in [@moduleInfo.parameters, @moduleInfo.arrayDependencies]
        pd.shift() if pd[0] is 'require'

      requireReplacements = {} # final replacements for all require() calls.

      # Go throught all original deps & resolve their fileRelative counterpart.
      # resolvedDeps stored as a <code>Dependency<code> object
      [ @arrayDeps      # Store resolvedDeps as res'DepType'
        @requireDeps
        @asyncDeps ] = for strDepsArray in [ # @todo:2 do we need to replaceAsynchRequires ?
           @moduleInfo.arrayDependencies
           @moduleInfo.requireDependencies
           @moduleInfo.asyncDependencies
          ]
            deps = []

            for strDep in (strDepsArray || [])
              dep = new Dependency strDep, @filename, @bundle.filenames
              deps.push dep
              requireReplacements[strDep] = dep.name()

              if dep.type # for reporting!
                (@depenenciesTypes[dep.type] or= []).push dep.resourceName

            deps

      # replace 'require()' calls using requireReplacements
      @moduleInfo.factoryBody = moduleManipulator.getFactoryWithReplacedRequires requireReplacements

      # our final 'templateInfo' information follows
      @parameters = _.clone @moduleInfo.parameters
      @arrayDependencies = (d.toString() for d in @arrayDeps)
      @nodeDependencies = (d.name() for d in @arrayDeps)

      _.defaults @, @moduleInfo
      @reportDeps()



  ### for reference (we could have passed UModule instance it self :-) ###
  @property templateInfo: get: -> _B.go {
      @moduleName
      @moduleType
      @modulePath
      webRootMap: @bundle.webRootMap || '.'
      @arrayDependencies
      @nodeDependencies
      @parameters
      @factoryBody
      rootExports: if @build.noRootExports then undefined else @rootExports
      noConflict: if @build.noRootExports then undefined else @noConflict
  }, fltr: (v)->not _.isUndefined v

  # @todo:2 report coffeescript problem:
  # ```
  # class A
  #   prop: {@prop1, prop2}
  # ```
  # gives
  # ```
  # prop1:A.prop1,
  # prop2:A.prop2
  #```


### Debug information ###

if Logger::debug.level > 90
  YADC = require('YouAreDaChef').YouAreDaChef

  YADC(UModule)
    .before /_constructor/, (match, bundle, filename)->
      l.debug "Before '#{match}' with 'filename' = '#{filename}', bundle = \n", _.pick(bundle, [])



