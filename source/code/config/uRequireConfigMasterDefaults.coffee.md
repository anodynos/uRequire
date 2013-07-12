# Introduction

The *master & defaults* configuration file of *uRequire*.

## Literate Coffescript

This file is written in [Literate Coffeescript](http://ashkenas.com/literate-coffeescript): it serves both as *markdown documentation* AND the *actual code* that represents the *master config*. The code blocks shown are the actual code used at runtime, i.e each key declares its self and sets a default value.

    module.exports = uRequireConfigMasterDefaults =

NOTE: This file primary location is https://github.com/anodynos/uRequire/blob/master/source/code/config/uRequireConfigMasterDefaults.coffee.md & copied over to the urequire.wiki - DONT edit it separatelly in the wiki.

## Config Usage

A `config` determines a `bundle` and a `build` that uRequire will process. A config is an object with the expected keys and can be used as:

* **File based**, using the urequire CLI (from `npm install urequire -g`) as `$ urequire config myConfig.js`, where `myConfig.js` is a node module file that exports the `config` object. The file can actually be a `.coffee` or `.js` node module, or a `.json` file as well as many other formats - see [butter-require](https://github.com/anodynos/butter-require).

* Using [**grunt-urequire**](https://github.com/aearly/grunt-urequire), having (almost) the exact `config` object of the file-base, but as a `urequire` grunt task. @todo: diffs ?

* Within your tool's code, [using `urequire.BundleBuilder`](Using-uRequire#Using-within-your-code).

@todo: doc this better

## Versatility

uRequire configs are extremelly versatile:

* it understands keys both in the 'root' of your config *OR* in ['bundle'/'build' hashes](uRequireConfigMasterDefaults.coffee#bundle-build)

* it provides shortcuts, to convert simple declarations to more complex ones.

* it has a unique inheritance scheme for 'deriving' from parent configs.

## Deriving

A config can _inherit_ the values of a parent config, in other words it can be _derived_ from it. Its similar to how a subclass *overrides* a parent class (but much more flexible. @todo: explain why).

For example if you have a child `DevelopementConfig` derived from a parent `ProductionConfig`, then the child will inherit all the values/defaults and perhaps override (or ammend, append etc) the values of the parent. A child can inherit from one or more Parents, with precedence given to whichever parent comes first.

Ultimately all configs are derived from `uRequireConfigMasterDefaults` (this file) which holds all default values.

## @tags legend

Each key description might have some of these tags:

* @derive: describes how values are derived from other parent configs. Some *standard* derivations are listed here:

   * *ArrayizePush*:
   Child items (on derived configs) are appended *after* the ones higher up.
   The types for both src & dst are either `Array<Anything>` or `Anything` (but Array) which is arrayized first. To reset the inherited array, use `[null]` as the 1st item of your child array.

   * *ArrayizeUniquePush*: Just like *ArrayizePush*, but only === unique items are pushed.

* @stability: (1-5) a [nodejs-like stability](http://nodejs.org/api/documentation.html#documentation_stability_index) of the setting. If not stated, its assumed to be a "3 - Stable".

* @optional - setting this key is optional, unless otherwise specified.

* @todo: this file is documentation & code. `@todo`s should be part of any code and a great chance to highlight future directions! Also watch out for **NOT IMPLEMENTED** features - its still v0.4.0!

* @type The value types that are valid - usually there is a lot of flexibility of the types of values you can use.

* @alias usually DEPRACATED (but still supported) ones.

* @note Any other note that requires attention

## bundle & build

**uRequire config** has 2 top-level keys/hashes: `bundle` and `build`. All related information is nested bellow these two keys.

**@note: user configs (especially simple ones) can safely omit `bundle` and `build` hashes and put the keys belonging on either on the 'root' of their config object. uRequire safely recognises where keys belong, even if they're not in `bundle`/`build`.**

_______
# bundle

The `bundle` hash defines what constitutes a bundle, i.e where files are located, which ones are converted etc. Consider a `bundle` as the 'source' or the 'package' that is then processed or build, based on the `build` part of the config.

    bundle:

## bundle.name

The *name* of the bundle, eg 'MyLibrary'.

@optional

@note When using [grunt-urequire](https://github.com/aearly/grunt-urequire), it *defaults* to the multi-task `@target`. So with grunt config `{urequire: 'MyBundlename': {bundle : {name:undefined}, build:{} }}`, `bundle.name` will default to `'MyBundlename'`.

@note: `bundle.name` serves as the 1st default for `bundle.main` (if main is not explicit).

@alias `bundleName` DEPRACATED

      name: undefined

## bundle.main

The `'main'` or `'index'` module file of your bundle, that `require`s and kicks off all other modules (perhaps implicitly).

@optional and useless, unless 'combined' template is used. 

### Details:
* `bundle.main` is used as 'name' / 'include' on RequireJS build.js, on combined/almond template.

*  It should be the 'entry' point module of your bundle, where all dependencies are `require`'d. Then **r.js** recursively adds all dependency tree to the 'combined' optimized file.

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

* _BundleFile_ - any file (even binary) that is not really processed, but for convinience can be copied to [`build.dstPath`](urequireconfigmasterdefaults.coffee#build.dstpath) via [`bundle.copy`](urequireconfigmasterdefaults.coffee#bundle.copy) at each build (or partial build eg on 'watch', when filesize/timestamp changes).

* _Resource_ - any textual resource that we want to convert to something else: eg `.coffee`->`.js`, or `.less`->`.css`

* _Module_ - A Module is like a _Resource_, but its also a Javascript Module whose Dependencies we monitor and as the last build step we convert it through the [`build.template`](urequireconfigmasterdefaults.coffee#build.template). A Module is ultimately JavaScript code, that is perhaps expressed is some other compiled-to-js language like Coffeescript.

`Resource` & `Module` are only those files that matched in [`bundle.resources`](urequireconfigmasterdefaults.coffee#bundle.resources). All those matching `bundle.filez` but not [`bundle.resources`](urequireconfigmasterdefaults.coffee#bundle.resources) are considered `BundleFile`s.

@type filename specifications (or simply filenames), expressed in either:

  * *gruntjs*'s expand minimatch format (eg `'**/*.coffee'`) and its exclusion cousin (eg `'!**/DRAFT*.*'`)
  
  * `RegExp`s that match filenames (eg `/./`) again with a `[...'!', /regexp/]` exclusion pattern.

@example `bundle: {filez: ['**/recources/*.*', '!dummy.json', /\.someExtension$/i ]}`

@note the `z` in `filez` is used to segragate from gruntjs `files`, when urequire is used within [grunt-urequire](https://github.com/aearly/grunt-urequire) and allow its different features like RegExp & deriving.

@derive: [ArrayizePush](urequireconfigmasterdefaults.coffee#tags-legend).

@note: The master default is `undefined`, so the highest `filez` in derived hierarchy determines what is ultimately allowed.

@alias `filespecs` DEPRACATED (with different semantics)

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

Defines an array of text-based **Resource Converters (RC)** (eg compilers, converters etc), that perform a conversion from a resource format
(eg coffeescript, less) to another **converted** format (eg javascript, css).

All files that are matched by one or more RCs are considered as **resources**.

**Resource Converters** can work either as in-memory workflow or as an external file system based conversion.

Each RC has:

 * `name` a simple name eg. `'coffee-script'`. A `name` can have various flags at the start of this name - see below. @todo: `name` should be unique

 * `filez` - a [`filez`](urequireconfigmasterdefaults.coffee#bundle.filez) spec of the files it deals with.

 * `convert` - a callback eg `function(resource){return convert(resource.source)}` that converts using some resource's data (eg `source`) to an in memory *converted* state or perform any other in memory or external conversion.
 The return of `convert()` is stored as resource.converted and its possibly converted again by a subsequent converter. Finally, if its not falsy, its saved automatically at resource.dstFilepath (which uses [`build.dstPath`](urequireconfigmasterdefaults.coffee#build.dstPath)) & `dstFilename` below.

 * `dstFilename` - a `function(srcFilename){return convertFn(srcFilename)}` that converts a *source* filename to its *destination* filename, eg `'file.coffee'-> 'file.js'`. If its a `String` (eg '.js'), its considered a simple extension replacement.

 * and flags `isTerminal`, `isAfterTemplate` & `isMatchSrcFilename` & `type` that can be easily defined via `name` flags - explained below.

Resource Converters are *attached* to the files of the bundle (those that match `filez`), the last one determining the class of resource.

### resource `clazz` & `type`

The `type` is user set among ['module', 'text', 'file'] - the default being `'module'`.
A resource converter's `type` marks each matching file's clazz either as a `Module`, a `TextResource` or a `FileResource` (but only the last one matters!)

#### FileResource

An external file whose contents we need to know nothing of (but we can if we want). At each conversion, the `convert()` is called, passing a `FileResource` instance with fields (from `BundleFile`) like `srcFilename`, `srcFilepath`, `dstFilepath` & also `fileStats` etc for convenience.

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

@example Check the following code [(that is actually part of uRequire)](#Literate-Coffescript), that defines some basic text resource converters ('coffee-script' & 'LiveScript'):

      resources: [ # an array of resource converters

        # the 'Object' way to define a resource converter is an object like this:
        {
          name: 'Javascript'         # '*' flag denotes isTerminal:false.
                                      # Default `isTerminal:true`, which means no other (subsequent) resource converters will be visited.

          filez: [                    # type like to `bundle.filez`, defines matching files, converted with this converter

            '**/*.js'    # minimatch string (ala grunt's 'file' expand or node-glob)

                         # a RegExp works as well - use [..., `'!', /myRegExp/`, ...] to denote exclusion
            /.*\.(javascript)$/
          ]

          convert: (resource)-> resource.source  # javascript needs no compilation - just return source as is

          dstFilename: (filename)->             # convert .js | .javascript to .js
            (require '../paths/upath').changeExt filename, 'js'

          # these are defaults, you can ommit them
          isAfterTemplate: false
          isTerminal: false
          isMatchSrcFilename: false
          type: 'module'
        }

        # the alternative (& easier) 'Array' way of declaring a Converter: using an [] instead of {}
        [
          'coffee-script'                      # name & flags as a String at pos 0

          [ '**/*.coffee', /.*\.(coffee\.md|litcoffee)$/i] # filez [] at pos 1

          (resource)->                          # convert Function at pos 2
            (require 'coffee-script').compile resource.source, bare:true

          (srcFilename)->                                  # dstFilename Function at pos 3
            ext = srcFilename.replace /.*\.(coffee\.md|litcoffee|coffee)$/, "$1"  # retrieve matched extension, eg 'coffee.md'
            srcFilename.replace (new RegExp ext+'$'), 'js'                        # replace it and teturn new filename
        ]

        # or in short
        [ 'LiveScript', [ '**/*.ls']
          (resource)-> (require 'LiveScript').compile resource.source, bare:true
          '.js'] # if dstFilename is a String, it denotes an extension change in the of srcFilename
      ]

@stability: 2 - Unstable

@note when two ore more files end up with the same `dstFilename`, build halts.

@todo uRequire `bundle.resources` aims to power a streamlined conversion process. More functionality is need towards this aim :

* flexible in memory pipelines, where to go next etc.

* When the same `dstFilename` is encountered in two or more resources/modules, it could mean pre or post conversion concatenation: either all sources are concatenated & then passed to `convert`, or each resource is `convert`ed alone & their outputs are concatenated onto `dstFilename`.

## bundle.webRootMap

For dependencies that refer to web's root (eg `'/libs/myLib'`), it maps `/` to a directory on the file system **when running in nodejs**. When running on Web/AMD, RequireJS maps it to the **http-server's root** by default.

`webRootMap` can be absolute or relative to [`bundle.path`](urequireconfigmasterdefaults.coffee#bundle.path). - it defaults to bundle.

@example "/var/www" or "/../../fakeWebRoot"

@note `webRootMap` is not (yet) working with `combined` template.

      webRootMap: '.'

## bundle.dependencies

Information related to dependenecies handling is listed here.

      dependencies:

### bundle.dependencies.node

Dependencies listed here are treated as node-only, hence they aren't added to the AMD dependency array (and hence not available on the Web/AMD side). Its the same as using the `node!` fake plugin, eg `require('node!my_fs')`, but probably more useful cause your code can execute on nodejs without conversion that strips 'node!'.

By default no known node packages like `'util'`, `'fs'` etc are part of `bundle.dependencies.node`, but this may change in future releases and include them all.

@type String or Array<String>

@derive [ArrayizeUniquePush](urequireconfigmasterdefaults.coffee#tags-legend).

@example `node: ['myutil', 'my_fs']`

@todo: all built-in node packages should be the default eg `node: ['util', 'fs', 'http', 'path', 'child_process', 'events' ...etc ]`. Can lead to inadvertized feature leak if someone has a module under these names - just issue a warning ?

@alias noWeb DEPRACATED

        node: []

### bundle.dependencies.depsVars

Global dependencies (eg 'underscore') are by default not part of a `combined` file. Each global dep has one or more variables it is exported as, eg `jquery: ["$", "jQuery"]`. At run time, when running on web side as a standalone .js <script/>, the script will _load_ the dependency from the global object, using the exported global variable(s).

Variable names can be infered from the code by uRequire, when you used this binding implicitly (AMD only for now), for example `define ['jquery'], ('$')->` binds variable `$` with dependency `'jquery'`. You can choose to list them here to be precise.

@type `{ dependency1: ['varName1', 'varName2'], dep2:[..], ...}`

@derive Each dependency name/key of child configs is added to the resulted object, if not already there. Its variables are then [ArrayizeUniquePush](urequireconfigmasterdefaults.coffee#tags-legend) onto the existing array. For example for child `{myDep1: ['myDep1Var1', 'myDep1Var3'], myDep2: 'myDep2Var'}` with parent `{myDep1: ['myDep1Var1', 'myDep1Var2']}` the result derived object will be `{myDep1: ['myDep1Var1', 'myDep1Var2', 'myDep1Var3'], myDep2: ['myDep2Var']}`.

@note In case variable names can't be identified from modules (i.e you solely use 'nodejs' format), and aren't in `bundle.dependencies.depsVars`, 'combined/almond' build will fail.

@alias variableNames DEPRACATED

        depsVars: {}

### bundle.dependencies._knownDepsVars

Some known depsVars, have them as backup - its a private field, not meant to be extended by users (use .

@type see [`bundle.dependencies.depsVars`](urequireconfigmasterdefaults.coffee#bundle.dependencies.depsVars)

@alias _knownVariableNames DEPRACATED

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

Allows you to export (i.e have available) modules throughout the bundle.

Each dependency will be available in the *whole bundle* under varName(s) - i.e they will be like *globals* to your bundle. Effectively this means that each module will have an *injection* of all `dependencies.exports.bundle` dependencies/var bindings, so you don't have to list them in each module.

@type either :

* like [`bundle.dependencies.depsVars`](urequireconfigmasterdefaults.coffee#bundle.dependencies.depsVars)

* `['dep1', 'dep2']` with varnames looked up in [`bundle.dependencies.depsVars`](urequireconfigmasterdefaults.coffee#bundle.dependencies.depsVars)) or discovered by your module declarations.

@derive see [`bundle.dependencies.depsVars`](urequireconfigmasterdefaults.coffee#bundle.dependencies.depsVars)

@example `{'underscore': '_', 'jquery': ["$", "jQuery"], 'models/PersonModel': ['persons', 'personsModel']}` will make ALL modules in the bundle have `_`, `$`, `jQuery`, `persons` and `personsModel` variables injected.

@alias `bundleExports` DEPRACATED

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

The `build` hash holds keys that define the conversion or `build` process, such as *where* to output, *how* to convert etc.

    build:

## build.dstPath

Output converted files onto this 

* directory

* filename (if `combined` template is used)

* function @todo: function NOT IMPLEMENTED

@example `'build/code'` or `'build/dist/myLib-min.js'`

@alias `outputPath` DEPRACATED

      dstPath: undefined


## build.forceOverwriteSources

Output on the same directory as the _source_ [`bundle.path`](urequireconfigmasterdefaults.coffee#bundle.path), overwriting all files. Useful if your sources are not *real sources*.

@note: Be warned that when `true`, [build.dstPath](urequireconfigmasterdefaults.coffee#build.dstPath) is ignored and always takes the value of [`bundle.path`](urequireconfigmasterdefaults.coffee#bundle.path).

      forceOverwriteSources: false

## build.template

A string in [Build.templates](https://github.com/anodynos/uRequire/blob/master/source/code/process/Build.coffee) = ['UMD', 'AMD', 'nodejs', 'combined']

@see *Conversion Templates* in docs.

      template: 'UMD'

## build.watch

Watch for changes in bundle files and reprocess/re output *only* those changed files.

The *watch feature* of uRequire works with:

* Standalone urequireCmd, setting `watch: true` or -w flag.

* Instead of `watch:true`, you use [grunt-urequire >=0.4.4](https://github.com/aearly/grunt-urequire) & [grunt-contrib-watch >=0.4.4](https://github.com/gruntjs/grunt-contrib-watch).

@note at each `watch` event there is a *partial build* carried out. You are advised to have a full build (eg run the `urequire:xxx` grunt task before running `watch: xxx: tasks: ['urequire:xxx']`) within the same invocation of grunt (eg run `grunt urequire:xxx watch:xxx`) so that all modules & their dependencies are loaded. In some cases (eg `combined` template) a full build is enforced by urequire.

      watch: false

## build.noRootExports

When true, it ignores all rootExports {& noConflict()} defined in all module files (eg `{rootExports: ['persons', 'personsModel']}` in top of 'mymodule.js'.

@note Useful only on Web side and rootExports are used.

### Usage

* A value of 'true' doesn't force to ignore root exports declared in  `dependencies.exports.root`, @todo: when `exports.root` is implemented :-)

* Use `'bundle'` instead of `true` to ignore those defined in `bundle.exports.root` @todo: NOT IMPLEMENTED

* Use `'all'` to ignore all root exports @todo: NOT IMPLEMENTED

@type boolean | 'bundle' | 'all'

      noRootExports: false

## build.scanAllow

By default, ALL `require('dep1')` deps in your module are added on the dependency array eg `define(['dep0', 'dep1',...], ...)`, [preventing RequireJS to scan @ runtime](https://github.com/jrburke/requirejs/issues/467#issuecomment-8666934).

With `scanAllow:true` you can allow `require('')` scan @ runtime, *for source modules that have no other [] deps* (i.e. using nodejs source modules or using only require('') instead of the dependencies array. If there is even one dep on [], runtime scan is disabled on requireJs and uRequire takes care to have all `require('')` deps listed on deps array as they should to [prevent halting](https://github.com/jrburke/requirejs/issues/467).

@note: modules with `rootExports` / `noConflict()` always have `scanAllow: false`

      scanAllow: false

## build.allNodeRequires

Pre-require all deps on node, even if they aren't mapped to any  parameters, just like in AMD deps []. Hence it preserves the same loading order as on Web/AMD, with a trade off of a possible slower starting up (they are cached nevertheless, so you gain speed later).

      allNodeRequires: false

## build.verbose
Print bundle, build & module processing information.

@type: Boolean

@todo: make it less verbose / work better with `build.debugLevel`

      verbose: false

## build.debugLevel
Debug levels *1-100*.

@todo: make it less verbose / work better with `build.verbose`

      debugLevel: 0

## build.continue

Dont bail out while processing when there are **module processing errors**.

For example ignore a coffeescript compile error, and just do all the other modules. Or on a `combined` conversion when a 'global' has no 'var' association anywhere, just hold on, ignore this global and continue.

@note: Not needed when `build.watch` is used - the `continue` behavior is applied to `build.watch`.

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

This is set by either *urequireCMD* or [grunt-urequire](https://github.com/aearly/grunt-urequire) to signify the end of a build - don't use it!

      done: (doneVal)-> console.log "done() is missing and I got a #{doneVal} on the default done()"