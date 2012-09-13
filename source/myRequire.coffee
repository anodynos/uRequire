###
  processes each .js file in 'bundlePath', extracting AMD/module information
  It then tranforms each file using template to 'outputPath'
###


processBundle = (options)->
  l = require('./utils/logger')
  if not options.verbose then l.log = ->

  l.log 'process called with options\n', options

  _ = require 'underscore'
  _fs = require 'fs'
  _path = require 'path'
  _wrench = require 'wrench'
  template = require "./templates/UMD"
  extractModule = require "./extractModule"
  fileRelativeDependencies = require './fileRelativeDependencies'


  bundleFiles = [] # read bundle dir & keep only .js files
  for mp in _wrench.readdirSyncRecursive(options.bundlePath)
    mFile = _path.join(options.bundlePath, mp)
    if _fs.statSync(mFile).isFile() and (_path.extname mFile) is '.js'
      #todo: make sure its an AMD module
      bundleFiles.push mp.replace /\\/g, '/'

  l.log '\nbundleFiles=', bundleFiles

  for modyle in bundleFiles
    l.log '\n', 'processing module:', modyle
    oldJs = _fs.readFileSync(options.bundlePath + '/' + modyle, 'utf-8')
    moduleInfo = extractModule(oldJs)

    moduleInfo.frDependencies = fileRelativeDependencies modyle, bundleFiles, moduleInfo.dependencies

    if options.noExports
      moduleInfo.rootExports = false #Todo:check for existence, allow more than one,

    templateInfo = _.extend moduleInfo, {
    version: options.version
    modulePath: _path.dirname modyle # module path within bundle
    }

    l.log _.pick templateInfo, 'dependencies', 'frDependencies', 'modulePath'

    newJs = template templateInfo
    outputFile = _path.join options.outputPath, modyle

    if not (_fs.existsSync _path.dirname(outputFile))
      l.log "creating directory #{_path.dirname(outputFile)}"
      _wrench.mkdirSyncRecursive(_path.dirname(outputFile))

    _fs.writeFileSync outputFile, newJs, 'utf-8'




module.exports = {
  processBundle: processBundle
  # used by UMD-transformed modules, to make the node (async) require
  getMakeRequire: ()-> require('./makeRequire')
}
