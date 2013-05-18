_ = require 'lodash'
_B = require 'uberscore'

l = new _B.Logger 'urequire/UModule'

upath = require '../paths/upath'
ModuleGeneratorTemplates = require '../templates/ModuleGeneratorTemplates'
ModuleManipulator = require "../moduleManipulation/ModuleManipulator"
Dependency = require "../Dependency"

module.exports =

class UModule
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor:->@_constructor.apply @, arguments

  ###
  @param {Object} bundle The Bundle where this UModule belongs
  @param {String} filename of module, eg 'models/PersonModel.coffee'
  @param {String} sourceCode, AS IS (might be coffee, coco, livescript, typescript etc)
  ###
  _constructor: (@bundle, @filename, @sourceCode)->
    # set '@sourceCode; triggers everything

  ### @return {String} the filename extension of this module, eg `.js` or `.coffee`###
  @property extname: get:-> upath.extname @filename

  ### @return {String} filename, as read from filesystem (i.e bundleRelative) without extension eg `models/PersonModel` ###
  @property modulePath: get:-> upath.trimExt @filename

  ###
    Module sourceCode, AS IS (might be coffee, coco, livescript, typescript etc)

    Everytime it is set, if its new sourceCode it adjusts moduleInfo, resetting all deps.

    It does not actually convert, as it waits for instructions from the bundle
    But the module is ready to provide & alter deps information (eg add some injected Dependencies)
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
          l.debug("Compiling coffeescript '#{@filename}'") if l.deb 90
          cs = require 'coffee-script'
          try
            @_sourceCodeJs = cs.compile @sourceCode, bare:true
          catch err
            err.uRequire = "Coffeescript compilation error:\n"
            l.err err.uRequire, err
            throw err

    return @_sourceCodeJs

  ###
  Extract AMD/module information for this module.
  Factory bundleRelative deps like `require('path/dep')` are replaced with their fileRelative counterpart
  Extracted module info augments this instance.
  ###
  adjustModuleInfo: ->
    # reset info holders
#    @depenenciesTypes = {} # eg `globals:{'lodash':['file1.js', 'file2.js']}, externals:{'../dep':[..]}` etc
    @isConvertible = false
    @convertedJs = ''

    moduleManipulator = new ModuleManipulator @sourceCodeJs, beautify:true
    @moduleInfo = moduleManipulator.extractModuleInfo() # keeping original @moduleInfo

    if _.isEmpty @moduleInfo
      l.warn "Not AMD/nodejs module '#{@filename}', copying as-is."
    else if @moduleInfo.moduleType is 'UMD'
        l.warn "Already UMD module '#{@filename}', copying as-is."
    else if @moduleInfo.untrustedArrayDependencies
        l.err "Module '#{@filename}', has untrusted deps #{d for d in @moduleInfo.untrustedArrayDependencies}: copying as-is."
    else
      @isConvertible = true
      @moduleInfo.parameters or= []        #default
      @moduleInfo.arrayDependencies or= [] #default

      if _.isEmpty @moduleInfo.arrayDependencies
        @moduleInfo.parameters = []
      else # remove *reduntant parameters* (those in excess of the arrayDeps), requireJS doesn't like them if require is 1st param!
        @moduleInfo.parameters = @moduleInfo.parameters[0..@moduleInfo.arrayDependencies.length-1]

      # 'require' & associates are *fixed* in UMD template (if needed), so remove 'require'
      for pd in [@moduleInfo.parameters, @moduleInfo.arrayDependencies]
        pd.shift() if pd[0] is 'require'

      requireReplacements = {} # final replacements for all require() calls.

      # Go throught all original deps & resolve their fileRelative counterpart.
      [ @arrayDeps  # Store resolvedDeps as res'DepType'
        @requireDeps
        @asyncDeps ] = for strDepsArray in [ # @todo:2 why do we need to replaceAsynchRequires ?
           @moduleInfo.arrayDependencies
           @moduleInfo.requireDependencies
           @moduleInfo.asyncDependencies
          ]
            deps = []
            for strDep in (strDepsArray || [])
              deps.push dep = new Dependency strDep, @filename, @bundle.filenames
              requireReplacements[strDep] = dep.name()

              # add some reporting
              if @bundle.reporter
                @bundle.reporter.addReportData _B.okv({}, # build a `{'global':'lodash':['_']}`
                  dep.type, [dep.name()]
                ), @modulePath

            deps
      # replace 'require()' calls using requireReplacements
      @moduleInfo.factoryBody = moduleManipulator.getFactoryWithReplacedRequires requireReplacements

      # add remaining dependencies (eg 'untrustedRequireDependencies') to DependenciesReport
      if @bundle.reporter
        for repData in [ (_.pick @moduleInfo, @bundle.reporter.reportedDepTypes) ]
          @bundle.reporter.addReportData repData, @modulePath

      # our final 'templateInfo' information follows
      @parameters = _.clone @moduleInfo.parameters
      @nodeDeps = _.clone @arrayDeps

      _.defaults @, @moduleInfo
      @
  ###
  Actually converts the module to the target @build options.
  ###
  convert: (@build) -> #set @build 'temporarilly': options like scanAllow & noRootExports are needed to calc deps arrays
    if @isConvertible
      l.debug("Converting module '#{@modulePath}'") if l.deb 30

      # inject bundleExports Dependencies information to arrayDeps, nodeDeps & parameters
      if not _.isEmpty (bundleExports = @bundle?.dependencies?.bundleExports)
        l.debug("#{@modulePath}: injecting dependencies \n", @bundle.dependencies.bundleExports) if l.deb 30

        for depName, varNames of bundleExports
          if _.isEmpty varNames
            # attempt to read from bundle & store found varNames at @bundle.dependencies.bundleExports
            varNames = bundleExports[depName] = @bundle.getDepsVars(depName:depName)[depName]
            l.debug("""
              #{@modulePath}: dependency '#{depName}' had no corresponding parameters/variable names to bind with.
              An attempt to infer varNames from bundle: """, varNames) if l.deb 40

          if _.isEmpty varNames # still empty, throw error. #todo: bail out on globals with no vars ??
            err = uRequire: """
              Error converting bundle named '#{@bundle.bundleName}' in '#{@bundle.bundlePath}'.

              No variable names can be identified for bundleExports dependency '#{depName}'.

              These variable names are used to :
                - inject the dependency into each module
                - grab the dependency from the global object, when running as <script>.

              Remedy:

              You should add it at uRequireConfig 'bundle.dependencies.bundleExports' as a
                ```
                  bundleExports: {
                    '#{depName}': 'VARIABLE_IT_BINDS_WITH',
                    ...
                    jquery: ['$', 'jQuery'],
                    backbone: ['Backbone']
                  }
                ```
              instead of the simpler
                ```
                  bundleExports: [ '#{depName}', 'jquery', 'backbone' ]
                ```

              Alternativelly, pick one medicine :
                - define at least one module that has this dependency + variable binding, using AMD instead of commonJs format, and uRequire will find it!
                - declare it in the above format, but in `bundle.dependencies.variableNames` and uRequre will pick it from there!
                - use an `rjs.shim`, and uRequire will pick it from there (@todo: NOT IMPLEMENTED YET!)
            """
            l.err err.uRequire
            throw err
          else
            for varName in varNames # add for all corresponding vars
              if not (varName in @parameters)
                d = new Dependency depName, @filename, @bundle.filenames #its cheap!
                @arrayDeps.push d
                @nodeDeps.push d
                @parameters.push varName
                l.debug("#{@modulePath}: injected dependency '#{depName}' as parameter '#{varName}'") if l.deb 50
              else
                l.debug("#{@modulePath}: Not injecting dependency '#{depName}' as parameter '#{varName}' cause it already exists.") if l.deb 10

      # @todo:3 also add rootExports ?

      # Add all `require('dep')` calls
      # Execution stucks on require('dep') if its not loaded (i.e not present in arrayDependencies).
      # see https://github.com/jrburke/requirejs/issues/467
      #
      # So load ALL require('dep') fileRelative deps have to be added to the arrayDepsendencies on AMD.
      #
      # Even if there are no other arrayDependencie, we still add them all to prevent RequireJS scan @ runtime
      # (# RequireJs disables runtime scan if even one dep exists in []).
      #
      # We allow them only if `--scanAllow` or if we have a `rootExports`
      if not (_.isEmpty(@arrayDeps) and @build?.scanAllow and not @moduleInfo.rootExports)
        for reqDep in @requireDeps
          if reqDep.pluginName isnt 'node' and                # 'node' is a fake plugin: signaling nodejs-only executing modules. Hence dont add to arrayDeps!
            not (_.any @arrayDeps, (dep)->dep.isEqual reqDep) and # not already there
            not (reqDep.name() in (@bundle.dependencies?.noWeb or []))
              @arrayDeps.push reqDep
              @nodeDeps.push reqDep if @build?.allNodeRequires

      moduleTemplate = new ModuleGeneratorTemplates ti = @templateInfo
      l.verbose "Converting '#{@modulePath}' with template = '#{@build.template.name}', templateInfo = \n", _.omit(ti, ['factoryBody', 'webRootMap', ])

      @convertedJs = moduleTemplate[@build.template.name]() # @todo: pass template, not its name
    else
      @convertedJs = @sourceCodeJs

    @



  ###
  Returns all deps in this module along with their corresponding parameters (variable names)

  Note: currently, only AMD-modules provide us with the variable-binding of dependencies!

  @param {Object} q optional query with two optional fields : depType & depName
  @return {Object}
      {
        jquery: ['$', 'jQuery']
        lodash: ['_']
        'models/person': ['pm']
      }
  ###
  getDepsVars: (q={})->
    depsVars = {}
    if @isConvertible
      for dep, idx in @arrayDeps when (
        ((not q.depType) or (q.depType is dep.type)) and
        ((not q.depName) or (dep.isEqual q.depName))
      )
          dv = (depsVars[dep.name(relativeType:'bundle')] or= [])
          # store the variable(s) associated with dep
          if @parameters[idx] and not (@parameters[idx] in dv )
            dv.push @parameters[idx] # if there is a var, add once

      depsVars
    else {}

  ### for reference (we could have passed UModule instance it self :-) ###
  @property templateInfo: get: -> _B.go {
      @moduleName
      @moduleType
      @modulePath
      webRootMap: @bundle.webRootMap || '.'
      arrayDependencies: (d.name() for d in @arrayDeps)
      nodeDependencies: (d.name() for d in @nodeDeps)
      @parameters
      @factoryBody

      rootExports: do ()=>
                    result = if @build.noRootExports
                      undefined
                    else
                      if @rootExports then @rootExports else @rootExport # backwards compatible with rootExport :-)
                    if result
                      _B.arrayize result


      noConflict: if @build.noRootExports then undefined else @noConflict
  }, fltr: (v)->not _.isUndefined v

### Debug information ###
if l.deb >= 90
  YADC = require('YouAreDaChef').YouAreDaChef

  YADC(UModule)
    .before /_constructor/, (match, bundle, filename)->
      l.debug("Before '#{match}' with filename = '#{filename}'")



