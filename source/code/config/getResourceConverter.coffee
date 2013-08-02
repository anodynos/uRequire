_ = require 'lodash'
_B = require 'uberscore'
l = new _B.Logger 'urequire/config/_resourceConverters', 0 # config's `build.debugLevel` doesn't work here, cause the config is not read yet!
upath = require '../paths/upath'
UError = require '../utils/UError'

BundleFile = require '../fileResources/BundleFile'
FileResource = require '../fileResources/FileResource'
TextResource = require '../fileResources/TextResource'
Module = require '../fileResources/Module'

{_resourceConverters} = require './resourceConverters'

# A formal `ResourceConverter` creator & registry retriever/updater function
#
# It accepts as arguments either all details, or a single RC-like object as the first arg.
#
# It then creates an object with the following keys :
# 'name', 'description', 'filez', 'convert', 'convFilename', 'type', 'isModule', 'isTerminal', 'isAfterTemplate, 'isMatchSrcFilename'


nameFlagsActions =
  '&': (rc)-> rc.type = 'bundle'
  '@': (rc)-> rc.type = 'file'
  '#': (rc)-> rc.type = 'text'
  '$': (rc)-> rc.type = 'module'
  '~': (rc)-> rc.isMatchSrcFilename = true
  '|': (rc)-> rc.isTerminal = true
  '*': (rc)-> rc.isTerminal = false             # todo: delete '*' case - isTerminal = false is default
  '!': (rc)-> rc.isAfterTemplate = true

nameFlags = _.keys nameFlagsActions

searchRCRegistry = (search)->                              # @todo: `src[prop].call` with more meaningfull context ? eg urequire's runtime ?
  l.log 'Searching for RC ', search
  if _.isString search # search by name string
    name = search
    # strip nameFlags for search's sake
    #while name[0] in (n or= _.keys nameFlagsActions) then name = name[1..]
    while name[0] in nameFlags then name = name[1..]
    # lookup registry with name (without flags)
    if rcInReg = _resourceConverters[name]
      rcInReg = getResourceConverter rcInReg

      # apply 'search' nameFlags to RC found
      rcInReg.name = search
      rcInReg = getResourceConverter rcInReg


  else # search is a function
    for rcKey, rc of _resourceConverters
      # make sure its the {} format and store it
      rc = _resourceConverters[rcKey] = getResourceConverter rc
      if search rc
        rcInReg = rc
        break


  if not rcInReg
    l.err uerr = "ResourceConverter not found in registry with name = #{name}, search = #{search}"
    throw new UError uerr

  # retrieved RC from registry, might be a ->, [] or {} - call recursivelly to cater for it
  getResourceConverter rcInReg


module.exports =
getResourceConverter = (rc)->
  l.log 'getResourceConverter, rc =', rc
  if _.isFunction rc
    rc = rc.call searchRCRegistry

  if _.isArray rc
    if _.isEqual rc, [null]                                          # cater for [null] reset array signpost
      return rc                                                      # in blender that arrayPushes RCs
    else
      if _.isString(rc[1]) and                                       # possibly a `description` @ pos 1, if followed
        (_.isArray(rc[2]) or _.isString(rc[2]) or _.isRegExp(rc[2]) )   # by what looks as `filez` at pos 2
          [ name,  description, filez, convert, convFilename] = [    # assign all attributes of array, incl `description`
            rc[0], rc[1],       rc[2], rc[3],   rc[4] ]
      else
        [ name,  filez, convert, convFilename] = [                   # pos 1 is not a description, its a `filez`
          rc[0], rc[1], rc[2],   rc[3] ]

      rc = {name, description, filez, convert, convFilename}

  if not _B.isObject rc
    l.err uerr = 'Bogus resourceConverter:', rc
    throw new UError uerr

  else    # already an {}, or was an Array/Function which ended up as an {}

    if (not rc.name) or !_.isString(rc.name)
      l.err uerr = "ResourceConverter `name` should be a unique, non empty String - was '#{rc.name}'"
      throw new UError uerr

    # Read & remove the flags in name, setting the proper RC object flags.
    while (flag = rc.name[0]) in nameFlags
      nameFlagsActions[flag] rc
      rc.name = rc.name[1..]  # remove 1st char

    if rc.isModule # isModule is DEPRACATED but still supported (till 0.5 ?)
      l.warn "DEPRACATED key 'isModule' found in ResourcesConverter with `name: '#{rc.name}'`. Use `type: 'module'` instead."
      rc.type = 'module'

    if rc.type # might be type-less, hence matching filez type determined by previous/following RC
      if rc.type not in ['bundle', 'file', 'text', 'module']
        l.err "invalid resourceConverter.type '#{rc.type}' - will default to 'bundle'"
        rc.type = 'bundle'

      Object.defineProperty rc, 'clazz',
        enumerable: false
        configurable: true
        value: switch rc.type
          when 'bundle' then BundleFile
          when 'file' then FileResource
          when 'text' then TextResource
          when 'module' then Module

    # some defaults
    rc.description or= "No description for ResourceConverter '#{rc.name}'"
    rc.isTerminal ?= false
    rc.isAfterTemplate ?= false
    rc.isMatchSrcFilename ?= false

    fixConvFilenameFunction rc

  l.log "Returning RC '#{rc.name}' with clazz.name = #{rc?.clazz?.name}"
  rc


registerResourceConverter = (rc)->
  # Check the registry for existing RC under same or different name
  if _resourceConverters[rc.name]
    if _B.isObject(_resourceConverters[rc.name])          # non {} version will be overwritten as a {}
      if (_resourceConverters[rc.name] is rc) or true
        l.warn "Updated/ing existing ResourceConverter '#{rc.name}'"
      else
        l.err uerr = """
          Another ResourceConverter with `name: '#{rc.name}'` exists.
          Change its name, or use `-> @ '#{rc.name}'` to retrieve an existing instance and use it, update it etc"
        """
        throw new UError uerr
    else
      l.warn "Instantiating & registering ResourceConverter from non-object format:", rc
      _resourceConverters[rc.name] = rc

  else
    for regName, regRc of _resourceConverters
      if rc is regRc
        l.err uerr = """
          The ResourceConverter instance with `name: '#{rc.name}' is registered with another `name '#{regName}'`.
          You must use the same name to update it.
          Alternativelly u can clone it (eg use `-> my_#{regName} = _.clone(@ '$#{regName}')` to retrieve
          an existing one and use it, update it, change its flags etc, but changing `my_#{rc.name}.name` before returning it."
        """
        throw new UError uerr

    l.warn 30, "Registering ResourceConverter:", rc.name
    _resourceConverters[rc.name] = rc


# changes the `convFilename` to a function if a String
fixConvFilenameFunction = (rc)->
  if _.isString rc.convFilename
    # consume flags
    if rc.convFilename[0] is '~'
      rc.convFilename = rc.convFilename[1..]
      isSrcFilename = true


    if rc.convFilename[0] is '.'
      # change filename extension
      rc.convFilename =
        do (ext=rc.convFilename)->
          (dstFilename, srcFilename)->
            # By default it replaces `dstFilename`, with `~` flag it replaces `srcFilename`
            upath.changeExt (if isSrcFilename then srcFilename else dstFilename), ext

    else # a fn that returns the `convFilename` String
      rc.convFilename = do (filename=rc.convFilename)-> -> filename

  else # some checks
    if not (_.isFunction(rc.convFilename) or _.isUndefined(rc.convFilename))
      l.err uerr = "ResourceConverter error: `convFilename` is neither String|Function|Undefined."
      throw new UError uerr, nested:err