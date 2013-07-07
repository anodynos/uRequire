# externals
_ = require 'lodash'
_B = require 'uberscore'
l = new _B.Logger 'urequire/UModule'
fs = require 'fs'

# uRequire
upath = require '../paths/upath'
ModuleGeneratorTemplates = require '../templates/ModuleGeneratorTemplates'
ModuleManipulator = require "../moduleManipulation/ModuleManipulator"
UResource = require './UResource'
Dependency = require "../Dependency"
UError = require '../utils/UError'

# Represents a Javascript module
class UModule extends UResource
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p ;null

  @property modulePath: get:-> upath.trimExt @filename  # filename (bundleRelative) without extension eg `models/PersonModel`

  ###
    Check if `super` in UResource has spotted changes and thus has a possibly changed @converted (javascript code)
    & call `@adjustModuleInfo()` if so.

    It does not actually convert to any template, as it waits for instructions from the bundle

    But the module can provide deps information (eg to inject Dependencies etc)
  ###
  refresh: ->
    if super
      if @sourceCodeJs isnt @converted # @converted is produced by UResource's refresh
        @sourceCodeJs = @converted
        @adjustModuleInfo()
        return @hasChanged = true
      else
        l.debug "No changes in sourceCodeJs of module '#{@dstFilename}' " if l.deb 90

    return @hasChanged = false # only when written

  reset:-> super; delete @sourceCodeJs

  ###
  Extract AMD/module information for this module.
  Factory bundleRelative deps like `require('path/dep')` are replaced with their fileRelative counterpart
  Extracted module info augments this instance.
  ###
  adjustModuleInfo: ->
    # reset info holders
#    @depenenciesTypes = {} # eg `globals:{'lodash':['file1.js', 'file2.js']}, externals:{'../dep':[..]}` etc
    l.debug "adjustModuleInfo for '#{@dstFilename}'" if l.deb 70

    @moduleManipulator = new ModuleManipulator @sourceCodeJs, beautify:true
    @moduleInfo = @moduleManipulator.extractModuleInfo() # keeping original @moduleInfo

    if _.isEmpty @moduleInfo
      l.warn "Not AMD/nodejs module '#{@filename}', copying as-is."
    else if @moduleInfo.moduleType is 'UMD'
        l.warn "Already UMD module '#{@filename}', copying as-is."
    else if @moduleInfo.untrustedArrayDeps
        l.err "Module '#{@filename}', has untrusted deps #{d for d in @moduleInfo.untrustedArrayDeps}: copying as-is."
    else
      @isConvertible = true
      @moduleInfo.parameters or= []        #default
      @moduleInfo.arrayDeps or= [] #default

      if _.isEmpty @moduleInfo.arrayDeps
        @moduleInfo.parameters = []
      else
        # remove *reduntant parameters* (those in excess of the arrayDependencies):
        # useless & also requireJS doesn't like them if require is 1st param!
        @moduleInfo.parameters = @moduleInfo.parameters[0..@moduleInfo.arrayDeps.length-1]

      # 'require' & associates are *fixed* in UMD template (if needed), so remove 'require'
      for pd in [@moduleInfo.parameters, @moduleInfo.arrayDeps]
        pd.shift() if pd[0] is 'require'

      # Go throught all original deps & resolve their fileRelative counterpart.
      [ @arrayDependencies  # Store resolvedDeps as res'DepType'
        @requireDependencies
        @asyncDependencies ] = for strDepsArray in [ # @todo:2 why do we need to replaceAsynchRequires ?
           @moduleInfo.arrayDeps
           @moduleInfo.requireDeps
           @moduleInfo.asyncDeps
          ]
            for strDep in (strDepsArray || [])
              new Dependency strDep, @filename, @bundle

      # add remaining dependencies (eg 'untrustedRequireDeps') to DependenciesReport
      if @bundle.reporter
        for repData in [ (_.pick @moduleInfo, @bundle.reporter.reportedDepTypes) ]
          @bundle.reporter.addReportData repData, @modulePath

      # setup some 'templateInfo' information
      #clone these cause we're injecting deps in them & keep the original for reference
      @parameters = _.clone @moduleInfo.parameters
      @nodeDependencies = _.clone @arrayDependencies

      {@moduleName, @moduleType, @modulePath, @flags} = @moduleInfo

      @flags.rootExports = _B.arrayize @flags.rootExports

      null

  ###
  Actually converts the module to the target @build options.
  ###
  convert: (@build) -> #set @build 'temporarilly': options like scanAllow & noRootExports are needed to calc deps arrays
    if @isConvertible
      l.debug("Preparing conversion of '#{@modulePath}' with template '#{@build.template.name}'") if l.deb 30

      # inject exports.bundle Dependencies information to arrayDependencies, nodeDependencies & parameters
      if not _.isEmpty (bundleExports = @bundle?.dependencies?.exports?.bundle)
        l.debug("#{@modulePath}: injecting dependencies \n", @bundle.dependencies.exports.bundle) if l.deb 80

        for depName, depsVars of bundleExports
          if _.isEmpty depsVars
            # attempt to read from bundle & store found depsVars at @bundle.dependencies.exports.bundle
            depsVars = bundleExports[depName] = @bundle.getDepsVars( (dep)->dep.depName is depName)[depName]

            l.debug("""#{@modulePath}: dependency '#{depName}' had no corresponding parameters/variable names to bind with.
                       An attempt to infer depsVars from bundle: """, depsVars) if l.deb 40

          if _.isEmpty depsVars # still empty, throw error. #todo: bail out on globals with no vars ??
            l.err uerr = """
              No variable names can be identified for `dependencies: exports: bundle` dependency '#{depName}'.

              These variable names are used to :
                - inject the dependency into each module
                - grab the dependency from the global object, when running as <script>.

              Remedy:

              You should add it at uRequireConfig 'bundle.dependencies.exports.bundle' as a
                ```
                  dependencies: exports: bundle: {
                    '#{depName}': 'VARIABLE(S)_IT_BINDS_WITH',
                    ...
                    jquery: ['$', 'jQuery'],
                    backbone: ['Backbone']
                  }
                ```
              instead of the simpler
                ```
                  dependencies: exports: bundle: [ '#{depName}', 'jquery', 'backbone' ]
                ```

              Alternativelly, pick one medicine :
                - define at least one module that has this dependency + variable binding, using AMD instead of commonJs format, and uRequire will find it!
                - declare it in the above format, but in `bundle.dependencies.depsVars` and uRequre will pick it from there!
                - use an `rjs.shim`, and uRequire will pick it from there (@todo: NOT IMPLEMENTED YET!)
            """
            throw new UError uerr
          else
            # @todo: (5 3 4) Make sure arrays are at the same index,
            # and adjust them so deps & params correspond to each other!
            if (lenDiff = @arrayDependencies.length - @parameters.length) > 0
              @parameters.push "__dummyParam#{paramIndex}" for paramIndex in [1..lenDiff]

            for varName in depsVars # add for all corresponding vars
              if not (varName in @parameters)
                d = new Dependency depName, @filename, @bundle #its cheap!
                @arrayDependencies.push d
                @nodeDependencies.push d
                @parameters.push varName
                l.debug("#{@modulePath}: injected dependency '#{depName}' as parameter '#{varName}'") if l.deb 99
              else
                l.debug("#{@modulePath}: Not injecting dependency '#{depName}' as parameter '#{varName}' cause it already exists.") if l.deb 90

      # @todo:3 also add rootExports ?

      # Add all `require('dep')` calls
      # Execution stucks on require('dep') if its not loaded (i.e not present in arrayDeps).
      # see https://github.com/jrburke/requirejs/issues/467
      #
      # So load ALL require('dep') fileRelative deps have to be added to the arrayDepsendencies on AMD.
      #
      # Even if there are no other arrayDependencie, we still add them all to prevent RequireJS scan @ runtime
      # (# RequireJs disables runtime scan if even one dep exists in []).
      #
      # We allow them only if `--scanAllow` or if we have a `rootExports`
      if not (_.isEmpty(@arrayDependencies) and @build?.scanAllow and not @flags.rootExports)
        for reqDep in @requireDependencies
          # dont add to arrayDependencies, if node only
          if reqDep.pluginName isnt 'node' and # 'node' is a fake plugin signaling nodejs-only executing modules.
            (reqDep.name(plugin:false) not in @bundle.dependencies.node) and
            not (_.any @arrayDependencies, (dep)->dep.isEqual reqDep) # and not already there
              @arrayDependencies.push reqDep
              @nodeDependencies.push reqDep if @build?.allNodeRequires

      @webRootMap = @bundle.webRootMap || '.'
      @arrayDeps = (d.name() for d in @arrayDependencies)
      @nodeDeps = (d.name() for d in @nodeDependencies)

      # Now we have all our Dependenecies & bundle properly initialized

      # populate requireReplacements (what goes into 'require()' calls),
      # with fileRelative paths that work everywhere & remove 'node' fake pluging
      requireReplacements = {}
      for dep in _.flatten [ @arrayDependencies, @requireDependencies, @asyncDependencies ]
        requireReplacements[dep.depString] =
          if dep.pluginName is 'node' # remove fake plugin 'node'
            dep.name(plugin:false)
          else
            dep.name()

        # Report each Dependency (if interesting) eg. infrom us "Bundle-looking dependencies not found in bundle"
        if @bundle.reporter
          @bundle.reporter.addReportData _B.okv({}, # build a `{'global':'lodash':['_']}`
            dep.type, [dep.name()]
          ), @modulePath

      # replace 'require()' calls using requireReplacements
      @factoryBody = @moduleManipulator.getFactoryWithReplacedRequires requireReplacements

      {@noRootExports} = @build
      # `this` uModule, stands also for templateInfo :-)
      @moduleTemplate = new ModuleGeneratorTemplates @ #todo: (1 3 1) retain the same @moduleTemplate {} (we need to refresh headers etc in template)

      l.verbose "Converting '#{@modulePath}' with template = '#{@build.template.name}'"
      l.debug "module info = \n", _.pick @, [
          'moduleName', 'moduleType', 'modulePath', 'arrayDeps', 'nodeDeps',
          'parameters', 'webRootMap', 'flags'] if l.deb 80

      @converted = @moduleTemplate[@build.template.name]() # @todo: (3 3 3) pass template, not its name

      delete @noRootExports
    @

  ###
  Returns all deps in this module along with their corresponding parameters (variable names)

  Note: currently, only AMD-modules provide us with the variable-binding of dependencies!

  @param {Function} depFltr optional callback filtering dependency. Called with dep as param. Defaults to all-true fltr

  @return {Object}
      {
        jquery: ['$', 'jQuery']
        lodash: ['_']
        'models/person': ['pm']
      }
  ###
  getDepsVars: (depFltr=->true)->
    depsVars = {}
    if @isConvertible
      for dep, idx in _.flatten [@arrayDependencies, @requireDependencies] when depFltr(dep)
      #when (
#        ((not q.depType) or (q.depType is dep.type)) and
#        ((not q.depName) or (dep.isEqual q.depName)) and
#        ((not q.pluginName) or (dep.pluginName is q.pluginName))
#      )
          dv = (depsVars[dep.name(relativeType:'bundle', plugin:false)] or= [])
          # store the variable(s) associated with dep
          if @parameters[idx] and not (@parameters[idx] in dv )
            dv.push @parameters[idx] # if there is a var, add once

      depsVars
    else {}

module.exports = UModule

### Debug information ###
#if l.deb >= 90
#  YADC = require('YouAreDaChef').YouAreDaChef
#
#  YADC(UModule)
#    .before /_constructor/, (match, bundle, filename)->
#      l.debug("Before '#{match}' with filename = '#{filename}'")
#
#

