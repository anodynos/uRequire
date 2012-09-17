# Adjust as file-relative deps if its in bundle, as-is otherwise (eg 'underscore')
module.exports = (modyle, bundleFiles, dependencies)->
  _path = require 'path'
  pathRelative = require './utils/pathRelative'
  l = require './utils/logger'

  frDeps = []
  for dep in dependencies
    if dep + '.js' in bundleFiles
      # frDep = path.relative("$/#{_path.dirname modyle}", "$/#{dep}") # NOT working OK
      frDep = pathRelative("$/#{_path.dirname modyle}", "$/#{dep}", dot4Current:true)
      frDeps.push frDep
    else
      frDeps.push dep   # eg 'underscore'
      if dep.match /\// # eg 'lame/dir'
        l.warn "Dependency '#{dep}' in '#{modyle}' propably refers to bundle, but not found. Added as-is."
  return frDeps