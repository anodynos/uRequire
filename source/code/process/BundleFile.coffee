upath = require '../paths/upath'

###
  A dummy/base class, representing any file in the bundle
###
class BundleFile

  ###
    @param {Object} bundle The Bundle where this BundleFile belongs
    @param {String} filename, bundleRelative eg 'models/PersonModel.coffee'
  ###
  constructor: (@bundle, @filename)->

  refresh:->true #perhaps we could check for filesystem timestamp etc

  @property extname: get: -> upath.extname @filename                # original extension, eg `.js` or `.coffee`
  @property fullPath: get: -> "#{@bundle.bundlePath}/#{@filename}" # full filename on OS filesystem, eg `myproject/mybundle/mymodule.js`

module.exports = BundleFile