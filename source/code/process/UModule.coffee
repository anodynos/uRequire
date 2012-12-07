_ = require 'lodash'
_B = require 'uberscore'
upath = require '../paths/upath'

ModuleGeneratorTemplates = require '../templates/ModuleGeneratorTemplates'
ModuleManipulator = require "../moduleManipulation/ModuleManipulator"
Dependency = require "../Dependency"
l = require '../utils/logger'

module.exports =
class UModule
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p

  constructor: ->
    @_constructor.apply @, arguments

  _constructor: (
    @filename    # the full filename of this module, eg 'models/PersonModel.coffee'
    @_sourceCode # String of source code eg coffee (or .js)
    @bundle      # todo: 'bundle' where it belongs
  )->
    @adjustModuleInfo()

  ### @return {String} the filename extension of this module, eg `.js` or `.coffee`###
  @property extname:
    get:-> upath.extname @filename

  ### @return {String} filename, as read from filesystem (i.e bundleRelative) without extension eg `models/PersonModel` ###
  @property modulePath:
    get:-> upath.trimExt(@filename)

  ###
    Module sourceCode, AS IS (might be coffee, coco, livescript, typescript etc)
    Everytime it is set, it checks to see if new & adjusts the module information (require's etc).

    It does not convert, as it wait for instructions from the bundle (eg add some injected Dependencies etc)
  ###
  @property sourceCode:
    enumerable: false
    get: -> @_sourceCode
    set: (src)->
      if src isnt @_sourceCode
        @_sourceCode = src
        @_sourceCodeJs = ''
        @adjustModuleInfo()

  ### Module source code, in Js ###
  @property sourceCodeJs: get: ->
    if not @_sourceCodeJs
      if @extname is '.js'
        @_sourceCodeJs = @_sourceCode
      else # compile to coffee, iced, coco etc
        if @extname is '.coffee'
          l.verbose 'Compiling coffeescript:', @filename
          cs = require 'coffee-script'
          try
            @_sourceCodeJs = cs.compile @sourceCode, bare:true
          catch err
            err.uRequire = "Coffeescript compilation error:\n"
            l.err err.uRequire, err
            process.exit(1) if not @bundle.options.Continue

    return @_sourceCodeJs

  convert: (template = @bundle.options.template) ->
    if @isConvertible
      @convertedJs = (new ModuleGeneratorTemplates @templateInfo)[template]()
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
            d = new Dependency d, @filename, @bundle.filenames

            if d.isGlobal() # store the variable(s) associated with it (if there is one & not exists!)
              gdv = (@_globalDepsVars[d.resourceName] or= [])
              gdv.push @parameters[idx] if @parameters[idx] and not (@parameters[idx] in gdv )

        @_globalDepsVars
      else {}


  adjustModuleInfo: ->
    # reset info holders
    @depenenciesTypes = {} # eg `globals:{'lodash':['file1.js', 'file2.js']}, externals:{'../dep':[..]}` etc
    @_globalDepsVars = {} # store { jquery: ['$', 'jQuery'] }
    @isConvertible = false
    @convertedJs = ''

    moduleManipulator = new ModuleManipulator @sourceCodeJs, beautify:true
    mi = moduleManipulator.extractModuleInfo()

    if _.isEmpty mi
      l.warn "Not AMD/node module '#{@filename}', copying as-is."
    else if mi.moduleType is 'UMD'
        l.warn "Already UMD module '#{@filename}', copying as-is."
    else if mi.untrustedArrayDependencies
        l.err "Module '#{@filename}', has untrusted deps #{d for d in mi.untrustedDependencies}: copying as-is."
    else
      @isConvertible = true
      mi.parameters ?= [] #default
      mi.arrayDependencies ?= [] #default

      if @bundle.options.noExport
        delete mi.rootExports
      else
        mi.rootExports = mi.rootExport if mi.rootExport #backwards compatible:-)
        if mi.rootExports
          mi.rootExports = [mi.rootExports] if not _.isArray mi.rootExports

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
      if not (_.isEmpty(mi.arrayDependencies) and @bundle.options.scanAllow and not mi.rootExports)
        for reqDep in requireDeps
          if reqDep.pluginName isnt 'node' and # 'node' is a fake plugin,  signaling nodejs-only executing modules. hence dont add to arrayDeps!
            not (reqDep.toString() in mi.arrayDependencies)
              mi.arrayDependencies.push reqDep.toString()

      mi.nodeDependencies = if @bundle.options.allNodeRequires then mi.arrayDependencies else (d.name() for d in arrayDeps)

      @webRootMap = @bundle.options.webRootMap || '.'
      _.extend @, mi

      @reportDeps()

  ### simply for reference (we could have passed UModule instance it self :-) ###
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



## some debugging code

# @todo:
#   move debug to seperate file - (that's what AOP cross cutting concerns) and YADC 'em ny if debuging is enabled.
#   implement most verbose stuff here!
#   YADC todos :
#     Add generic debuggin' / loging
#
#
#
(require('YouAreDaChef').YouAreDaChef UModule)

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

  .before 'convert', ->
    l.verbose 'Converting with templateInfo = \n', (
        _B.go @templateInfo,
          fltr: (v, k)-> not _B.inFilters k, ['factoryBody', /webRootMap/]
      )




