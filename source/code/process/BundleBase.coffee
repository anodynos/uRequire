_ = (_B = require 'uberscore')._
l = new _B.Logger 'urequire/process/BundleBase'

fs = require 'fs'

upath = require '../paths/upath'
pathRelative = require '../paths/pathRelative'
Dependency = require '../fileResources/Dependency'
UError = require '../utils/UError' #todo: use this instead!

###
Common functionality used at build time (Bundle) or runtime (NodeRequirer)
###
class BundleBase extends _B.CalcCachedProperties

  Object.defineProperties @::,
    webRoot:
      get: -> upath.normalize "#{
        if @webRootMap[0] is '.' # hardwired as path from path
          @path + '/' + @webRootMap
        else
          @webRootMap # an OS file system dir, as-is
        }"

  ###
  For a given `Dependency`, resolve *all possible* paths to the file.

  `resolvePaths` is respecting:
       - The `Dependency`'s own semantics, eg `webRootMap` if `dep` is relative to web root (i.e starts with `\`) and similarly for isRelative etc. See <code>Dependency</code>
       - `@relativeTo` param, which defaults to the module file calling `require` (ie. @dirname), but can be anything eg. @path.
       - `requirejs` config, if it exists in this instance of BundleBase / NodeRequirer

  @param {Dependency} dep The Dependency instance whose paths we are resolving.
  @param {String} relativeTo Resolve relative to this path. Default is `@dirname`, i.e the module/file that called `require`

  @return {Array<String>} The resolved paths of the Dependency
  ###
  resolvePaths: (dep, relativeTo = @dirname)->
    depName = dep.name plugin:no, ext:yes

    resPaths = []
    addit = (path)-> resPaths.push upath.normalize path

    if dep.isFileRelative #relative to requiring file's dir
      addit relativeTo + '/' + depName
    else
      if dep.isWebRootMap # web-root path
        addit @webRoot + depName
      else # requireJS baseUrl/Paths
        pathStart = depName.split('/')[0]
        if @getRequireJSConfig().paths?[pathStart] #eg src/
          paths = @getRequireJSConfig().paths[pathStart]
          if not _.isArray(paths)
            paths = [ paths ] #else _.isString(paths)

          for path in paths # add them all
            addit @path + (depName.replace pathStart, path)
        else
          if dep.isRelative  # relative to bundle eg 'a/b/c',
            addit @path + depName
          else # a single pathpart, like 'underscore' or 'myLib'
            addit depName     # local eg 'underscore' (most likely)
            addit @path + depName  # or bundleRelative (unlikely)

    return resPaths

module.exports = BundleBase