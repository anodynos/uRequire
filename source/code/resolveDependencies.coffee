# Adjust as file-relative deps if its in bundle, as-is otherwise (eg 'underscore')
module.exports = (modyle, bundleFiles, dependencies)->

  _path = require 'path'
  pathRelative = require './utils/pathRelative'
  #l = require './utils/logger'

  # final dependencies, containing all deps found
  bundleRelative  = []  # existing & normalized bundle-relative dependencies (UMD)
  fileRelative = []     # existing file-Relative dependencies (node)

  # extra dependency resolution information
  global = []           # global-looking deps, like 'underscore'
  webRoot = []          # webRoot deps, like '/assets/myLib'
  external = []         # external-looking deps, like '../../../someLib'
  notFoundInBundle = [] # seemingly belonging to bundle, but not found, like '../myLib'

  for dep in dependencies
    dep = dep.replace /\\/g, '/'
    if not ("#{dep}.js" in bundleFiles)
      if dep.match /\//
        # a relative path, maybe pointing to bundle: if so convert to bundleRelative
        normalized = (_path.normalize "#{_path.dirname modyle}/#{dep}").replace /\\/g, '/'
#        normalized = normalized.replace /\\/g, '/'
        if normalized + '.js' in bundleFiles
          dep = normalized

    if "#{dep}.js" in bundleFiles
      frDep = pathRelative "$/#{_path.dirname modyle}", "$/#{dep}", dot4Current:true
    else
      frDep = dep # either global, webRoot, external or notFound : add as-is to fileRelative
      if dep[0] is '/'
        webRoot.push dep
      else
        if dep.match /\//
          # check if outside bundle boundaries eg ../../../myLib or eg lame/dir
          if pathRelative "$/#{modyle}/../../#{dep}", "$" #2 steps back: one for $ & one for module.js
            notFoundInBundle.push dep
          else
            external.push dep
        else #global-looking, add as is eg. 'underscore'
          global.push dep

    bundleRelative.push dep
    fileRelative.push frDep

  return {bundleRelative, fileRelative, global, external, notFoundInBundle, webRoot}