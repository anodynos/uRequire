_ = require 'lodash'
_B = require 'uberscore'
l = new _B.Logger 'urequire/config/ResourceConverter', 0 # config's `build.debugLevel` doesn't work here, cause the config is not read yet!

#BundleFile = require '../fileResources/BundleFile'
#FileResource = require '../fileResources/FileResource'
#TextResource = require '../fileResources/TextResource'
#Module = require '../fileResources/Module'

upath = require '../paths/upath'
UError = require '../utils/UError'


# ResourceConverter creates materialized RC instances
# It contains setter factories on the instance
# @note on properties conventions:
# if 'prop' is the name of a property:
#   - 'prop' is a non-enumerable property with a get/set
#   - ' prop' (with a space infront) is the human-display name, to solve the [GETTER/SETTER] feature of utils.inspect/console.log
#   - '_prop  (with a low dash infront) is the actual value holder of 'prop' getter (if different from ' prop')

class ResourceConverter
  # @param rc - an RC-spec ({}, [] or ->)
  # The constructor performs the following:
  # - retrieves the {} representation (from a perhaps [] or -> representation)
  # - copies its properties of to this instance
  # - strips the nameflags, updating boolean flags & type
  # - fixes the convFilename, if its a String (but stores its info for later cloning reusage)
  # @return the proper RC instance
  constructor: (rc)->
#    l.log "Constructing new RC from rcSpec =", rc
    rc = getResourceConverterObject rc # make sure we deal with an {}

    if _B.isHash rc
      @update rc
    else
      return {}

  update: (rc)->
    if rc isnt @
      _.extend @, rc

      # checks
      if @isModule # isModule is DEPRACATED but still supported (till 0.5 ?) #@todo: cater for `@isModule === false`
        l.warn "DEPRACATED key 'isModule' found in ResourcesConverter with `name: '#{rc.name}'`. Use `type: 'module'` instead."
        rc.type = 'module'

      # defaults
      @descr or= "No descr for ResourceConverter '#{@name}'"
      @isTerminal ?= false
      @isAfterTemplate ?= false
      @isBeforeTemplate ?= false
      @isMatchSrcFilename ?= false
    @

  clone: ->
    # make sure it's initializd properly
    rc = _.pick @, ['name', 'descr', 'filez', 'convert', 'isTerminal', 'isAfterTemplate', 'isMatchSrcFilename', 'type']
    rc.convFilename = @[' convFilename'] if @[' convFilename'] # get the original convFilename (eg '.js')
    new ResourceConverter rc

  # turn name, type & convFilename into getter/setter properties, so they can be updated
  Object.defineProperties @::,
    # setting name strips flags & applies them on instance
    name:
      get: -> @[' name']
      set: (name)->
        # Read & remove the flags in name, setting the proper RC object flags.
        if (not name) or !_.isString(name)
          l.er uerr = "ResourceConverter `name` should be a unique, non empty String - was '#{name}'"
          throw new UError uerr

        while (flag = name[0]) in nameFlags
          nameFlagsActions[flag] @
          name = name[1..]  # remove 1st char

        oldName = @[' name']
        if (ResourceConverter.registry[oldName] is @) and (name isnt oldName)
          l.warn "Renaming RC '#{oldName}' to '#{name}' on ResourceConverter.registry."
          delete ResourceConverter.registry[oldName]
          ResourceConverter.registry[name] = @

        @[' name'] = name # human display value & value holder

    # type sets the clazz property accordingly
    # note an RC might be type-less - matching filez type determined by previous/following RC
    type:
      get: -> @[' type']
      set: (type)->
        if type not in types = ['bundle', 'file', 'text', 'module']
          l.er uerr = "Invalid resourceConverter.type '#{type}' - must be in [#{types.join ','}]"
          throw new UError uerr

        @[' type'] = type # human display value & value holder

    clazz:
      get:->
        switch @type
          #note late loading cause of some circular deps on specs
          when 'bundle' then require '../fileResources/BundleFile'
          when 'file' then require '../fileResources/FileResource'
          when 'text' then require '../fileResources/TextResource'
          when 'module' then require '../fileResources/Module'

    # changes the `convFilename` to a function if a String
    convFilename:
      enumerable: true
      get: -> @_convFilename
      set: (cf)->
        if cf
          @[' convFilename'] = cf # display original value

          if _.isString cf
            if cf[0] is '~' # consume flags
              cf = cf[1..]
              isSrcFilename = true

            if cf[0] is '.' # change filename extension
              cf =
                do (ext=cf)->
                  (dstFilename, srcFilename)-> # replaces `dstFilename`, with `~` flag it replaces `srcFilename`
                    upath.changeExt (if isSrcFilename then srcFilename else dstFilename), ext

            else # a fn that returns the `convFilename` String
              cf = do (filename=cf)-> -> filename

          else # some checks
            if not (_.isFunction(cf) or _.isUndefined(cf))
              l.er uerr = "ResourceConverter error: `convFilename` is neither String|Function|Undefined."
              throw new UError uerr, nested:err

          # set and hide value holder @todo: NOT WORKING
          #Object.defineProperty @, '_convFilename', {value:cf, enumerable:false, configurable:true}
          @_convFilename = cf

  ### ResourceConverters Registry functions ###
  @registry = require('./ResourceConverters').extraResourceConverters

  # A higly argument overloaded function:
  #
  # Searches and returns an RC by name (string). Flags on searchName update found RC.
  # Add an non-existent RC
  # Finds and updates an existing/registered RC (by an RC or rc spec)
  #
  # @param rc :
  #   String name - eg 'coffee-script' or '#coffee-script' which finds and applies flags to found RC
  #   ResourceConverter instance, which updates the one found if it exists by the same name
  #   formal or informal spec (Object or Array notation), instantiated as RC instance, update existing if it exists.
  #
  # @return The new or found and/or Updated ResourceConverter instance.
  @searchRegisterUpdate: (rc)->
    if _.isString rc
      name = rc
      # strip nameFlags for searchNameOrRC's sake
      while name[0] in nameFlags then name = name[1..]  
      # lookup registry with name (without flags)
      if rcResult = ResourceConverter.registry[name]
        if not (rcResult instanceof ResourceConverter)
          rcResult = ResourceConverter.registry[name] = new ResourceConverter rcResult
          #l.warn "Instantiated a registered, non instance ResourceConverter while searching for '#{searchNameOrRC}'."

        rcResult.name = rc # apply nameFlags of rc String
      else
        throw new UError "ResourceConverter not found in registry with name = #{name}, searchNameOrRC = #{searchNameOrRC}"

    else
      if not (rc instanceof ResourceConverter)
        rcResult = rc = new ResourceConverter rc

      if rc and !_.isEmpty(rc)
        # Check the registry for existing RC (instance or RC-spec) under 'name'
        if rcFound = ResourceConverter.registry[rc.name] # find by rc.name
          if not (rcFound instanceof ResourceConverter)
            rcFound = new ResourceConverter rcFound
            #l.warn "Instantiated a registered, but non-RC instance ResourceConverter '#{rcResult.name}'."

          rcResult = ResourceConverter.registry[rc.name] = rcFound.update rc # always update with passed rc
          #l.warn "Updated existing ResourceConverter #{rcResult.name}'."

        else # not found by rc.name - create & register a new one
          rcResult = ResourceConverter.registry[rcResult.name] = rc
          #l.warn "Instantiated and registered a *new* ResourceConverter '#{rcResult.name}'"
    rcResult

  # @param rc either the {}, [] or  -> representation of an RC
  # @return the {} representation of an RC
  getResourceConverterObject = (rc)->

    if _.isFunction rc
      rc = rc.call ResourceConverter.searchRegisterUpdate, ResourceConverter.searchRegisterUpdate
      return getResourceConverterObject rc                              # returned rc might still be a ->, [] or {}

    if _.isString rc
      return getResourceConverterObject ResourceConverter.searchRegisterUpdate rc

    if _.isArray rc
      if _.isString(rc[1]) and                                          # possibly a `descr` @ pos 1, if followed
        (_.isArray(rc[2]) or _.isString(rc[2]) or _.isRegExp(rc[2]) )   # by what looks as `filez` at pos 2
          [ name,  descr, filez, convert, convFilename] = [             # assign all attributes of array, incl `descr`
            rc[0], rc[1],       rc[2], rc[3],   rc[4] ]
      else
        [ name,  filez, convert, convFilename] = [                   # pos 1 is not a descr, its a `filez`
          rc[0], rc[1], rc[2],   rc[3] ]

      rc = {name, descr, filez, convert, convFilename}

    if rc and not _B.isHash(rc) # allow null & undefined
      l.er uerr = 'Bogus resourceConverter:', rc
      throw new UError uerr

    rc

  nameFlagsActions =
    '&': (rc)-> rc.type = 'bundle'
    '@': (rc)-> rc.type = 'file'
    '#': (rc)-> rc.type = 'text'
    '$': (rc)-> rc.type = 'module'

    '~': (rc)-> rc.isMatchSrcFilename = true
    '|': (rc)-> rc.isTerminal = true
    '*': (rc)-> rc.isTerminal = false   # default, needed only for 0.4.x strip support
    '+': (rc)-> rc.isBeforeTemplate = true
    '!': (rc)-> rc.isAfterTemplate = true

  nameFlags = _.keys nameFlagsActions

module.exports = ResourceConverter
