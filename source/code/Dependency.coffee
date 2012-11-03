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
      #@resourceName = @resourceName[0..(@resourceName.length - @extname.length)-1] #strip extension ?

  bundleRelative: ()->
    if @isFileRelative()
      # normalize and check if in bundleFiles
      normalized = (_path.normalize "#{_path.dirname @modyle}/#{@resourceName}").replace /\\/g, '/'
      if (normalized + (@extname || '.js')) in @bundleFiles #should not call isFound here, cause it depends on us.
        normalized
      else
        @resourceName
    else
      @resourceName

  fileRelative: ()->
    if @modyle and @isFound()
      pathRelative "$/#{_path.dirname @modyle}", "$/#{@bundleRelative()}", dot4Current:true
    else
      @resourceName

  isFileRelative: ()-> @resourceName[0] is '.'

  isRelative: ()-> @resourceName.indexOf('/') >= 0 and not @isWebRoot()

  isWebRoot: ()-> @resourceName[0] is '/'

  isBundleBoundary: ()->
    if @isWebRoot() or (not @modyle)
      false
    else
      !!pathRelative "$/#{@modyle}/../../#{@fileRelative()}", "$" #2 .. steps back :$ & module

  isGlobal: ()->  not @isWebRoot() and
                  not @isRelative() and
                  not @isFound()

  isFound: ()-> (@bundleRelative() + (if @extname then '' else '.js')) in @bundleFiles

  toString:-> """
        #{  if @pluginName then @pluginName + '!' else ''
        }#{ @fileRelative()
        }
    """

module.exports = Dependency

