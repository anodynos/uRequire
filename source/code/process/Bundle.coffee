# external
_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
_B = require 'uberscore'

_fs = require 'fs'
_wrench = require 'wrench'

# uRequire
l = new (require '../utils/Logger') 'Bundle'
upath = require '../paths/upath'
getFiles = require "./../utils/getFiles"
uRequireConfigMasterDefaults = require '../config/uRequireConfigMasterDefaults'
DependenciesReporter = require './../DependenciesReporter'
UModule = require './UModule'

###

###
class Bundle
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor:-> @_constructor.apply @, arguments

  interestingDepTypes: ['notFoundInBundle', 'untrustedRequireDependencies', 'untrustedAsyncDependencies']

  @staticProperty requirejs: get:=> require 'requirejs'

  _constructor: (bundleCfg)->
    # clone all bundleCfg properties to @
    _.extend @, _B.deepCloneDefaults bundleCfg, uRequireConfigMasterDefaults.bundle

    @main or= 'main' # @todo: add implicit bundleName, or index.js, main.js & other sensible defaults
    @uModules = {}
    @reporter = new DependenciesReporter @interestingDepTypes #(if build.verbose then null else @interestingDepTypes)
    @loadModules()


  ###
  Read / refresh all files in directory.
  Not run everytime there is a file added/removed, unless we need to:
  Runs initially and in unkonwn -watch / refresh situations
  ###
  @property moduleFilenames: get: ->
    try
      @filenames =  getFiles @bundlePath # get all filenames each time we 'refresh'

      moduleFilenames =  getFiles @bundlePath, (mfn)=>
        _B.inFilters(mfn, @includes) and not _B.inFilters(mfn, @excludes) #@todo (uberscore):notFilters()

      # @todo: cleanup begone modules
      #@deleteModules _.difference(_.keys(@uModules), moduleFilenames)
    catch err
      err.uRequire = "*uRequire #{@VERSION}*: Something went wrong reading from '#{@bundlePath}'."
      l.err err.uRequire
      throw err

    l.verbose 'Bundle files found (*.*):\n', @filenames,
              '\nModule files found (js, coffee etc):\n', moduleFilenames
    moduleFilenames

  deleteModules: (modules)->
    delete @uModules[m] for m in modules if @uModules[m]

  ###
    Processes each module, as instructed by `watcher` in a [] paramor read file system (@moduleFilenames)
    @param build - see `config/uRequireConfigMasterDefaults.coffee`
    @param String or []<String> with filenames to process.
      @default read files from filesystem (property @moduleFilenames)
  ###
  loadModules: (moduleFilenames = @moduleFilenames)->
    for moduleFN in _B.arrayize moduleFilenames
      try
        moduleSource = _fs.readFileSync "#{@bundlePath}/#{moduleFN}", 'utf-8'

        # check exists & source up to date
        if @uModules[moduleFN]
          if uM.sourceCode isnt moduleSource
            delete @uModule[moduleFN]

        if not @uModules[moduleFN]
          @uModules[moduleFN] = new UModule @, moduleFN, moduleSource
      catch err
        l.err 'TEMP:' + err
        if not _fs.existsSync "#{@bundlePath}/#{moduleFN}" # remove it, if missing from filesystem
          l.log "Removed file : '#{@bundlePath}/#{moduleFN}'"
          delete @uModules[moduleFN] if @uModules[moduleFN]
        else
          err.uRequire = "*uRequire #{@VERSION}*: Something went wrong while processing '#{moduleFN}'."
          l.err err.uRequire
          throw err



  ###
  Globals dependencies & the variables they might bind with, like {jquery: ['$', 'jQuery']}

  The information is gathered from all modules and joined together.

  Also use bundle.dependencies.variableNames, for globals + varnames bindings.

  @return dependencies.variableNames @example {
      'underscore': '_'
      'jquery': ["$", "jQuery"]
      'models/PersonModel': ['persons', 'personsModel']
  }

  @todo: If there is a global that ends up with empty vars eg {myStupidGlobal:[]}
    (cause nodejs format was used and var names are NOT read there)
    Then myStupidGlobal MUST have a var name on the config.
    Otherwise, we should alert for fatal error & perhaps quit!

  @todo : refactor & generalize !
  ###
  @property globalDepsVars: get:->
    _globalDepsVars = {}

    gatherDepsVars = (depsVars)-> # add non-exixsting var to the dep's `vars` array
      for dep, vars of depsVars
        existingVars = (_globalDepsVars[dep] or= [])
        existingVars.push v for v in (_B.arrayize vars) when v not in existingVars

    for uMK, uModule of @uModules
      gatherDepsVars uModule.globalDepsVars

    if optsDepsVars = @dependencies?.variableNames
      gatherDepsVars _.pick optsDepsVars, _.keys(_globalDepsVars) # pick only existing GLOBALS

    _globalDepsVars





  ###
  Build / convert all uModules that have changed since last build
  ###
  buildChangedModules: (build)->
    haveChanges = false

    for mfn, uModule of @uModules
      if not uModule.convertedJs # it has changed, then conversion is needed :-)
        haveChanges = true
        #@todo: reset reporter!

        # First, dependency inject information
        # @todo: inject `bundleDependencies`

        convertedJS = uModule.convert build # @todo change this

        # Now, it is send to build.out() or saved to build.outputPath

        # but first, decide where to output when combining
        if build.template is 'combine' #todo: read properly
          if not build.combinedFile # change build's paths
            build.combinedFile = upath.changeExt build.outputPath, '.js'
            build.outputPath = "#{build.combinedFile}__temp"
          #@interestingDepTypes.push 'global' #@todo: add to this reporter's run !

        if _.isFunction build.out
          build.out uModule.modulePath, convertedJS

    @combine build if build.template is 'combine' and haveChanges

    if not _.isEmpty(@reporter.reportData)
      l.log '\n########### urequire, final report ########### :\n', @reporter.getReport()

  #Bundle::build.debugLevel = 10 # @todo: try this for debugin'


  ###
  ###
  combine: (build)->
    almondTemplates = new (require '../templates/AlmondOptimizationTemplate') {
      @globalDepsVars
      @main
    }

    console.log almondTemplates.dependencyFiles

    rjsConfig =
      paths: almondTemplates.paths
      wrap: almondTemplates.wrap
      baseUrl: build.outputPath
      include: @main
      out: build.combinedFile
#      out: (text)=>
#        #todo: build.out it!
#        l.verbose "uRequire: writting combinedFile '#{combinedFile}'."
#        @outputToFile text, @combinedFile
#        if _fs.existsSync @combinedFile
#          l.verbose "uRequire: combined file '#{combinedFile}' written successfully."

      optimize: "none" #  uglify: {beautify: true, no_mangle: true} ,
      name: 'almond'

    for fileName, genCode of almondTemplates.dependencyFiles
      build.outputToFile "#{build.outputPath}/#{fileName}.js", genCode

    try # copy almond.js from GLOBAL/urequire/node_modules -> outputPath #@todo : alternative paths ?
      build.outputToFile(
        "#{build.outputPath}/almond.js"
        _fs.readFileSync("#{__dirname}/../../../node_modules/almond/almond.js", 'utf-8')
      )
    catch err
      err.uRequire = """
        uRequire: error copying almond.js from uRequire's installation node_modules - is it installed ?
        Tried here: '#{__dirname}/../../../node_modules/almond/almond.js'
      """
      l.err err.uRequire
      throw err

    try
      _fs.unlinkSync @combinedFile
    catch err #todo : handle it ?

    l.verbose "optimize with r.js with our kind of 'uRequire.build.js' = ", JSON.stringify _.omit(rjsConfig, ['wrap']), null, ' '
    @requirejs.optimize rjsConfig, (buildResponse)->
      l.verbose 'r.js buildResponse = ', buildResponse
      if false # not build.watch @todo implement watch
        _wrench.rmdirSyncRecursive build.outputPath

      if _fs.existsSync @combinedFile
        l.verbose "uRequire: combined file '#{@combinedFile}' written successfully."




#(require('YouAreDaChef').YouAreDaChef Bundle)
#
#  .before /.*/, (match, args...)->
#    console.log "#### before: #{match} :", args
#    console.log 'debugLevel', this[match]?.debugLevel

#  combine:->
#    l.verbose 'combine: optimizing with r.js'
#  .before 'processModule', (filename)->
#    v.verbose '\nProcessing module: ', filename

module.exports = Bundle