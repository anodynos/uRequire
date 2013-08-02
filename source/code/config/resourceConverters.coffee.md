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

          convFilename: (srcFilename)->  # convert .js | .javascript to .js
            (require '../paths/upath').changeExt srcFilename, 'js'

          type: 'module'                 # not needed, since we have '$' flag to denote `type: 'module'`

          # these are defaults, you can ommit them
          isAfterTemplate: false
          isTerminal: false
          isMatchSrcFilename: false
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

How do we such flexibility with both [] & {} formats ?
@todo: getResourceConverter.coffee

### Extra Resource Converters

We have an unordered `resourceConverters` {} registry with `name` as key & a ResourceCoverter instance as value.
Its populated with all RCs loaded, initially from master defaults followed by user defined ones.
The registry allows user defined RCs (as a function), to easily look up, instantiate, reuse or call functions of registered RCs.

We define some extra built-in RC-definitions for convenience. We add them to the registry by name, but we dont actually create their *proper* RC-instances unless they are needed (i.e used in a `resources` config) to save loading time.

    _resourceConverters =

      teacup: [
         '@~teacup'
         'Renders teacup nodejs modules (that export the plain template function), to HTML. FileResource means its source is not read/refreshed.'
         ['**/*.teacup']
         do ->
            require.extensions['.teacup'] = require.extensions['.coffee']     # register extension once
            -> @requireUncached(@srcRealpath)()                               # return our `convert()` function

         '.html'
      ]


@stability: 2 - Unstable

@note *When two ore more files end up with the same `dstFilename`*, build halts. @todo: This should change in the future: when the same `dstFilename` is encountered in two or more resources/modules, it could mean Pre- or Post- conversion concatenation. Pre- means all sources are concatenated & then passed once to `convert`, or Post- where each resource is `convert`ed alone & but their outputs are concatenated onto that same `dstFilename`.



    module.exports = {
      defaultResourceConverters       # used as is by [`bundle.resources`](uRequireConfigMasterDefaults.coffee#bundle.resources)
      _resourceConverters
    }
