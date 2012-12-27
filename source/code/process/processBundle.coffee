_ = require 'lodash'
_fs = require 'fs'
upath = require '../paths/upath'
_wrench = require 'wrench'
getFiles = require "./../utils/getFiles"
DependenciesReporter = require './../DependenciesReporter'
convertModule = require './convertModule'
l = require './../utils/logger'
version = "<%= pkg.version %>"


processModule = (modyle, bundleFiles, options, reporter)->
  l.verbose '\nProcessing module: ', modyle

  oldJs = _fs.readFileSync "#{options.bundlePath}/#{modyle}", 'utf-8'
  newJs = convertModule modyle, oldJs, bundleFiles, options, reporter

  outputFile = upath.join options.outputPath, modyle

  if not (_fs.existsSync upath.dirname(outputFile))
    l.verbose "creating directory #{upath.dirname(outputFile)}"
    _wrench.mkdirSyncRecursive(upath.dirname(outputFile))

  _fs.writeFileSync outputFile, newJs, 'utf-8'


###
  Processes each .js file in 'bundlePath', extracting AMD/module information
  It then tranforms each file using template to 'outputPath'

  { bundlePath: 'build/examples/spec',
  version: '0.1.9',
  forceOverwriteSources: true,
  webRootMap: false,
  outputPath: 'build/examples/spec' }


  TODO: refactor it
  TODO: test it
  TODO: doc it
###
processBundle = (options)->

  l.verbose "uRequire #{options.version}: Processing bundle with options:\n", options

  interestingDepTypes = ['notFoundInBundle', 'untrustedRequireDependencies', 'untrustedAsyncDependencies']
  reporter = new DependenciesReporter(if options.verbose then null else interestingDepTypes )

  try
    bundleFiles =  getFiles options.bundlePath, ()-> true # get all files
    jsFiles =  getFiles options.bundlePath, (fileName)-> (upath.extname fileName) is '.js'
  catch err
    l.err "*uRequire #{version}*: Something went wrong reading from #{options.bundlePath}. Error=\n", err
    process.exit(1) # always

  l.verbose '\nBundle files found: \n', bundleFiles,
            '\nJs files found: \n', jsFiles

  for modyle in jsFiles
    try
      processModule modyle, bundleFiles, options, reporter
    catch err
      l.err "*uRequire #{version}*: Something went wrong when processing #{modyle}. Error=\n", err
      process.exit(1) if not options.Continue

  if not _.isEmpty(reporter.reportData)
    l.log '\n########### urequire, final report ########### :\n', reporter.getReport()

  return null # save pointless coffeescript return :-)

module.exports = processBundle
