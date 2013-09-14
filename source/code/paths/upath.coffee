_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
_path = require 'path'

###
  upath is a proxy to node's 'path', replacing '\' with '/' for all string results :-)

  And adding some features ?...
###
upath = {}
for fName, fn of _path when _.isFunction fn
  upath[fName] = do (fName)->
    (p...)->
      res = _path[fName] p...
      if _.isString res
        res.replace /\\/g, '/'
      else
        res

# normalize eveything but the first meaninigfull './'
upath.normalizeSafe = (path)->
  path = path.replace /\\/g, '/'
  if _.startsWith path, './'
    if _.startsWith path, './..'
      upath.normalize(path)
    else
      './' + upath.normalize(path)
  else
    upath.normalize(path)

## filename related additions
###
  @return file + ext, if it doesnt have it
  eg to add .js to output .js file
###
upath.addExt = (file, ext)->
  file + if _.endsWith(file, ext) then '' else ext

upath.trimExt = (file)->
  file[0..(file.length - @extname(file).length)-1]
###
  @return filename with changed extension
###
upath.changeExt = (file, ext)->
  upath.trimExt(file) + if ext[0] is '.' then ext else '.'+ext

###
  Add .ext, ONLY if filename doesn't have an extension (any).
  Extensions are considered to be up to 6 chars long
###
upath.defaultExt = (file, ext)->
  oldExt = upath.extname file
  if oldExt and (oldExt.length <= 6) and (oldExt.length >= 1)
    file
  else
    upath.addExt file, ext

module.exports = upath

## inline tests @todo specs!
#console.log upath.trimExt 'myfile/trimedExt.txt'
#
#console.log upath.changeExt 'myfile/changedToPDF.txt', 'pdf'
#console.log upath.changeExt 'myfile/changedToDotPDF.txt', '.pdf'
#console.log upath.changeExt 'mymodule.coffee.md', '.js' # NOT WORKING
#
#console.log upath.addExt 'myfile/addedTxt.txt', 'txt'
#console.log upath.addExt 'myfile/addedDotTxt.txt', '.txt'

#console.log upath.addExt 'mymodule.coffee.md', 'coffee.md' # NOT WORKING

#console.log upath.join undefined or '', 'module/location'
#console.log upath.normalizeSafe './../module/./location'
#console.log upath.normalizeSafe './module/./location'
#console.log upath.normalizeSafe '.././module//location'