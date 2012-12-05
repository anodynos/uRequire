upath = require '../paths/upath'
_ = require 'lodash'
_wrench = require 'wrench'
_fs = require 'fs'

getFiles = (path, conditionCb)->

  files = [] # read bundle dir & keep only .js files
  for bf in _wrench.readdirSyncRecursive(path)
    bundleFilename = bf.replace /\\/g, '/'
    fullFilename = upath.join path, bundleFilename
    if _fs.statSync(fullFilename).isFile()
      if _.isFunction conditionCb
        if conditionCb bundleFilename, fullFilename
          files.push bundleFilename
      else
         files.push bundleFilename

  return files

module.exports = getFiles