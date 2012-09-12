###
  processes each .js file, extracting AMD/module information
  It then outputs each file to 'outputPath' (or overwrites existing if 'forceOverwrite is used)
###
module.exports = (options)->
    log = console.log
    log options
    _ = require('underscore')
    fs = require('fs')
    path = require('path')
    wrench = require('wrench')


    if not fs.existsSync opt.outputPath
      wrench.mkdirSyncRecursive opt.outputPath, 0777

    log "recursing #{options.bundlePath}"
    bundlePaths = wrench.readdirSyncRecursive(options.bundlePath);

    for bundlePath in bundlePaths
      log bundlePath


  #  js = fs.readFileSync(o.bundlePath, 'utf-8')
  #
  #  fileInfo =
  #    bundlePath:
       #will this be the baseUrl on your requirejs.config
    #  filePath: "y:/WebStormWorkspace/Trial_backbone-todos-anodynos/backbone_require/js/models/TodoModel.js"
    #  rootExports: 'myAwesomeModule' # export in one *global* (root) variable. TOdo:check for existence, allow more than one!
    #
    #console.log template _.extend fileInfo, extractModule(js)
  #  template = require("./templates/UMD")
  #  extractModule = require("./extractModule")
