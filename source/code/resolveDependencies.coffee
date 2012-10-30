# Adjust as file-relative deps if its in bundle, as-is otherwise (eg 'underscore')
module.exports = (modyle, bundleFiles, dependencies)->

  _path = require 'path'
  pathRelative = require './utils/pathRelative'
  #l = require './utils/logger'

  # final dependencies, containing all deps found
  bundleRelative  = []  # existing & normalized bundle-relative dependencies
  fileRelative = []     # existing file-Relative dependencies

  # extra dependency resolution information
  global = []           # global-looking deps, like 'underscore'
  webRoot = []          # webRoot deps, like '/assets/myLib'
  external = []         # external-looking deps, like '../../../someLib'
  notFoundInBundle = [] # seemingly belonging to bundle, but not found, like '../myLib'

  # checks for existence, irrespective of .js
  inBundleFiles = (file)->
    return ("#{file}.js" in bundleFiles) or (file in bundleFiles)

  # strips .js extension, if exists
  stripDotJs = (file)->
    if (_path.extname file) is '.js'
      file[0..file.length-4]
    else
      file

  for dep in dependencies ? []
    dep = dep.replace /\\/g, '/'
    if not (inBundleFiles dep)
      if dep.match /\//   # a relative path, maybe pointing to bundle
        normalized = (_path.normalize "#{_path.dirname modyle}/#{dep}").replace /\\/g, '/'
        if inBundleFiles normalized
          dep = stripDotJs normalized

    if inBundleFiles dep
      dep = stripDotJs dep
      frDep = pathRelative "$/#{_path.dirname modyle}", "$/#{dep}", dot4Current:true
    else
      frDep = dep # either global, webRoot, external or notFound : add as-is to fileRelative
      if dep[0] is '/'
        webRoot.push dep
      else
        if dep.match /\//
          # check if outside bundle boundaries eg ../../../myLib or eg lame/dir
          if pathRelative "$/#{modyle}/../../#{dep}", "$" #2 .. steps back :$ & module
            notFoundInBundle.push dep
          else
            external.push dep
        else #global-looking, add as is eg. 'underscore'
          global.push dep

    bundleRelative.push dep
    fileRelative.push frDep

  return {bundleRelative, fileRelative, global, external, notFoundInBundle, webRoot}