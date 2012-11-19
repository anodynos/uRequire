_ = require 'lodash'
_fs = require 'fs'
upath = require '../paths/upath'
_wrench = require 'wrench'
getFiles = require "./../utils/getFiles"
DependenciesReporter = require './../DependenciesReporter'
convertModule = require './convertModule'
l = require './../utils/logger'


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

  bundleFiles =  getFiles options.bundlePath, (fileName)-> true # get all files
  jsFiles =  getFiles options.bundlePath, (fileName)-> (upath.extname fileName) is '.js'

  l.verbose '\nBundle files found: \n', bundleFiles

  for modyle in jsFiles
    processModule modyle, bundleFiles, options, reporter

  if not _.isEmpty(reporter.reportData)
    l.log '\n########### urequire, final report ########### :\n', reporter.getReport()

  return null # save pointless coffeescript return :-)

module.exports = processBundle