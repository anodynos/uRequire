fs = require 'fs'
mkdirp = require 'mkdirp'
When = require 'when'

# uRequire
BundleFile = require './BundleFile'
upath = require 'upath'
ResourceConverter = require '../config/ResourceConverter'
ResourceConverterError = require '../utils/ResourceConverterError'

###
  Represents any bundlefile resource, whose source/content we dont read (but subclasses do).

  The `convert()` of the ResourceConverter should handle the file contents - for example fs.read it, require() it or spawn an external program.

  Paradoxically, a FileResource
    - can `read()` its source contents (assumed utf-8 text)
    - can `save()` its `converted` content (if any).

  Each time it `@refresh()`es, if super is changed (BundleFile's fileStats), it runs `runResourceConverters`:
      - calls `converter.convert()` and stores result as @converted
      - calls `converter.convFilename()` and stores result as @dstFilename
    otherwise it returns `@hasChanged = false`

  When `save()` is called (with no args) it outputs `@converted` to `@dstFilepath`.
###
class FileResource extends BundleFile

  ###
    @data converters {Array<ResourceConverter} (bundle.resources) that matched this filename & are used in turn to convert, each time we `refresh()`
  ###

  ###
    Check if source (AS IS eg js, coffee, LESS etc) has changed
    and convert it passing throught all @converters

    @return true if there was a change (and convertions took place) and note as @hasChanged
            false otherwise
  ###
  refresh: ->
    super.then (superRefreshed)=>
      if not superRefreshed
        false # no change in parent, why should I change ?
      else
        if @constructor is FileResource # run only for this class,
          @runResourceConverters (rc)-> rc.runAt not in _.flatten [ResourceConverter.runAt_modOnly, 'afterSave']
        else
          true # let subclasses decide whether to run ResourceConverters.

  reset:->
    super
    delete @converted

  Object.defineProperties @::,
    # only if @srcMain exists
    srcMainFilepath: get: -> if @srcMain then upath.join @bundle?.path or '', @srcMain
    srcMainRealpath: get: -> if @srcMain then "#{process.cwd()}/#{@srcMainFilepath}"

  # go through all Resource `converters`, converting with each one
  # Note: it acts on @converted & @dstFilename, leaving them in a new state
  runResourceConverters: (convFilter=->true)->
    @hasErrors = false

    converters = (
      for resConv in @converters when convFilter(resConv) and (resConv.enabled )
        break if resConv.isTerminal
        resConv
    )

    if converters.length and l.deb 30
      l.deb "`#{@constructor?.name}` '#{@srcFilename}' passing through #{converters.length} ResourceConverter(s)."

    When.each(converters, (resConv)=>
      l.deb "ResourceConverter '#{resConv.name}' for `#{@constructor?.name}` '#{@srcFilename}' " if l.deb 40

      atStep = null
      When.sequence([
        =>
          if _.isFunction resConv.convert
            @hasChanged = true
            l.deb "`resourceConverter.convert()` for '#{resConv.name}'" if l.deb 90
            atStep = 'convert'

            When(
              if resConv.convert.length is 2 # nodejs style callback is 2nd arg
                # call wating for callback or a promise (race), but ignoring any other sync return
                callbackPromise = (deferred = When.defer()).promise
                fnPromise = resConv.convert @, When.node.createCallback deferred.resolver
                When.race(_.filter [callbackPromise, fnPromise], (it)-> When.isPromiseLike it)
              else
                # call exepecting either a promise or any non-promise sync return
                resConv.convert @
            ).then (@converted)=> # stores resolved value at @converted
        =>
          if _.isFunction resConv.convFilename
            l.deb "`resourceConverter.convFilename()` for '#{resConv.name}'..." if l.deb 60
            atStep = 'convFilename'
            oldDstFn = @dstFilename
            @dstFilename = resConv.convFilename @dstFilename, @srcFilename, @
            if l.deb 60
              if @dstFilename isnt oldDstFn
                l.deb "...@dstFilename changed from '#{oldDstFn}' to '#{@dstFilename}'"
              else
                l.deb 80, "@dstFilename remained '#{oldDstFn}'"
      ]).catch (err)=>
          throw @hasErrors = new ResourceConverterError """
            Error converting #{@constructor?.name} '#{@srcFilename}' with ResourceConverter '#{resConv?.name}' @ step #{atStep}.
          """, {nested: err}
    ).yield @hasChanged

  readOptions = 'utf-8' # compatible with node 0.8 #{encoding: 'utf-8', flag: 'r'}
  read: (filename=@srcFilename, options=readOptions)->
    _.defaults options, readOptions if options isnt readOptions
    filename = upath.join @bundle?.path or '', filename
    try
      fs.readFileSync filename, options
    catch err
      @hasErrors = true
      @bundle.handleError new UError "Error reading file '#{filename}'", nested:err
      undefined

  save: (filename=@dstFilename, content=@converted, options)->
    @constructor.save.call @, upath.join(@dstPath, filename), content, options
    if filename not in (@dstFilenamesSaved or= [])
      @dstFilenamesSaved.push filename

  saveOptions = {encoding: 'utf-8', mode: 438, flag: 'w'}
  @save: (filename, content, options=saveOptions)->
    _.defaults options, saveOptions if options isnt saveOptions
    l.debug("Saving file '#{filename}'...") if l.deb 95
    #todo: fix handleError - @bundle is undefined when statically called
    @bundle.handleError new UError "Error saving - no filename" if !filename
    @bundle.handleError new UError "Error saving - no content" if !content

    try
      if not fs.existsSync(fileDirname = upath.dirname filename)
        l.verbose "save: Creating directory '#{fileDirname}'"
        mkdirp.sync fileDirname

      fs.writeFileSync filename, content, options
      l.verbose "Saved file '#{filename}'"
      return true
    catch err
      l.er uerr = "Can't save '#{filename}'", err
      @bundle.handleError new UError uerr, nested:err

module.exports = FileResource

_.extend module.exports.prototype, {l, _, _B}