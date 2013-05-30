upath = require '../paths/upath'

###
  A dummy/base class, representing any file in the bundle
###
class BundleFile
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p ;null

  ###
    @param {Object} bundle The Bundle where this BundleFile belongs
    @param {String} filename, bundleRelative eg 'models/PersonModel.coffee'
  ###
  constructor: (@bundle, @filename)->

  refresh:->
    @dstFilename = @srcFilename
    true #perhaps we could check for filesystem timestamp etc

  reset:-> @hasChanged = true

  @property extname: get: -> upath.extname @filename                # original extension, eg `.js` or `.coffee`

  # alias to source @filename
  @property srcFilename: get: -> @filename
  # source filename with path, eg `myproject/mybundle/mymodule.js`
  @property srcFilepath: get: -> upath.join @bundle.path, @filename

  # @dstFilename exists after each refresh/conversion
  # destination filename with build.outputPath, eg `myBuildProject/mybundle/mymodule.js`
  @property dstFilepath: get:-> if @bundle.build then upath.join @bundle.build.outputPath, @dstFilename

module.exports = BundleFile
