_ = require 'lodash'
_B = require 'uberscore'

# urequire
l = new (require '../utils/Logger') 'UModule'

Bundle = require './Bundle'
Build = require './Build'

###
  Load Config:
    * check options
    * Load (a) bundle(s) and (a) build(s)
    * Build & watch for changes
###

class BundleBuilder
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor: ->@_constructor.apply @, arguments

  _constructor: (@cfg)->

    # todo: cater for `simple` format and bring up to the full format

    @cfg.bundle.VERSION = '0.3.0 Alpha - change this!'

    # check & build config / options
    @checkBuildPathsOrQuit() # @todo:3 improve

    l.verbose """Building '#{@cfg.bundle.bundleName || 'UNNAMED'}' bundle in
                 '#{@cfg.bundle.bundlePath}' with build = """, @cfg.build

    # Load Bundle
    @bundle = new Bundle @cfg.bundle
    @build = new Build @cfg.build

    # Build bundle against the build setup (@todo: or builds ?)
    @bundle.buildChangedModules @build


    # @todo: & watch its folder
    # @watchDirectory @cfg.bundle.bundlePath

  # todo: register something to watch events
  #  watchDirectory:->
  #    onFilesChange: (filesChanged)->
  #      bundle.loadModules filesChanged #:[]<String>

  checkBuildPathsOrQuit:->
    if not @cfg.bundle.bundlePath
      l.err """
        Quitting, no bundlePath specified.
        Use -h for help"""
      process.exit(1)
    else
      if @cfg.build.forceOverwriteSources
        @cfg.build.outputPath = @cfg.bundle.bundlePath
        l.verbose "Forced output to '#{@cfg.build.outputPath}'"
      else
        if not @cfg.build.outputPath
          l.err """
            Quitting, no --outputPath specified.
            Use -f *with caution* to overwrite sources."""
          process.exit(1)
        else
          if @cfg.build.outputPath is @cfg.bundle.bundlePath #@todo: check normalized
            l.err """
              Quitting, outputPath == bundlePath.
              Use -f *with caution* to overwrite sources (no need to specify --outputPath).
              """
            process.exit(1)


module.exports = BundleBuilder