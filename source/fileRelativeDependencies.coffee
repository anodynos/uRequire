# Adjust as file-relative deps if its in bundle, as-is otherwise (eg 'underscore')
module.exports = (modyle, bundleFiles, dependencies)->
  _path = require 'path'
  pathRelative = require './pathRelative'
  l = require './utils/logger'

  frDep = []
  for dep in dependencies
    if dep+'.js' in bundleFiles
      frDep.push pathRelative("$/#{_path.dirname modyle}", "$/#{dep}", dot4Current:true)
    else
      frDep.push dep    # eg 'underscore'
      if dep.match /\// # eg 'lame/dir'
        l.warn "Dependency '#{dep}' in '#{modyle}' propably refers to bundle, but not found. Added to fileRelativeDependencies as-is."
  return frDep