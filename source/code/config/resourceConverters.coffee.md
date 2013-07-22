# Introduction

**Resource Converters (RC)** are compilers/converters/transpilers etc, that perform a conversion from one resource format (eg coffeescript, less) to another **converted** format (eg javascript, css).


**Resource Converters** is a simplistic, generic, yet evolving *conversions workflow system*, that is trivial to use and extend to cater for all kind of conversions. The workflow has the following principles :

  * *simple callback API* that enables any kind of conversion, even with *one-liners*.

  * focus to *in-memory conversions pipeline*, to save time loading & saving through the filesystem.

  * powerfull *only-when-needed* workflow, where each file is processed/converted only when it really needs to.

  * *seamlessly integrated* with `bundle` & `build` paths, unobstrusivelly loading from and saving to the filesystem with a lean config. It also works smoothly with `build.watch` and the whole uRequire building process.

All [`bundle.filez`](uRequireConfigMasterDefaults.coffee#bundle.filez) that are matched by one or more Resource Converters in [`bundle.resources`](uRequireConfigMasterDefaults.coffee#bundle.resources) are considered as **resources**.

@todo flexible in memory pipelines, where to go next etc.

## Literate Coffescript

This file is written in [Literate Coffeescript](http://ashkenas.com/literate-coffeescript): it serves both as *markdown documentation* AND the *actual code* that represents the *master config*. The code blocks shown are the actual code used at runtime, i.e each key declares its self and sets a default value.

    _ = require 'lodash'
    _B = require 'uberscore'
    l = new _B.Logger 'urequire/config/resourceConverters', 0 # config's `build.debugLevel` doesn't work here, cause the config is not read yet!
    upath = require '../paths/upath'
    UError = require '../utils/UError'

    BundleFile = require '../fileResources/BundleFile'
    FileResource = require '../fileResources/FileResource'
    TextResource = require '../fileResources/TextResource'
    Module = require '../fileResources/Module'

## Inside a Resource Converter

Each *Resource Converter* (RC) has:

 * `name` : a simple name eg. `'coffeescript'`. A `name` can have various flags at the start of this name - see below. @todo: `name` should be unique

 * `description` : any optional details to keep the name smaller :-)

 * `filez` : a same as [`bundle.filez`](urequireconfigmasterdefaults.coffee#bundle.filez) spec of the files this resource deals with (always withing `bundle.filez` files).

 * `convert` :  a callback eg `function(resource){return convert(resource.source)}` that converts using some resource's data (eg `source`) to an in memory *converted* state or perform any other in memory or external conversion.
 The return of `convert()` is stored as `resource.converted` and its possibly converted again by a subsequent converter. Finally, if it ends up as non falsy, its saved automatically at `resource.dstFilepath` (which uses [`build.dstPath`](urequireconfigmasterdefaults.coffee#build.dstPath)) & `convFilename()` below.

 * `convFilename` :

  * a `function(dstFilename, srcFilename){return 'someConvertedDstFilename.ext')}` that converts the current `dstFilename` (or the `srcFilename`) or to its new *destination* `dstFilename`, eg `'file.coffee'-> 'file.js'`.

  * a `String` starting with '.' (eg ".js"), its considered a simple extension replacement. By default it replaces the extension of current `dstFilename`, but with the `~` flag it performs the extension replacement on `srcFilename` (eg `"~.coffee.md"`).

  * a plain String, returned as is (*note: duplicate destFilename currently cause a build error*).

 * flags `isTerminal`, `isAfterTemplate` & `isMatchSrcFilename` & `type` that can be easily defined via `name` flags - explained below.

Resource Converters are *attached* to files of the bundle (those that match `filez`), the last one determining the class of created resource.

### resource `clazz` & `type`

The `type` is user set among ['bundle', 'file', 'text', 'module'] - the default is undefined.

A resource converter's `type` marks each matching file's clazz either as a `Module`, a `TextResource` or a `FileResource` (but only the last one matters!)

#### FileResource

An external file whose contents we need to know nothing of (but we can if we want). At each conversion, the `convert()` is called, passing a `FileResource` instance with fields:

  * (from `BundleFile`) :
    `srcFilename` - eg
    `srcFilepath` - eg
    `dstFilepath` - eg
    `fileStats` - eg
    `sourceMapInfo` eg
     more ???

You can perform any internal or external conversion in `convert()`. If `convert()` returns non falsy, the content is saved at [`build.dstPath`](urequireconfigmasterdefaults.coffee#build.dstPath).

#### TextResource

A subclass of TextResource Any *textual/utf-8* **Resource**, (eg a `.less` file), denoted by `type:'text'` or via a `'#'` flag preceding its `name` eg `name:'#less'`.

_Key has precedence over name flag, if object format is used - see @type._

#### Module

A **Module** is *javascript code* with node/commonjs `require` or AMD style `define`/`require` dependencies.

Each Module is converted just like a *textual/utf-8* **Resource**, but its dependencies come into play and ultimately it is converted through the chosen [`template`](urequireconfigmasterdefaults.coffee#build.template).

Its is denoted either via key `isModule:true` or via a lack of `'#'` flag preceding its name.

_Again key has precedence over name flag, if object format is used - see @type._

### isTerminal

A converter can be `isTerminal:true` (the default) or `isTerminal:false`.

uRequire uses each matching converter in turn during the build process, converting from one format to the next, using the converted source and dstFilename as the input to the next converter. All that until the first `isTerminal:true` converter is encountered, where the resource conversion process stops.

A converter is by default `isTerminal:false` and can denote it self as `isTerminal:true` in the object format or by using the name flag `'|'`.

### isAfterTemplate

A converter with `isAfterTemplate:true` (refers only to Module converters) will run after the module is converted through its template (eg 'UMD'). By default `isAfterTemplate:false`. Use the `'!'` name flag to denote `isAfterTemplate:true`.

### As an example, the `defaultRecourceConverters`

The following code [(that is actually part of uRequire's code)](#Literate-Coffescript), defines the Default Resource Converters ('javascript', 'coffeescript', 'livescript', 'coco') all as `type:'module' :

    defaultResourceConverters = [

### The proper *Object way* to define a Resource Converter

# a dummy .js converter
{
  name: '$javascript'            # '$' flag denotes `type: 'module'`.

  description: "I am a dummy js converter, I do nothing but mark `.js` files as `Module`s."

  filez: [                       # type is like `bundle.filez`, defines matching files, matched, marked and converted with this converter
    '**/*.js'                    # minimatch string (ala grunt's 'file' expand or node-glob), with exclusions as '!**/*temp.*'
                                 # RegExps work as well - use [..., `'!', /myRegExp/`, ...] to denote exclusion
    /.*\.(javascript)$/
  ]

  convert: -> @source            # javascript needs no compilation - just return source as is

  convFilename: (srcFilename)->   # convert .js | .javascript to .js
    (require '../paths/upath').changeExt srcFilename, 'js'

  # these are defaults, you can ommit them
  isAfterTemplate: false
  isTerminal: false
  isMatchSrcFilename: false
  type: 'module'                # not needed, since we have '$' flag to denote `type: 'module'`
}

### The alternative (and less verbose) *Array way* of declaring an RC, using an [] instead of {}.

        [
          '$coffeescript'                                                   # `name` & flags as a String at pos 0

                                                                            # `description` at pos 1
          "Coffeescript compiler, using the locally installed 'coffee-script' npm package. Uses `bare:true`."

          [ '**/*.coffee', /.*\.(coffee\.md|litcoffee)$/i]                  # `filez` [] at pos 2

          do ->                                                             # `convert` Function at pos 3
            coffee = require 'coffee-script'                                # 'store' `coffee` in closure
            -> coffee.compile @source, bare:true                            # return the convert fn

          (srcFn)->                                                         # `convFilename` Function at pos 4
            ext = srcFn.replace /.*\.(coffee\.md|litcoffee|coffee)$/, "$1"  # retrieve matched extension, eg 'coffee.md'
            srcFn.replace (new RegExp ext+'$'), 'js'                        # replace it and teturn new filename
        ]

### The alternative, even shorter `[] way`

        [
          '$livescript'
          [ '**/*.ls']                                                      # if pos 1 is Array, then there's *undefined `description`*
          ->(require 'LiveScript').compile @source, bare:true               # @todo: autodetect *undefined description* if 3rd is a -> or undefined
          '.js'                                                             # if `convFilename` is String starting with '.',
        ]                                                                   # it denotes an ext replacement of dstFilename (or srcFilename if `~` flag is used.

### The shortest way ever, a one-liner converter!

        [ '$coco', [ '**/*.coco'], (->(require 'coco').compile @source, bare:true), '.js']
    ]

## How do we such flexinbility with both [] & {} formats ?


## A formal `ResourceConverter` creator & registry retriever/updater function

It accepts as arguments either all details, or a single RC-like object as the first arg.

It then creates an object with the following keys :
  `'name', 'description', 'filez', 'convert', 'convFilename', 'type', 'isModule', 'isTerminal', 'isAfterTemplate, 'isMatchSrcFilename'`

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
    
    getResourceConverterForObjectArrayOrFunction = (rc)->

      if _.isFunction rc
        retrievedRC = rc.call (search)->                              # @todo: `src[prop].call` with more meaningfull context ? eg urequire's runtime ?
          # search by name
          if _.isString search
            name = search
            # strip nameFlags for search's sake
            while name[0] in nameFlags then name = name[1..]
            # lookup registry with name (without flags)
            rcInReg = resourceConverters[name]

            # The search being a name String, perhaps WITH nameFlags
            if _B.isObject rcInReg
              # so search becomes the new name, causing a refresh of {} flags.
              rcInReg.name = search
            else
              # oops, Array versions might still have their own flags
              # still not materilized as {} properties flags
              if _.isArray rcInReg
                lastFlagIdx = 0
                while rcInReg[0][lastFlagIdx] in nameFlags then lastFlagIdx++
                rcInReg[0] = rcInReg[0].slice(0, lastFlagIdx) + search

          # search is actually a function
          else
            rcInReg = _.find resourceConverters, (resConv)-> search resConv

          if not rcInReg
            l.err uerr = "ResourceConverter not found in registry with name = #{name}, search = #{search}"
            throw new UError uerr

          # retrieved RC from registry, might be a ->, [] or {} - call recursivelly to cater for it
          return getResourceConverterForObjectArrayOrFunction rcInReg

        # retrieved the RC from fn.call, again might be a ->, [] or {} - call recursivelly to cater for it
        return getResourceConverterForObjectArrayOrFunction retrievedRC

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

        # Check the registry for existing RC under same or different name
        if resourceConverters[rc.name]
          if _B.isObject(resourceConverters[rc.name])          # non {} version will be overwritten as a {}
            if (resourceConverters[rc.name] is rc)
              l.warn "Updated/ing existing ResourceConverter '#{rc.name}'"
            else
              l.err uerr = """
                Another ResourceConverter with `name: '#{rc.name}'` exists.
                Change its name, or use `-> @ '#{rc.name}'` to retrieve an existing instance and use it, update it etc"
              """
              throw new UError uerr
          else
            l.debug 30, "Instantiating & registering ResourceConverter from non-object format:", rc
            resourceConverters[rc.name] = rc

        else
          for regName, regRc of resourceConverters
            if rc is regRc
              l.err uerr = """
                The ResourceConverter instance with `name: '#{rc.name}' is registered with another `name '#{regName}'`.
                You must use the same name to update it.
                Alternativelly u can clone it (eg use `-> my_#{regName} = _.clone(@ '$#{regName}')` to retrieve
                an existing one and use it, update it, change its flags etc, but changing `my_#{rc.name}.name` before returning it."
              """
              throw new UError uerr

          l.debug 30, "Registering new ResourceConverter:", rc
          resourceConverters[rc.name] = rc

        if rc.isModule # isModule is DEPRACATED but still supported (till 0.5 ?)
          l.warn "DEPRACATED key 'isModule' found in ResourcesConverter with `name: '#{rc.name}'`. Use `type: 'module'` instead."
          rc.type = 'module'

        if rc.type
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

        # ammend convFilename function
        if _.isString rc.convFilename
          if rc.convFilename[0] is '~'
            rc.convFilename = rc.convFilename[1..]
            isSrcFilename = true

          if rc.convFilename[0] is '.'  # filename extension change if it starts with '.'.
                                        # By default it replaces `dstFilename`, with `~` flag it replaces `srcFilename`
            rc.convFilename =
              do (ext=rc.convFilename)->
                (dstFilename, srcFilename)->
                  upath.changeExt (if isSrcFilename then srcFilename else dstFilename), ext

          else # return a fn that returns the `convFilename` String
            rc.convFilename = do (filename=rc.convFilename)-> -> filename

        else
          if not (_.isFunction(rc.convFilename) or _.isUndefined(rc.convFilename))
            l.err uerr = "ResourceConverter error: `convFilename` is neither String|Function|Undefined."
            throw new UError uerr, nested:err

      rc



@stability: 2 - Unstable

@note *When two ore more files end up with the same `dstFilename`*, build halts. @todo: This should change in the future: when the same `dstFilename` is encountered in two or more resources/modules, it could mean Pre- or Post- conversion concatenation. Pre- means all sources are concatenated & then passed once to `convert`, or Post- where each resource is `convert`ed alone & but their outputs are concatenated onto that same `dstFilename`.


## Registering resourceConverters

We have an unordered `resourceConverters` {} registry with `name` as key & a ResourceCoverter instance as value.
Its populated with all RCs loaded, initially from master defaults followed by user defined ones.
The registry allows user defined RCs (as a function), to easily look up, instantiate, reuse or call functions of registered RCs.

    resourceConverters = {}

## Extra Resource Converters

We define some extra built-in RC-definitions for convenience. We add them to the registry by name, but we dont actually create their *proper* RC-instances unless they are needed (i.e used in a `resources` config) to save loading time.

    resourceConverters = {
      teacup: [
       '@~teacup'
       'Renders teacup nodejs modules (that export the plain template function), to HTML. FileResource means its source is not read/refreshed.'
       ['**/*.teacup']
       do ->
          require.extensions['.teacup'] = require.extensions['.coffee']     # register extension once
          teacup = require 'teacup'                                         # require once, avail through closure
          -> teacup.render @requireUncached "#{@srcRealpath}"               # return our `convert()` function
       '.html'
      ]
    }


    module.exports = {
      defaultResourceConverters       # used as is by [`bundle.resources`](uRequireConfigMasterDefaults.coffee#bundle.resources)
      getResourceConverterForObjectArrayOrFunction        # used by blendConfigs
    }

