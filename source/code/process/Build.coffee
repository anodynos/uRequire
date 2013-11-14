_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
l = new _B.Logger 'urequire/process/Build'

# uRequire
upath = require '../paths/upath'

DependenciesReporter = require './../utils/DependenciesReporter'
MasterDefaultsConfig = require '../config/MasterDefaultsConfig'
UError = require '../utils/UError'
TextResource = require '../fileResources/TextResource'

BundleFile = require './../fileResources/BundleFile'
FileResource = require './../fileResources/FileResource'
TextResource = require './../fileResources/TextResource'
Module = require './../fileResources/Module'

module.exports =

class Build extends _B.CalcCachedProperties

  @calcProperties:

    changedModules: -> _.pick @_changed, (f)-> f instanceof Module

    changedResources: -> _.pick @_changed, (f)-> f instanceof FileResource

    errorFiles: -> _.pick @_changed, (f)-> f.hasErrors

    changedFiles: -> @_changed

  constructor: (buildCfg)->
    super
    _.extend @, buildCfg
    @count = 0

    # setup 'combinedFile' on 'combined' template
    # (i.e where to output AMD-like templates & where the combined .js file)
    if (@template.name is 'combined')
      if not @template.combinedFile # assume '@dstPath' is valid
        @template.combinedFile = @dstPath
        @dstPath = upath.dirname @dstPath

        l.verbose """
            `build.template` is 'combined' and `build.template.combinedFile` is undefined:
            Setting `build.template.combinedFile` = '#{@template.combinedFile}' from `build.dstPath`
            and `build.dstPath` = '#{@dstPath}' (keeping only path.dirname)."""

      @template.combinedFile = upath.changeExt @template.combinedFile, '.js'
      @template._combinedFileTemp = "#{@template.combinedFile}___temp"

      if not @dstPath # one '@combinedFile' is defined
        @dstPath = upath.dirname @template.combinedFile
        l.verbose """
          `build.template` is 'combined' and `build.dstPath` is undefined:
           Setting `build.dstPath` = '#{@dstPath}' from `build.template.combinedFile` = '#{@template.combinedFile}'"""

      if @out
        l.warn "`build.out` is deleted due to `combined` template being used - r.js doesn't work in memory yet."
        delete @out

  @templates = ['UMD', 'UMDplain', 'AMD', 'nodejs', 'combined']

  newBuild:->
    @startDate = new Date();
    @count++
    @current = {} # store user related stuff here for current build
    @_changed = {} # changed files/resources/modules
    @cleanProps()

  # @todo: store all changed info in build (instead of bundle), to allow multiple builds with the same bundle!
  addChangedBundleFile: (filename, bundleFile)->
    @_changed[filename] = bundleFile
#    @cleanProps()

  report: (bundle)-> # some build reporting
    l.verbose "Report for `build` ##{@count}:"

    interestingDepTypes = ['notFoundInBundle', 'untrusted']
    if not _.isEmpty report = bundle.reporter.getReport interestingDepTypes
      l.warn "Dependency types report for `build` ##{@count}:\n", report

    l.verbose "Changed: #{_.size @changedResources} resources of which #{_.size @changedModules} were modules."
    l.verbose "Copied #{@_copied[0]} files, Skipped copying #{@_copied[1]} files." if @_copied?[0] or @_copied?[1]

    if _.size bundle.errorFiles
      l.er "#{_.size bundle.errorFiles} files/resources/modules still with errors totally in the bundle."

    if _.size @errorFiles
      l.er "#{_.size @errorFiles} files/resources/modules with errors in this build."
      l.er "Build ##{@count} finished with errors in #{(new Date() - @startDate) / 1000 }secs."
    else
      l.verbose "Build ##{@count} finished succesfully in #{(new Date() - @startDate) / 1000 }secs."