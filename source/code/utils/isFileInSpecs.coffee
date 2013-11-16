_ = require 'lodash'
_B = require 'uberscore'
minimatch = require 'minimatch'

# Returns true if `filename` passes through the `filez` specs Array
# 
# @param String filename name of the filename, eg 'myfile.txt' 
#
# @param Array<String|RegExp> filename *specs* in minimatch or RegExp,
#        with negative being '!' either as a 1st char of Strings or
#        as a plain '!' that negates the *spec* following (usefull to negate RegExps).
#
isFileInSpecs = (filename, filez)-> #todo: (3 6 4) convert to proper In/in agreement
  finalAgree = false
  for agreement, idx in _B.arrayize filez #go through all (no bailout when true) cause we have '!*glob*'
    agrees =
      if _.isString agreement
        if agreement[0] is '!'
          if agreement is '!'
            excludeIdx = idx + 1
          else
            excludeIdx = idx
          minimatch filename, agreement.slice(1)
        else
          minimatch filename, agreement

      else
        if _.isRegExp agreement
          !!filename.match agreement
        else
          if _.isFunction agreement
            agreement filename

    if agrees
      if idx is excludeIdx
        finalAgree = false
      else
        finalAgree = true

  finalAgree

module.exports = isFileInSpecs

#in line specs
#l = new _B.Logger ''
#
#files = [
#  'myfile.txt'
#  'path/myfile.coffee'
#  'draft/mydraft.coffee'
#  'literate/draft/*.coffee.md'
#
#  #ommit
#  'uRequireConfigUMD.coffee'
#  'mytext.md'
#  'draft/mydraft.txt'
#]
#
#fileSpecs = [
#  '**/*.*'
#  '!**/draft/*.*'
#  '!uRequireConfig*.*'
#  '!', /.*\.md/
#  '**/draft/*.coffee'
#  '**/*.coffee.md'
#]
#
#l.log _.filter files, (f)-> isFileInSpecs f, fileSpecs
#
#l.log isFileInSpecs 'undefined', ['**/*']
