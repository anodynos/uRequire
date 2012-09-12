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

    #create outputPath ?
    #    if not fs.existsSync options.outputPath
    #      wrench.mkdirSyncRecursive opt.outputPath, 0777

    modulePaths = _wrench.readdirSyncRecursive(options.bundlePath)

    for mp in modulePaths
      modulePath = _path.join(options.bundlePath, mp)
      if _fs.statSync(modulePath).isFile()
        if (_path.extname modulePath) is '.js'
          log 'myRequire: processing file:' + modulePath
          data =
            version: options.version
            bundlePath: options.bundlePath
            filePath: modulePath
            # export in one *global* (root) variable.
            # Todo:check for existence, allow more than one!
            rootExports: 'myAwesomeModule'

          oldJs = _fs.readFileSync(modulePath, 'utf-8')
          newJs = template _.extend data, extractModule(oldJs)
          _fs.writeFileSync (_path.join options.outputPath, mp), newJs, 'utf-8'


  makeRequire: ()-> require('./makeRequire')
}
