_ = require 'lodash'
_B = require 'uberscore'
_fs = require 'fs'
_wrench = require 'wrench'

# uRequire
l = new (require '../utils/Logger') 'Build'
upath = require '../paths/upath'
uRequireConfigMasterDefaults = require '../config/uRequireConfigMasterDefaults'

module.exports =

class Build
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor: ->@_constructor.apply @, arguments

  _constructor: (buildCfg)->
    _.extend @, _B.deepCloneDefaults buildCfg, uRequireConfigMasterDefaults.build

    @out = @outputModuleToFile unless @out

  #@todo : check outputPath exists
  outputModuleToFile: (modulePath, content)->
    @outputToFile upath.join(@outputPath, "#{modulePath}.js"), content


  outputToFile: (outputFilename, content)-> # @todo:1 make private ?
    l.debug 5, "Writting file #{outputFilename} : ", content[30]

    if not (_fs.existsSync upath.dirname(outputFilename))
      l.verbose "Creating directory #{upath.dirname outputFilename}"
      _wrench.mkdirSyncRecursive upath.dirname(outputFilename)

    _fs.writeFileSync outputFilename, content, 'utf-8'
    if @watch #if debug
      l.verbose "Written file '#{outputFilename}'"

