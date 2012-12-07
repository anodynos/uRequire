upath = require './paths/upath'
pathRelative = require './paths/pathRelative'


class Dependency

  constructor: (@dep, @moduleFilename='', @bundleFiles=[])->
    @dep = @dep.replace /\\/g, '/'

    indexOfSep = @dep.indexOf '!'
    if indexOfSep > 0
      @pluginName = @dep[0..indexOfSep-1]

    @resourceName = if indexOfSep >= 0
                      @dep[indexOfSep+1..@dep.length-1]
                    else
                      @dep

    # file extension
    if upath.extname @resourceName #store (@todo: trim extension and keep like that)
      @extname = upath.extname @resourceName

  @TYPES:
    notFoundInBundle: 'notFoundInBundle'
    global: 'global'
    external: 'external'
    webRoot: 'webRoot'
    bundle: 'bundle'

  type:->
    if @isGlobal()
      @TYPES.global
    else
      if @isExternal()
        @TYPES.external
      else
        if @isNotFoundInBundle()
          @TYPES.notFoundInBundle
        else  # webRoot deps, like '/assets/myLib'
          if @isWebRoot()
            @TYPES.webRoot
          else
            false # @todo:TYPES.bundle

  # @todo @property name: {get}
  name: (options = {})->
    options.ext ?= true # default true
    options.plugin ?= true # default true
    options.relativeType ?= 'file' # default 'file

    n = """
      #{  if options?.plugin and @pluginName then @pluginName + '!' else ''
      }#{ if options?.relativeType is 'bundle' then @bundleRelative() else @fileRelative() #file = default
      }
    """

    if options.ext or not @extname
      n
    else
      n[0..(n.length - @extname.length)-1] #strip extension ?


  bundleRelative: ()->
    if @isFileRelative() and @isBundleBoundary()
        upath.normalize "#{upath.dirname @moduleFilename}/#{@resourceName}"
      # normalize and check if in bundleFiles
#        normalized =
#      if (normalized + (@extname || '.js')) in @bundleFiles #should not call isFound here, cause it depends on us.
        #normalized
#      else
#        @resourceName
    else
      @resourceName

  fileRelative: ()->
    if @moduleFilename and @isFound()
      pathRelative "$/#{upath.dirname @moduleFilename}", "$/#{@bundleRelative()}", dot4Current:true
    else
      @resourceName

  #toString:-> name()
  toString:-> @name { plugin: yes, relativeType: 'file', ext:yes}

  isBundleBoundary: ()->
    if @isWebRoot() or (not @moduleFilename)
      false
    else
      !!pathRelative "$/#{@moduleFilename}/../../#{@resourceName}", "$" #2 .. steps back :$ & module

  isFileRelative: ()-> @resourceName[0] is '.'

  isRelative: ()-> @resourceName.indexOf('/') >= 0 and not @isWebRoot()

  isWebRoot: ()-> @resourceName[0] is '/'

  isGlobal: ()->  not @isWebRoot() and
                  not @isRelative() and
                  not @isFound()

  ### external-looking deps, like '../../../someLib' ###
  isExternal: ()-> not (@isBundleBoundary() or @isWebRoot())

  ### seem to belong to bundle, but not found, like '../myLib' ###
  isNotFoundInBundle: ()-> @isBundleBoundary() and not (@isFound() or @isGlobal())


  isFound: ()-> # @todo: Remove .js dependency - Might have a dep to 'a.js' but we have 'a.coffee'
    knownExtensions = ['.js', 'coffee'] # @todo: retrieve this info from elsewhere (eg Bundle ?)
    for ke in knownExtensions
      if (@bundleRelative() + (if @extname then '' else ke)) in @bundleFiles
        return true

module.exports = Dependency