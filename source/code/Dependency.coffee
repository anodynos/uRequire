_path = require 'path'
pathRelative = require './utils/pathRelative'

class Dependency
  constructor: (@dep, @modyle='', @bundleFiles=[])->
    @dep = @dep.replace /\\/g, '/'

    indexOfSep = @dep.indexOf '!'
    if indexOfSep > 0
      @pluginName = @dep[0..indexOfSep-1]

    @resourceName = if indexOfSep >= 0
                      @dep[indexOfSep+1..@dep.length-1]
                    else
                      @dep

    # file extension
    if _path.extname @resourceName #store (& trim extension ?)
      @extname = _path.extname @resourceName

  bundleRelative: ()->
    if @isFileRelative() and @isBundleBoundary()
      (_path.normalize "#{_path.dirname @modyle}/#{@resourceName}").replace /\\/g, '/'
      # normalize and check if in bundleFiles
#        normalized =
#      if (normalized + (@extname || '.js')) in @bundleFiles #should not call isFound here, cause it depends on us.
        #normalized
#      else
#        @resourceName
    else
      @resourceName

  fileRelative: ()->
    if @modyle and @isFound()
      pathRelative "$/#{_path.dirname @modyle}", "$/#{@bundleRelative()}", dot4Current:true
    else
      @resourceName

  isBundleBoundary: ()->
    if @isWebRoot() or (not @modyle)
      false
    else
      !!pathRelative "$/#{@modyle}/../../#{@resourceName}", "$" #2 .. steps back :$ & module

  toString:-> name()

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

  toString:-> @name { plugin: yes, relativeType: 'file', ext:yes}

  isFileRelative: ()-> @resourceName[0] is '.'

  isRelative: ()-> @resourceName.indexOf('/') >= 0 and not @isWebRoot()

  isWebRoot: ()-> @resourceName[0] is '/'

  isGlobal: ()->  not @isWebRoot() and
                  not @isRelative() and
                  not @isFound()

  isFound: ()-> (@bundleRelative() + (if @extname then '' else '.js')) in @bundleFiles

module.exports = Dependency
