###
  processes each .js file in 'bundlePath', extracting AMD/module information
  It then tranforms each file using template to 'outputPath'
###
log = console.log
module.exports = {

  processBundle: (options)->
    log 'myRequire: process called with options\n', options
    _ = require('underscore')
    _fs = require('fs')
    _path = require('path')
    _wrench = require('wrench')

    template = require("./templates/UMD")
    extractModule = require("./extractModule")

    if not (_fs.existsSync outputDir)
      log "creating output folder #{options.outputPath}"
      _wrench.mkdirSyncRecursive(options.outputPath)

    for mp in _wrench.readdirSyncRecursive(options.bundlePath)
      module = _path.join(options.bundlePath, mp)
      if not _fs.statSync(module).isFile()
        outputDir = _path.join(options.outputPath, mp)
        if not (_fs.existsSync outputDir)
          log "creating folder #{outputDir}"
          _wrench.mkdirSyncRecursive(outputDir)
      else
        if (_path.extname module) is '.js'
          data =
#            version: options.version
#            bundlePath: options.bundlePath
            filePath: _path.dirname mp
            # export in one *global* (root) variable.
            # Todo:check for existence, allow more than one!
#            rootExports: 'myAwesomeModule'
          oldJs = _fs.readFileSync(module, 'utf-8')
          moduleInfo = extractModule(oldJs)
          log '\nmyRequire: processing file:', mp
          log data
          log _.pick moduleInfo, 'deps'
          newJs = template _.extend data, moduleInfo
          _fs.writeFileSync (_path.join options.outputPath, mp), newJs, 'utf-8'


  getMakeRequire: ()-> require('./makeRequire')
}
