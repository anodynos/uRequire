*** WARNING: Work In Progress - version 0.4.0beta2 ***

# Introduction

The *master & defaults* configuration file of *uRequire*.

## Literate Coffescript

This file is written in [Literate Coffeescript](http://ashkenas.com/literate-coffeescript): it serves both as *markdown documentation* AND the *actual code* that represents the *master config*. The code blocks shown, are the actual code used at runtime, i.e each key declares its self and sets a default value.

    module.exports = uRequireConfigMasterDefaults =

## Config Usage

A config determines a `bundle` and a `build` that uRequire will process. It can be used as:

* A node module that exports a config object (eg `myConfig.coffee|js`) or a `.json` file, as well as many other formats - see [butter-require](https://github.com/anodynos/butter-require).

* Using [grunt-urequire](https://github.com/aearly/grunt-urequire), having almost the exact config as a `urequire` task. @todo: diffs ?

@todo: doc it better

## Deriving

A config can _inherit_ the values of a parent config, in other words it can be _derived_ from it. Its similar to how a subclass *overrides* a parent class (but much more flexible. @todo: explain why).

For example if you have `DevelopementConfig` derived from a parent `ProductionConfig`, then the first one (the child) will inherit all the values/defaults and perhaps override (or ammend, append etc) the values of the second (the parent).

Ultimately all configs are derived from `uRequireConfigMasterDefaults` (this file) which holds all default values.

## @tags legend

* @derive: describes how values are derived from other parent configs. Some *standard* derivations are listed here:

   * *ArrayizePush*:
   Child items (on derived configs) are appended *after* the ones higher up.
   The types for both src & dst are either `Array<Anything>` or `Anything` (but Array) which is arrayized first. To reset the inherited array, use `[null]` as the 1st item of your child array.

   * *ArrayizeUniquePush*: Just like *ArrayizePush*, but only === unique items are pushed.

* @stability: (1-5) a [nodejs-like stability](http://nodejs.org/api/documentation.html#documentation_stability_index) of the setting. If not stated, its assumed to be a "3 - Stable".

* @optional - setting this key is optional, unless otherwise specified.

* @todo: this file is documentation & code. todos are part of any code!

* @type The valuetypes that are valid - usually there is a lot of flexibility of the types of values you can use.

* @alias usually DEPRACATED (but still supported) ones.

* @note Any other note that requires attention

## bundle & build

**uRequire config** has 2 top-level keys/hashes: `bundle` and `build`. All related information is nested bellow these two keys.

**@note: user configs (especially simple ones) can safely omit `bundle` and `build` hashes and put the keys belonging on either on the 'root' of their config object. uRequire safely recognises where keys belong, even if they're not in `bundle`/`build`.**

_______
# bundle

The `bundle` hash defines what constitutes a bundle, i.e where files are located, which ones are converted etc. Consider a `bundle` as the 'source' to the `build` process that follows.

    bundle:

## bundle.name

The *name* of the bundle, eg 'MyLibrary'.

@optional

@note When using [grunt-urequire](https://github.com/aearly/grunt-urequire), it *defaults* to the multi-task `@target`. So with grunt config `{urequire: 'MyBundlename': {bundle : {name:undefined}, build:{} }}`, `bundle.name` will default to `'MyBundlename'`.

@note: `bundle.name` serves as the 1st default for `bundle.main` (if main is not explicit).

      name: undefined

## bundle.main

The `'main'` or `'index'` module file of your bundle, that `require`s and kicks off all other modules (perhaps implicitly).

@optional and useless, unless 'combined' template is used. 

### Details:
* `bundle.main` is used as 'name' / 'include' on RequireJS build.js, on combined/almond template.

*  It should be the 'entry' point module of your bundle, where all dependencies are `require`'d. Then **r.js** recursivelly adds all dependency tree to the 'combined' optimized file.

* It is also used to as the initiation `require` on your combined bundle.
  It is the module just kicks off the app and/or requires all your other library modules.

* Defaults to `bundle.name`, `'index'`, `'main'`: If `bundle.main` is missing, it defaults to `bundle.name`, *only* if there is a module by that name. If `bundle.name` fails to match an existing module, `'index'` or `'main'` are used as `bundle.main` (again provided there is a module named `'index'` or `'main'` - which ever found first). In all cases of automatic discovery, uRequire will issue a warning.

If `bundle.main` can't match an existing module, it will cause a `'combined'` template error. 

      main: undefined

## bundle.path

The file system path where source bundle files reside.

@example `'./source/code'`

@note If `bundle.path` is ommited, it is implied by the first config's file position (if the config is file-based i.e not [grunt-urequire](https://github.com/aearly/grunt-urequire)).

@alias `bundlePath` DEPRACATED

      path: undefined

## bundle.filez

All files that participate in the `bundle` are specified here.

Each matching file is considered to be either:

* _BundleFile_ - any file (even binary) that is not processed, but can be easily copied over via `bundle.copy` (eg. when changed on 'watch').

* _Resource_ - any textual resource that we want to convert to something else: eg '.coffee'->'.js', or '.less'->'.css'

* _Module_ - A Resource that is also a Module whose Dependencies we monitor and convert through some template.

`Resource` & `Module` are only those that matched in [`bundle.resources`](urequireconfigmasterdefaults.coffee#bundle.resources). All those matching only `bundle.filez` are considered `BundleFile`s.

@type filename specifications (or simply filenames), expressed in either:

  * *gruntjs*'s expand minimatch format (eg `'**/*.coffee'`) and its exclusion cousin (eg `'!**/DRAFT*.*'`)
  
  * `RegExp`s that match filenames (eg `/./`) again with a `[...'!', /regexp/]` exclusion pattern.

@example `bundle: {filez: ['**/recources/*.*', '!dummy.json', /\.someExtension$/i ]}`

@note the `z` in `filez` is used to segragate from gruntjs `files`, when urequire is used within [grunt-urequire](https://github.com/aearly/grunt-urequire) and allow its different features like RegExp & deriving.

@derive: [ArrayizePush](urequireconfigmasterdefaults.coffee#tags-legend).

@note: The master default is `undefined`, so the highest `filez` in derived hierarchy determines what is ultimately allowed.

@alias `filespecs` DEPRACATED

@default: NOTE: The actual default (runtime hard-coded), if no `filez` exists in the final cfg, is `['**/*.*']` (and not `undefined`).

      filez: undefined

## bundle.copy

Copy (binary) of all non-resource [`BundleFile`](urequireconfigmasterdefaults.coffee#bundle.filez)s to [`dstPath`](urequireconfigmasterdefaults.coffee#build.dstpath) as a convenience. When [`build.watch`](urequireconfigmasterdefaults.coffee#build.watch) is used, it monitors file size & timestamp and copies (overwrites) changed files.

@example `copy: ['**/images/*.gif', '!dummy.json', /\.(txt|md)$/i ]`

@type see [`bundle.filez`](urequireconfigmasterdefaults.coffee#bundle.filez) 

@derive [ArrayizePush](urequireconfigmasterdefaults.coffee#tags-legend).

@alias `copyNonResources` DEPRACATED

@default `[]`, no non-resource files are copied. You can use `/./` for all non-resource/non-module files to be copied to dstPath.

      copy: []

## bundle.resources

Defines an array of text-based resource converters (eg compilers), that perform an in-memory workflow conversion from a resource format (eg coffeescript, less) to another compiled format (eg javascript, css).

Each resource converter has:

 * `name` a simple name eg. `'coffee-script'`

 * `filez` - a [`filez`](urequireconfigmasterdefaults.coffee#bundle.filez) spec of the files it deals with.

 * `converter` - a `function(src){return convert(src)}` that converts resource's *source* text to *converted*.

 * `dstFilename` - a `function(fn){return convertFn(fn)}` that converts a source filename to its destination, eg `'file.coffee'-> 'file.js'`.

### resource types 

Each resource converter can deal with either: 

  * a *textual/utf-8* **Resource**, eg a .css file, denoted either with a `isModule:false` or via a `'!'` flag preceding its name eg `name:'!less'`. Key has precedence.

  * a **Module**, which is *javascript code* with node/commonjs `require` or AMD style `define`/`require` dependencies. Each module is converted just like a *textual/utf-8* **Resource**, but its dependencies come into play and ultimately it is converted through the chosen [`template`](urequireconfigmasterdefaults.coffee#build.template). Its is again denoted either via key `isModule:true` or via a lack of `'!'` flag preceding name (key has precedence).
  
### final 
Each resource converter can denote it self as `isFinal:true` (or use a flag `'*'`). For `isFinal:true` converters, uRequire will not go through subsequent resource converters (i.e only the first matching resource converter will be used).

@derive [ArrayizePush](urequireconfigmasterdefaults.coffee#tags-legend).

@optional unless you want to add resource converters for your *TypeScript*, *coco* or other conversion needs.

@type An Array<ResourceConverer>, where a `ResourceConverter` can be either an Object or an Array (for simpler descriptions). Check the following code [(that is actually part of uRequire)](#Literate), that defines some basic text resource converters:

      resources: [ # an array of resource converters

        # the 'proper' way to define a resource converter is an object like this:
        {
          name: '*Javascript'         # '*' flag denotes non-terminal.
                                      # Default is terminal, which means no other (subsequent) resource converters will be visited.

          filez: [                    # similar to `bundle.filez`, defines what files are converted with this converter
            '**/*.js'                 # minimatch string (ala grunt's 'file' expand or node-glob)
            /.*\.(javascript)$/i      # a RegExp works as well - use [..., `'!', /myRegExp/`, ...] to denote exclusion
          ]

          convert: (source, filename)-> source  # javascript needs no compilation - just return source as is

          dstFilename: (filename)->             # convert .js | .javascript to .js
            (require '../paths/upath').changeExt filename, 'js'
        }

        # the alternative (& easier) way of declaring a Converter: using an [] instead of {}
        [
          '*coffee-script'                                 # name at pos 0

          [ '**/*.coffee', /.*\.(coffee\.md|litcoffee)$/i] # filez at pos 1

          (source, srcFilename)->                          # convert function at pos 2
            (require 'coffee-script').compile source, bare:true

          (srcFilename)->                                  # dstFilename function at pos 3
            ext = srcFilename.replace /.*\.(coffee\.md|litcoffee|coffee)$/, "$1"  # retrieve matched extension, eg 'coffee.md'
            srcFilename.replace (new RegExp ext+'$'), 'js'                        # replace it and teturn new filename
        ]

        # or in short
        [ '*LiveScript', [ '**/*.ls']
          (source)-> (require 'LiveScript').compile source, bare:true
          (srcFilename)-> srcFilename.replace /(.*)\.ls$/, '$1.js' ]
      ]

@note when two ore more files end up with the same `dstFilename`, build halts.


@stability: 2 - Unstable

@todo A lot of work has to be done for uRequire resources to become a serious conversion toolkit :
* in memory pipelines, where to go next etc.
* equal `dstFilename` for two or more resources/modules, could mean pre or post conversion concatenation: either all sources are concatenated & then converted, or each resource is converted alone & their outputs are concatenated onto `dstFilename`.


## bundle.webRootMap

For dependencies that refer to webRoot (eg `'/libs/myLib'`), it maps `/` to a directory on the file system **when running in nodejs**. When running on Web/AMD, its the **http-server's root**.

Can be absolute or relative to [`bundle.path`](urequireconfigmasterdefaults.coffee#bundle.path). - it defaults to bundle.

@example "/var/www" or "/../../fakeWebRoot"

      webRootMap: '.'

## bundle.dependencies

Anything related to dependenecies is listed here.

      dependencies:

### bundle.dependencies.depsVars

Global dependencies (eg 'underscore') are by default not part of a `combined` file. Each global dep has one or more variables it is exported as, eg `jquery: ["$", "jQuery"]`. At run time, when running on web side, your script will _load_ the dependency from the global object, using the exported global variable. 

Variable names can be infered from the code by uRequire , when you used this binding implicitly (AMD only for now), for example `define ['jquery'], ('$')->`. You can choose to list them here to be precise.

@note In case they can't be identified from modules (i.e you solely use 'nodejs' format), and aren't in `bundle.dependencies.depsVars`, 'combined/almond' build will fail.

        depsVars: {}

### bundle.dependencies._knownDepsVars

Some known depsVars, have them as backup!

@todo: provide some 'common/standard' ones.

        _knownDepsVars:
          chai: 'chai'
          mocha: 'mocha'
          lodash: "_"
          underscore: "_"
          jquery: ["$", "jQuery"]
          backbone: "Backbone"
          knockout: ["ko", 'Knockout']

### bundle.dependencies.exports

Holds keys related to binding and exporting modules (i.e making them available to other modules, via a variable name)

        exports:

#### bundle.dependencies.exports.bundle

Each dep will be available in the *whole bundle* under varName(s) - they are global to your bundle.

@type
* `['dep1', 'dep2']` (with varnames looked up in [`bundle.dependencies.depsvars`](urequireconfigmasterdefaults.coffee#bundle.dependencies.depsvars))

* `{ dependency1: [varName1, varName2], ...}`

@example `{'underscore': '_', 'jquery': ["$", "jQuery"], 'models/PersonModel': ['persons', 'personsModel']}`

          bundle: {}

#### bundle.dependencies.exports.root

Each dep listed will be available GLOBALY under varName(s) - @note: works in browser only - attaching to `window`.

@example `{'models/PersonModel': ['persons', 'personsModel']}` is like having a `{rootExports: ['persons', 'personsModel']}` in 'models/PersonModel' module.

*@todo: NOT IMPLEMENTED - use module `{rootExports: [...]}` format in the modules you need root exports..*

          root:{}

### bundle.dependencies.replaceTo

Replace all right hand side dependencies (String value or []<String> values), to the left side (key).

@example `lodash: ['underscore']` replaces all 'underscore' deps to 'lodash' in the build files.

*@todo: NOT IMPLEMENTED*

        replaceTo: undefined

_______
# Build

The `build` hash holds keys that define the conversion, such as *where* and *what* to output.

    build:

## build.dstPath

Output converted files onto this 

* directory
* filename (if combining)
* function @todo: function NOT IMPLEMENTED

@example 'build/code'

@alias `outputPath` DEPRACATED

      dstPath: undefined


## build.forceOverwriteSources

Output on the same directory as source `bundle.path`, overwriting all files. Useful if your sources are not *real sources*.

WARNING: when true, [build.dstPath](urequireconfigmasterdefaults.coffee#build.dstPath) is ignored.

      forceOverwriteSources: false

## build.template

A string in ['UMD', 'AMD', 'nodejs', 'combined'] 

@see *Conversion Templates* in docs.

      template: 'UMD'

## build.watch

Watch for changes in bundle files and reprocess/re output *only* those changed files.

The *watch feature* of uRequire works with:

* Standalone urequireCmd, setting `watch: true` or -w flag.

* Instead of `watch:true`, you use [grunt-urequire >=0.4.4](https://github.com/aearly/grunt-urequire) & [grunt-contrib-watch >=0.4.4](https://github.com/gruntjs/grunt-contrib-watch). 

      watch: false

## build.noRootExports

When true, it ignores all rootExports {& noConflict()} defined in all module files (eg `{rootExports: ['persons', 'personsModel']}` in top of 'mymodule.js'.

@note Useful only on Web side and rootExports are used.

### Usage

* A value of 'true' doesn't force to ignore root exports declared in  `dependencies.exports.root`, @todo: when `exports.root` is implemented :-)

* Use `'bundle'` instead of `true` to ignore those defined in `bundle.exports.root` @todo: NOT IMPLEMENTED

* Use 'all' to ignore all root exports @todo: NOT IMPLEMENTED

      noRootExports: false

## build.scanAllow

By default, ALL require('') deps appear on [] to prevent RequireJS to scan @ runtime.

With `scanAllow:true` you can allow `require('')` scan @ runtime, for source modules that have no other [] deps (i.e. using nodejs source modules or using only require('') instead of the dependencies array.

@note: modules with rootExports / noConflict() always have `scanAllow: false`

      scanAllow: false

## build.allNodeRequires

Pre-require all deps on node, even if they aren't mapped to any  parameters, just like in AMD deps []. Hence it preserves the same loading order as on Web/AMD, with a trade off of a possible slower starting up (they are cached nevertheless, so you gain speed later).

      allNodeRequires: false

## build.verbose
Print bundle, build & module processing information.

@type: Boolean

      verbose: false

## build.debugLevel
Debug levels *1-100*.

      debugLevel: 0

## build.continue

Dont bail out while processing when there are **module processing errors**.

For example ignore a coffeescript compile error, and just do all the other modules. Or on a `combined` conversion when a 'global' has no 'var' association anywhere, just hold on, ignore this global and continue.

@note: Not needed when `watch` is used.

      continue: false

## build.optimize

Optimizes output files (i.e it minifies/compresses them for production).

@options

* *false*: no optimization (r.js build.js optimize: 'none')

* *true*: uses sane defaults of 'uglify2' to minify through r.js

* 'uglify' / 'uglify2': specifically select either with their r.js default settings.

* [r.js optimize object] like ['uglify'](https://github.com/jrburke/r.js/blob/f021df4d2b68/build/example.build.js#L138-154) or ['uglify2'](https://github.com/jrburke/r.js/blob/f021df4d2b68/build/example.build.js#L161-176) for example `optimize: {uglify2: output: {beautify: true}, compress: {...}, warnings: true}`

@todo: PARTIALLY IMPLEMENTED - Only working for `combined` template, delegating the option to `r.js`. 

      optimize: false
      _optimizers: ['uglify2', 'uglify']

## build.done

This is set by either *urequireCMD* or [grunt-urequire](https://github.com/aearly/grunt-urequire) to signify the end of a build - dont use it!

      done: (doneVal)-> console.log "done() is missing and I got a #{doneVal} on the default done()"