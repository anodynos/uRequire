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
          l.verbose 'Compiling coffeescript:', @filename
          cs = require 'coffee-script'
          try
            @_sourceCodeJs = cs.compile @sourceCode, bare:true
          catch err
            err.uRequire = "Coffeescript compilation error:\n"
            l.err err.uRequire, err
            throw err

    return @_sourceCodeJs

  convert: (build) ->
    l.debug 10, "Converting uModule #{@modulePath} with template: #{build.template}"
    if @isConvertible
      ti = @templateInfo

      if build.noRootExports
        delete ti.rootExports
      else
        ti.rootExports = ti.rootExport if ti.rootExport and not ti.rootExports #backwards compatible:-)
        ti.rootExports = _B.arrayize ti.rootExports

      @convertedJs = (new ModuleGeneratorTemplates ti)[build.template]()
    else
      @convertedJs = @sourceCodeJs

  reportDeps: ->
    if @bundle.reporter
      for repData in [ (_.pick @depenenciesTypes, @bundle.reporter.interestingDepTypes) ]
        @bundle.reporter.addReportData repData, @filename

  ###
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
            d = new Dependency d, @filename, @bundle.filenames # @todo: store these elsewhere ?

            if d.isGlobal() # store the variable(s) associated with it (if there is one & not exists!)
              gdv = (@_globalDepsVars[d.resourceName] or= [])
              gdv.push @parameters[idx] if @parameters[idx] and not (@parameters[idx] in gdv )

        @_globalDepsVars
      else {}


  # Extract AMD/module information fpr this module, and augment this instance.
  adjustModuleInfo: ->
    # reset info holders
    @depenenciesTypes = {} # eg `globals:{'lodash':['file1.js', 'file2.js']}, externals:{'../dep':[..]}` etc
    @_globalDepsVars = {} # store { jquery: ['$', 'jQuery'] }
    @isConvertible = false
    @convertedJs = ''

    # @todo: break into properties, keeping originals in @moduleInfo,
    #        calculating @arrayDependencies etc dynamically
    #         Therefore dependencies can be added at ease!
    moduleManipulator = new ModuleManipulator @sourceCodeJs, beautify:true
    mi = moduleManipulator.extractModuleInfo()

    if _.isEmpty mi
      l.warn "Not AMD/nodejs module '#{@filename}', copying as-is."
    else if mi.moduleType is 'UMD'
        l.warn "Already UMD module '#{@filename}', copying as-is."
    else if mi.untrustedArrayDependencies
        l.err "Module '#{@filename}', has untrusted deps #{d for d in mi.untrustedDependencies}: copying as-is."
    else
      @isConvertible = true
      mi.parameters ?= [] #default
      mi.arrayDependencies ?= [] #default

      # remove *reduntant parameters* (those in excess of the arrayDeps),
      # requireJS doesn't like them if require is 1st param!
      if _.isEmpty mi.arrayDependencies
        mi.parameters = []
      else
        mi.parameters = mi.parameters[0..mi.arrayDependencies.length-1]

      # 'require' & associates are *fixed* in UMD template (if needed), so remove 'require'
      for pd in [mi.parameters, mi.arrayDependencies]
        pd.shift() if pd[0] is 'require'

      requireReplacements = {} # final replacements for all require() calls.

      # Go throught all original deps & resolve their fileRelative counterpart.
      # resolvedDeps stored as a <code>Dependency<code> object
      [ arrayDeps      # Store resolvedDeps as res'DepType'
        requireDeps
        asyncDeps ] = for strDepsArray in [ # @todo: do we need to replaceAsynchRequires ?
           mi.arrayDependencies
           mi.requireDependencies
           mi.asyncDependencies
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
      mi.factoryBody = moduleManipulator.getFactoryWithReplacedRequires requireReplacements

      # load ALL require('dep') fileRelative deps on AMD to prevent scan @ runtime.
      # If there's no deps AND we have --scanAllow, ommit from adding them (unless we have a rootExports)
      # RequireJs disables runtime scan if even one dep exists in [].
      # Execution stucks on require('dep') if its not loaded (i.e not present in arrayDeps).
      # see https://github.com/jrburke/requirejs/issues/467

      mi.arrayDependencies = (d.toString() for d in arrayDeps)
      if not (_.isEmpty(mi.arrayDependencies) and @bundle.scanAllow and not mi.rootExports)
        for reqDep in requireDeps
          if reqDep.pluginName isnt 'node' and # 'node' is a fake plugin,  signaling nodejs-only executing modules. hence dont add to arrayDeps!
            not (reqDep.toString() in mi.arrayDependencies)
              mi.arrayDependencies.push reqDep.toString()

      mi.nodeDependencies = if @bundle.allNodeRequires then mi.arrayDependencies else (d.name() for d in arrayDeps)

      @webRootMap = @bundle.webRootMap || '.'

      _.extend @, mi

      @reportDeps()

  ### for reference (we could have passed UModule instance it self :-) ###
  @property templateInfo: get: -> _B.go { # @todo: report coffeescript problem: `class A \n prop: {@prop1, prop2}` gives `prop1:A.prop1, prop2:A.prop2` instead of
      @moduleName
      @moduleType
      @modulePath
      @webRootMap
      @arrayDependencies
      @nodeDependencies
      @parameters
      @factoryBody
      @rootExports
      @noConflict
  }, fltr: (v)->not _.isUndefined v

  ###
    @param { Object | []<String> } dependencyVariables see `bundle.dependencies.bundle`

    `['dep1', 'dep2']`

      or

    ```
    {
      'underscore': '_'
      'jquery': ["$", "jQuery"]
      'models/PersonModel': ['persons', 'personsModel']
    }
    ```
    These dependencies are added to this module, on all dep arrays + parameters

  ###
  addDependencies: (dependencyVariables)->
    @nodeDependencies = @arrayDependencies # we must have the same deps
                                           # @TODO:CRITICAL must find where arrayDeps have excessive deps (to params),
                                           # just for requireJs's sake, and insert them there!
    addDepVar = (dep, varName)-> # todo: NOT IMPLEMTED
      v.log "ADDING Dependency to module #{@modulePath} : ", dep, varName
      #@arrayDependencies_BEFORE_ADDING_REQUIRES.push dep
      #@parameters_IN_SYNC_WITH_ABOVE.push varName

    if _.isArray dependencyVariables
      depsVars = _.extend @bundle.globalDepsVars, @bundle.dependencies.variableNames # @todo: merge arrays, instead of overwritting
      for dep in dependencyVariables
        for varName in depsVars[dep]
          addDepVar dep, varName

    else
      if _.isObject dependencyVariables
        for dep, variables of dependencyVariables
          for varName in variables
            addDepVar dep, varName

## some debugging code

# @todo:
#   move debug to seperate file - (that's what AOP cross cutting concerns) and YADC 'em ny if debuging is enabled.
#   implement most verbose stuff here!
#   YADC todos :
#     Add generic debuggin' / loging
#
#
#
#(require('YouAreDaChef').YouAreDaChef UModule)

#  .after '_constructor', ()->
#    l.debug 100, '\n######### UModule _constructor finished', {
#      @modulePath  # bundleRelative : eg 'models/PersonModel'
#      @bundle.filenames # todo: 'bundle' where it belongs
#      @source      # String of source eg coffee (or .js) - used only to compare for file changes
#      @sourceCodeJs    # String of source code in js
#      @bundle.options     # the options used for the compilation #@todo : make @bundle.options a global ? :-)
#      @bundle.reporter    # @todo refactor/globalize!
#    }

#  .before /.*/, (match, args...)->
#    console.log "#### before: #{match}", args

#  .before 'convert', ->
#    l.verbose 'Converting with templateInfo = \n', (
#        _B.go @templateInfo,
#          fltr: (v, k)-> not _B.inFilters k, ['factoryBody', /webRootMap/]
#      )




