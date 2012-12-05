_ = require 'lodash'
_.mixin (require 'underscore.string').exports()

slang =
  ## filename related
  ###
  @return file + ext, if it doesnt have it (eg add .js to output .js file)
  ###
  addFileExt: (file, ext)-> file + if _(file).endsWith(ext) then '' else ext

module.exports = slang