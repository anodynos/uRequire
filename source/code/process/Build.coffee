_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/process/Build'
fs = require 'fs'

rimraf = require 'rimraf'
globExpand = require 'glob-expand'

# uRequire
upath = require '../paths/upath'

isFileInSpecs = require '../config/isFileInSpecs'

DependenciesReporter = require './../utils/DependenciesReporter'
MasterDefaultsConfig = require '../config/MasterDefaultsConfig'
UError = require '../utils/UError'

# circular dependencies, lazily loaded on constructor for testing
FileResource = null
Module = null

class Build extends _B.CalcCachedProperties

  @calcProperties:

    changedModules: -> _.pick @_changed, (f)-> f instanceof Module

    changedResources: -> _.pick @_changed, (f)-> f instanceof FileResource

    errorFiles: -> _.pick @_changed, (f)-> f.hasErrors

    changedFiles: -> @_changed

  constructor: (buildCfg)->
    super
    _.extend @, buildCfg

    # circular dependencies, lazily loaded
    Module = require './../fileResources/Module'
    FileResource = require './../fileResources/FileResource'

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

      if not @dstPath # only '@template.combinedFile' is defined
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

  doClean: ->
    if @clean
      @deleteCombinedTemp() # always by default
      if _B.isTrue @clean
        if _B.isTrue (do => try fs.existsSync(@dstPath) catch er)
          if @template.name is 'combined'
            @deleteCombined()
          else
            l.verbose "clean: deleting whole build.dstPath '#{@dstPath}'."
            try
              rimraf.sync @dstPath
            catch err
              l.warn "Can't delete build.dstPath dir '#{@dstPath}'.", err
        else
          l.verbose "clean: build.dstPath '#{@dstPath}' does not exist."
      else # filespecs - delete only files specified
        delFiles = _.filter(globExpand({cwd: @dstPath, filter: 'isFile'}, '**/*'), (f)=> isFileInSpecs f, @clean)
        if not _.isEmpty delFiles
          l.verbose "clean: deleting #{delFiles.length} files matched with filespec", @clean
          for df in delFiles
            l.verbose "clean: deleting file '#{df = upath.join @dstPath, df}'."
            try
              fs.unlinkSync df
            catch err
              l.warn "Can't delete file '#{df}'.", err
        else
          l.verbose "clean: no files matched filespec", @clean

  deleteCombinedTemp: ->
    if @template.name is 'combined'
      if _B.isTrue (do => try fs.existsSync(@template._combinedFileTemp) catch er)
        l.debug 30, "Deleting temporary combined directory '#{@template._combinedFileTemp}'."
        try
          rimraf.sync @template._combinedFileTemp
        catch err
          l.warn "Can't delete temp dir '#{@template._combinedFileTemp}':", err

  deleteCombined: ->
    if @template.name is 'combined'
      if _B.isTrue (do => try fs.existsSync(@template.combinedFile) catch er)
        l.verbose "Deleting combinedFile '#{@template.combinedFile}'."
        try
          fs.unlinkSync @template.combinedFile
        catch err
          l.warn "Can't delete combinedFile '#{@template.combinedFile}':", err

  report: (bundle)-> # some build reporting
    l.verbose "Report for `build` ##{@count}:"

    interestingDepTypes = ['notFoundInBundle', 'untrusted', 'node', 'nodeLocal'] if not @verbose
    if not _.isEmpty report = bundle.reporter.getReport(interestingDepTypes)
      l.warn "\n \nDependency types report for `build` ##{@count}:\n", report

    l.verbose "Changed: #{_.size @changedResources} resources of which #{_.size @changedModules} were modules."
    l.verbose "Copied #{@_copied[0]} files, Skipped copying #{@_copied[1]} files." if @_copied?[0] or @_copied?[1]

    if _.size bundle.errorFiles
      l.deb "#{_.size bundle.errorFiles} files/resources/modules still with errors totally in the bundle."

    if _.size @errorFiles
      l.deb "#{_.size @errorFiles} files/resources/modules with errors in this build."
      l.er "Build ##{@count} finished with errors in #{(new Date() - @startDate) / 1000 }secs."
    else
      l.verbose "Build ##{@count} finished succesfully in #{(new Date() - @startDate) / 1000 }secs."

module.exports = Build

_.extend module.exports.prototype, {l, _, _B}