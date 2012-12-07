# external
_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
_fs = require 'fs'
_wrench = require 'wrench'
_B = require 'uberscore'

# uRequire
upath = require '../paths/upath'
getFiles = require "./../utils/getFiles"
DependenciesReporter = require './../DependenciesReporter'
UModule = require './UModule'
l = require './../utils/logger'

class BundleProcessor
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props
  Function::staticProperty = (props) => Object.defineProperty @::, name, descr for name, descr of props
  
  interestingDepTypes: ['notFoundInBundle', 'untrustedRequireDependencies', 'untrustedAsyncDependencies']

  constructor: (@options)->
    l.verbose "uRequire #{@options.version}: Processing bundle with @options:\n", @options

    if not @options.bundlePath
      l.err """
        Quitting, no bundlePath specified.
        Use -h for help"""
      process.exit(1)
    else
      if @options.forceOverwriteSources
        @options.outputPath = @options.bundlePath
        l.verbose "Forced output to '#{options.outputPath}'"
      else
        if not @options.outputPath
          l.err """
            Quitting, no --outputPath specified.
            Use -f *with caution* to overwrite sources."""
          process.exit(1)
        else
          if @options.outputPath is @options.bundlePath
            l.err """
              Quitting, outputPath == bundlePath.
              Use -f *with caution* to overwrite sources (no need to specify --outputPath).
              """
            process.exit(1);

    @options.include ?= [/.*\.(coffee|iced|coco)$/i, /.*\.(js|javascript)$/i] # by default include all

    if @options.template is 'combine'
      @options.combinedFile = upath.addExt @options.outputPath, '.js'
      @options.outputPath = "#{@options.combinedFile}__temp"
      @interestingDepTypes.push 'global'

    @reporter = new DependenciesReporter(if @options.verbose then null else @interestingDepTypes)
    @readBundleFiles()


  #store @uModules
  processModule: (filename)->
    l.verbose '\nProcessing module: ', filename
    moduleSource = _fs.readFileSync "#{@options.bundlePath}/#{filename}", 'utf-8'

    uModule = new UModule filename, moduleSource, @bundleFiles,
                          @options, @reporter # @todo: dismiss these two!

    newJs = uModule.convert()

    outputFile = upath.join @options.outputPath, "#{upath.trimExt filename}.js" # fixed, output is always .js

    if not (_fs.existsSync upath.dirname(outputFile))
      l.verbose "Creating directory #{upath.dirname outputFile}"
      _wrench.mkdirSyncRecursive upath.dirname(outputFile)

    _fs.writeFileSync outputFile, newJs, 'utf-8'

  readBundleFiles:->
    try
      @bundleFiles =  getFiles @options.bundlePath # get all filenames

      @moduleFiles =  getFiles @options.bundlePath,
        (moduleFilename)=>
          _B.inFilters(moduleFilename, @options.include) and
          not _B.inFilters(moduleFilename, @options.exclude)
    catch err
      l.err "*uRequire #{version}*: Something went wrong reading from '#{@options.bundlePath}'. Error=\n", err
      process.exit(1) # always

    l.verbose 'Bundle files found (*.*):\n', @bundleFiles,
              '\nModule files found (js, coffee etc):\n', @moduleFiles

  ###

  ###
  combine:->
    l.verbose 'combine: optimizing with r.js'
    rjs = require 'requirejs'
    rjsConfig = require '../templates/RequireJSOptimization'
    rjsConfig.baseUrl = @options.outputPath
    rjsConfig.include = @options.mainName || 'main' # add index & other sensible defaults
    rjsConfig.out = @options.combinedFile
    rjsConfig.name = 'almond'

    # copy almond.js from GLOBAL/urequire/node_modules -> outputPath
    try
      _fs.writeFileSync "#{@options.outputPath}/almond.js",
        (_fs.readFileSync "#{__dirname}/../../../node_modules/almond/almond.js", 'utf-8'), 'utf-8'
    catch err
      err.uRequire = """
        uRequire: error copying almond.js from uRequire's installation node_modules - is it installed ?
        Tried here: '#{__dirname}/../../../node_modules/almond/almond.js'
      """
      l.err err.uRequire
      throw err

    # @todo: delete ? old .js file

    # actually optimize with r.js
    rjs.optimize rjsConfig, (buildResponse)->
      l.verbose 'r.js buildResponse = ', buildResponse
      if false # not @options.watch @todo implement watch
        _wrench.rmdirSyncRecursive @options.outputPath

      if _fs.existsSync @options.combinedFile
        l.verbose "uRequire: combined file '#{@options.combinedFile}' written successfully."

  ###
    Processes each .js file in 'bundlePath', extracting AMD/module information

    It then tranforms each file using template to 'outputPath'

    { bundlePath: 'build/examples/spec',
      version: '0.1.9',
      forceOverwriteSources: true,
      webRootMap: false,
      outputPath: 'build/examples/spec'
  }


    TODO: refactor it to work as a node function
    TODO: test it
    TODO: doc it
  ###
  processBundle: ()->

    for modyle in @moduleFiles
      try
        @processModule modyle
      catch err
        l.err "*uRequire #{version}*: Something went wrong while processing '#{modyle}'. Error=\n", err
        throw err
        process.exit(1) if not @options.Continue

    if @options.template is 'combine'
      @combine()

    if not _.isEmpty(@reporter.reportData)
      l.log '\n########### urequire, final report ########### :\n', @reporter.getReport()


module.exports = BundleProcessor

