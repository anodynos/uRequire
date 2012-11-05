getFiles = (path, conditionCb)->
  _path = require 'path'
  _wrench = require 'wrench'
  _fs = require 'fs'
  files = [] # read bundle dir & keep only .js files
  for mp in _wrench.readdirSyncRecursive(path)
    mFile = _path.join path, mp
    if _fs.statSync(mFile).isFile()
      if conditionCb mFile
        files.push mp.replace /\\/g, '/'
  return files

module.exports = getFiles