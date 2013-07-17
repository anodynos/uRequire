**Resource Converters (RC)** are compilers or converters or transpilers etc, that perform a conversion from one resource format (eg coffeescript, less) to another **converted** format (eg javascript, css).

**Resource Converters** is an evolving, generic workflow file source converions system, that is trivial to use and extend tp cater for all kind of
conversions. The workflow is build with the
following in mind:

  * *simple callback API* that enables any kind of conversion, even with *one-liners*.

  * focus to *in-memory conversions pipeline*, to save time loading & saving through the filesystem.

  * powerfull *only-when-needed* workflow, where each file is processed/converted only when it really needs to.

  * seamless integration with `bundle` & `build` paths, unobstrusivelly loading from and saving to the filesystem, with a lean config.

In [`bundle.resources`](uRequireConfigMasterDefaults.coffee#bundle.resources) all [`bundle.filez`](uRequireConfigMasterDefaults.coffee#bundle.filez) that are matched by one or more RCs are considered as **resources**.

Each *Resource Converter* (RC) has:

 * `name` a simple name eg. `'coffee-script'`. A `name` can have various flags at the start of this name - see below. @todo: `name` should be unique

 * `description` any optional details to keep the name smaller :-)

 * `filez` - a [`filez`](urequireconfigmasterdefaults.coffee#bundle.filez) spec of the files it deals with.

 * `convert` - a callback eg `function(resource){return convert(resource.source)}` that converts using some resource's data (eg `source`) to an in memory *converted* state or perform any other in memory or external conversion.
 The return of `convert()` is stored as `resource.converted` and its possibly converted again by a subsequent converter. Finally, if it ends up as non falsy, its saved automatically at `resource.dstFilepath` (which uses [`build.dstPath`](urequireconfigmasterdefaults.coffee#build.dstPath)) & `dstFilename` below.

 * `dstFilename` - a `function(srcFilename){return convertFn(srcFilename)}` that converts a *source* filename to its *destination* filename, eg `'file.coffee'-> 'file.js'`. If its a `String` starting with '.' (eg '.js'), its considered a simple extension replacement. If its a plain String its consedered as is.

 * flags `isTerminal`, `isAfterTemplate` & `isMatchSrcFilename` & `type` that can be easily defined via `name` flags - explained below.

Resource Converters are *attached* to the files of the bundle (those that match `filez`), the last one determining the class of created resource.

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

A converter is by default `isTerminal:true` and can denote it self as `isTerminal:false` in the object format or by using the name flag `'*'`.

### isAfterTemplate

A converter with `isAfterTemplate:true` (refers only to Module converters) will run after the module is converted through its template (eg 'UMD'). By default `isAfterTemplate:false`. Use the `'!'` name flag to denote `isAfterTemplate:true`.

### details & examples

@derive [ArrayizePush](urequireconfigmasterdefaults.coffee#tags-legend).

@optional unless you want to add resource converters for your *TypeScript*, *coco* or other conversion needs.

@type An Array<ResourceConverer>, where a `ResourceConverter` can be either an 'Object' or an 'Array' (for simpler descriptions). See @example below

@example Check the following code [(that is actually part of uRequire's code)](#Literate-Coffescript), that defines some default Resource Converters ('coffee-script', 'LiveScript', 'coco') marked as `type:'module' :

    _ = require 'lodash'
    _B = require 'uberscore'
    l = new _B.Logger 'urequire/config/ResourceConverters'
    upath = require '../paths/upath'

    RCs =

        # the 'Object' way to define a resource converter is an object like this:
        javascript: {
          name: '$JavaScript'            # '$' flag denotes `type: 'module'`.

          description: "I am a dummy js converter, I do nothing but mark `.js` files as Modules."

          filez: [                       # type like to `bundle.filez`, defines matching files, converted with this converter

            '**/*.js'                    # minimatch string (ala grunt's 'file' expand or node-glob)
                                         # RegExps work as well - use [..., `'!', /myRegExp/`, ...] to denote exclusion
            /.*\.(javascript)$/
          ]

          convert: -> @source            # javascript needs no compilation - just return source as is

          dstFilename: (srcFilename)->   # convert .js | .javascript to .js
            (require '../paths/upath').changeExt srcFilename, 'js'

          # these are defaults, you can ommit them
          isAfterTemplate: false
          isTerminal: false
          isMatchSrcFilename: false
          type: 'module'
        }

        # the alternative (& easier) 'Array' way of declaring a Converter: using an [] instead of {}
        coffeescript: [
          '$coffeescript'                                                   # name & flags as a String at pos 0
                                                                            # description at pos 1
          "Coffeescript compiler, using the locally installed 'coffee-script' npm package. Uses `bare:true`."

          [ '**/*.coffee', /.*\.(coffee\.md|litcoffee)$/i]                  # filez [] at pos 2

          ->(require 'coffee-script').compile @source, bare:true            # convert Function at pos 3

          (srcFn)->                                                         # dstFilename Function at pos 4
            ext = srcFn.replace /.*\.(coffee\.md|litcoffee|coffee)$/, "$1"  # retrieve matched extension, eg 'coffee.md'
            srcFn.replace (new RegExp ext+'$'), 'js'                        # replace it and teturn new filename
        ]

        # or shorter
        livescript: [
          '$livescript'
          [ '**/*.ls']                                                      # if pos 1 is Array, then there's no description
          ->(require 'LiveScript').compile @source, bare:true
          '.js']                                                            # if dstFilename is String starting with '.', it denotes an ext replacement of the srcFilename.

        # or the shortest ever, one-liner converter
        coco: [ '$coco', [ '**/*.ls'], (->(require 'coco').compile @source, bare:true), '.js']


We define an uBerscore _B.Blender here, cause it makes absolute sense to exactly define it here!

    resourceConverterBlender = new _B.DeepCloneBlender [
        order:['src']

        '[]': (prop, src)->
          r = src[prop]
          if _.isEqual r, [null]
            r # cater for [null] reset array signpost
          else
            if _.isString(r[1]) and                                       # possibly a `description` @ pos 1, if followed
              (_.isArray(r[2]) or _.isString(r[2]) or _.isRegExp(r[2]) ) # by what looks as `filez` at pos 2
                new ResourceConverter r[0],   r[1],       r[2],     r[3],      r[4]
            else                                                         # pos 1 is not a description, its a `filez`
              new ResourceConverter r[0],   undefined,    r[1],     r[2],      r[3]

        '{}': (prop, src)->
          r = src[prop]
          new ResourceConverter   r.name, r.description, r.filez, r.convert, r.dstFilename, r.type, r.isModule, r.isTerminal, r.isAfterTemplate, r.isMatchSrcFilename
    ]

    class ResourceConverter

      constructor: (@name, @description, @filez, @convert, @dstFilename, @type, isModule, @isTerminal, @isAfterTemplate, @isMatchSrcFilename)->
        while @name[0] in ['&','@', '#', '$', '~', '|', '*', '!']
          switch @name[0]
            when '&' then @type ?= 'bundle'
            when '@' then @type ?= 'file'
            when '#' then @type ?= 'text'
            when '$' then @type ?= 'module'
            when '~' then @isMatchSrcFilename ?= true
            when '|' then @isTerminal ?= true
            when '*' then @isTerminal ?= false # todo: delete '*' case - isTerminal = false is default
            when '!' then @isAfterTemplate ?= true
          @name = @name[1..] # remove 1st char

        if @type and (@type not in ['bundle', 'file', 'text', 'module'])
          l.err "resourceConverter.type '#{@type}' is invalid - will default to 'module'"

        if @isModule # isModule is DEPRACATED but still supported (till 0.5 ?)
          l.warn "DEPRACATED key 'isModule' found in `resources` converter '#{name}'. Use `type: 'module'` instead."
          @type = 'module'

        @isTerminal ?= false
        @isAfterTemplate ?= false
        @isMatchSrcFilename ?= false

        if _.isString @dstFilename
          if @dstFilename[0] is '.' # filename extension change if it starts with '.'
            @dstFilename = do (ext=@dstFilename)-> (srcFilename)-> upath.changeExt srcFilename, ext
          else # return a fn that returns the `dstFilename` String
            @dstFilename = do (dstFilename=@dstFilename)-> -> dstFilename

        # {name, filez, convert, dstFilename, type, isTerminal, isAfterTemplate, isMatchSrcFilename}

@stability: 2 - Unstable

@note when two ore more files end up with the same `dstFilename`, build halts.

@todo uRequire `bundle.resources` aims to power a streamlined conversion process. More functionality is need towards this aim :

* flexible in memory pipelines, where to go next etc.

* When the same `dstFilename` is encountered in two or more resources/modules, it could mean pre or post conversion concatenation: either all sources are concatenated & then passed to `convert`, or each resource is `convert`ed alone & their outputs are concatenated onto `dstFilename`.


Blend all default resource converters to their 'proper' Object format.

    for key, rc of RCs
      RCs[key] = resourceConverterBlender.blend {}, rc

    module.exports = {RCs, resourceConverterBlender}
