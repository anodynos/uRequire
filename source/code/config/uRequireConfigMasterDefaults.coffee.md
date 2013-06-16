# Introduction

** WARNING: Work In Progress **

The master & defaults configuration file of uRequire.

## Literate
This documentation file is written in [Literate Coffeescript](http://ashkenas.com/literate-coffeescript): it serves both as markdown documentation AND the actual executable. The code blocks shown, are the actual code used at runtime, i.e each key declares its self and sets a default value.


    module.exports = uRequireConfigMasterDefaults =

## bundle & build

uRequire config has two top level keys/hashes: `bundle` and `build`.
All related information is nested bellow these two keys.

*Note: user configs (especially simple ones) can safelly ommit 'bundle' and 'build' hashes and put keys belonging on either on the 'root' of their object. uRequire safelly recognises where keys belong, even if they're not in `bundle`/`build`.*

## Flexibility
@todo: doc it
polymorphism

## Deriving
@todo: doc it

## Legend
* @derive: describes how values are derived from other parent configs, similar to how a subclass *overrides* a parent class.

For example if you have `DevelopementCongig` which is derived from a parent `ProductionConfig`, then the first one (the derived) will override (or ammend) the values of the second (the parent).

Ultimatelly all configs are derived from `uRequireConfigMasterDefaults` which hold all default values.

* @stability: (1-5) a [nodejs-like stability](http://nodejs.org/api/documentation.html#documentation_stability_index) of the setting. If not stated, its assumed to be a "3 - Stable".

* @type

* @note

# bundle

    bundle:

The *bundle* hash defines what constitutes a bundle. A bundle is the 'source' to the 'build' that follows.

## bundle.name

      name: undefined

The *name* of the bundle, eg 'MyLibrary'

@optional

`name` its self can be derived from:
  - if using grunt, it defaults to the multi-task @target - for example
    `{urequire: 'MyBundlename': {bundle : {}, build:{} }}`

@note: `name` is the 1st default for 'main', if the latter is not explicit.

## bundle.main

The "main" / "index" module file of your bundle, needed when 'combined' template is used.

@todo: change this

Tempalte 'combined' requires a 'main' module.
if 'main' is missing, then main is assumed to be `bundleName`,
which in turn is assumed to be grunt's @target ('uberscoreDev' in this case).
Having 'uberscoreDev' as the bundleName/main, but no module by that name (or 'index' or 'main')
will cause a compilation error.
Its better to be precise anyway, in case this config is used outside grunt.


@optional

* Used as 'name' / 'include' on RequireJS build.js.
  It should be the 'entry' point module of your bundle, where all dependencies are `require`'d.
  r.js recursivelly adds them to the 'combined' optimized file.

* It is also used to as the initiation `require` on your combined bundle.
  It is the module just kicks off the app and/or requires all your other library modules.

* Defaults to 'name', 'index', 'main' etc, the first one that is found in uModules.


      main: undefined


## bundle.path

      path: undefined

If ommited, it is implied by config's position.

@example `'./source/code'`


## bundle.filez

      filez: ['**/*.*']

All files in bundle are specified here.

Each file is considered to be either:
* BundleFile
* Resource - any textual resource that we want to convert to something else: eg .coffee->.js, or .less or .css
* Module - A Resource that is also a Module whose Dependencies we monitor and converted through some template.
how these are matched, @see bundle: resources

@type
   filename specifications (or simply filenames), that within contains *all* the files within your bundle.
   Expressed in either grunt's expand minimatch format (and its negative cousin), or sRegExp`s

@default [/./], ie. all non-module files are copied

@example bundle: {filez: ['**/recources/*.*', '!dummy.json', /\.someExtension$/i ]}

@derive: when you derive, all your source items (derived objects) are appended after the ones higher up @todo: doc it


## bundle.copy

(binary) copy of all non-resource bundle files to dstPath - just a convenience

      copy: []

@type filez specs - see filez above
filename specifications (or simply filenames), considered as part of your bundle
that are copied to dstPath ONLY if not matched as resources/modules.

@example bundle: {copy: ['**/images/*.gif', '!dummy.json', /\.(txt|md)$/i ]}

@default [], ie. no non-module files are copied - U can use /./ for all

@derive when you derive, all your source items are ...@todo: doc it

## bundle.resources

Defines text converters (eg compilers), that perform an in-memory workflow conversion from a resource format (eg coffeescript, less) to another compiled format (eg javascript, css)

@stability: 2 - Unstable

Check the following code [(that is actually part of uRequire)](Literate), that defines some basic text resource converters:

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

## bundle.webRootMap

      webRootMap: '.'

Where to map `/` when running in node. On RequireJS its http-server's root.

Can be absolute or relative to bundle. Defaults to bundle.
@example "/var/www" or "/../../fakeWebRoot"

## bundle.dependencies

Anything related to dependenecies is listed here.

      dependencies:

### bundle.dependencies.depsVars

        depsVars: {}

Each (global) dependency has one or more variables it is exported as, eg `jquery: ["$", "jQuery"]`

They can be infered from the code of course (AMD only for now), but it good to list them here also.

They are used to 'fetch' the global var at runtime, eg, when `combined:'almond'` is used.

In case they are missing from modules (i.e u use the 'nodejs' module format only),
and aren't here either, 'almond' build will fail.

Also you can add a different var name that should be globally looked up.

### bundle.dependencies._knownDepsVars

Some known depsVars, have them as backup!
todo: provide some 'common ones' that are 'strandard'

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

          bundle: {}

@type
`{ dependency: varName(s) *}`
`['dep1', 'dep2']` (with discovered or ../depsVars names)

@example `{
  'underscore': '_'
  'jquery': ["$", "jQuery"]
  'models/PersonModel': ['persons', 'personsModel']
}`


#### bundle.dependencies.exports.root

Each dep listed will be available GLOBALY under varName(s) - @note: works in browser only - attaching to `window`.

          root:{}

@example {
  'models/PersonModel': ['persons', 'personsModel']
}

is like having a `{rootExports: ['persons', 'personsModel']} in 'models/PersonModel' module.

*@todo: NOT IMPLEMENTED - use module `{rootExports: [...]} format.*

### bundle.dependencies.replaceTo

Replace all right hand side dependencies (String value or []<String> values), to the left side (key)
Eg `lodash: ['underscore']` replaces all "underscore" deps to "lodash" in the build files.
@todo: Not implemented

        replaceTo:
          lodash: ['underscore']


# Build

The `build` key hold settings that define the conversion, such as *where* and *what* to output.

    build:

## build.dstPath

Output converted files onto this

      dstPath: undefined

* directory
* filename (if combining)
* function @todo: NOT IMPLEMENTED

*todo: if ommited, requirejs.buildjs.baseUrl is used ?*
@example 'build/code'
@alias `outputPath` DEPRACATED


## build.forceOverwriteSources

Output on the same directory as path.

Useful if your sources are not `real sources` eg. you use coffeescript :-).
WARNING: -f ignores --dstPath

      forceOverwriteSources: false

## build.template

String in ['UMD', 'AMD', 'nodejs', 'combined'] @todo: or an object with those as keys + more stuff!

      template: name: 'UMD'

      # @todo:4 NOT IMPLEMENTED
      #       # combined options: use a 'Universal' build, based on almond that works as standalone <script>, as AMD dependency and on node!
      #       # @todo:3 implement other methods ? 'simple AMD build"
      #      'combined':
      #
      #          # build even if no modules changes (just resources)
      #          noModulesBuild: false:
      #
      #
      #          # @default 'almond' - only one for now
      #          method: 'almond'
      #
      #           Code to be injected before the factory = {....} definition - eg variables available throughout your module
      #          inject: "var VERSION = '0.0.8'; //injected by grunt:concat"
      #
      #          ###
      #          Array of dependencies (globals?) that will be inlined (instead of creating a getGlobal_xxx).
      #          The default is that all bundle non-ignored
      #
      #          * 'true' means all (global) libs are inlined.
      #          * String and []<String> are deps that will be inlined
      #
      #          @example depsInline: ['backbone', 'lodash'] # inline these deps
      #          @example depsInline: ['backbone', 'lodash'] # inline these deps
      #
      #          @default undefined/false : 'All globals are replaced with a "getGlobal_#{globalName}"'
      #
      #          @issues: where do we find the source, eg 'lodash.js' ? We need bower integration!
      #          @todo:4 NOT IMPLEMENTED
      #          ###
      #          depsInline: false
      #
      #
      #          depsTo


## build.watch

Watch for changes in bundle files and reprocess/re output *only* those changed files.

The *watch feature* works as:

* standalone urequireCmd, having `watch: true`

* in grunt, without using `watch:true` value, but through `grunt-urequire >=0.4.5` & `grunt-contrib-watch`

      watch: false

## build.noRootExports

When true, it ignores all rootExports {& noConflict()} defined in all module files eg
  `{rootExports: ['persons', 'personsModel']}`

'true' doens not ignore those of `dependencies: exports: root`, @todo: when `exports.root` is implemented :-

* use 'bundle' to ignore those defined in `bundle.exports.root` config @todo: NOT IMPLEMENTED

* use 'all' to ignore all root exports @todo: NOT IMPLEMENTED

      noRootExports: false

*Web/AMD side only option* :

## build.scanAllow

By default, ALL require('') deps appear on []. to prevent RequireJS to scan @ runtime.

With `scanAllow:true` you can allow `require('')` scan @ runtime, for source modules that have no other [] deps (i.e. using nodejs source modules or using only require('') instead of the dependencies array.

@note: modules with rootExports / noConflict() always have `scanAllow: false`

      scanAllow: false

## build.allNodeRequires

Pre-require all deps on node, even if they arent mapped to parameters, just like in AMD deps [].
Preserves same loading order, with a trade off of a possible slower starting up (they are cached nevertheless, so you might gain speed later).

      allNodeRequires: false

## build.verbose
Print bundle, build & module processing information.

@type: Boolean

      verbose: false

## build.debugLevel
Debug levels *1-100*

      debugLevel: 0

## build.continue

Dont bail out while processing when there are **module processing errors**.

For example ignore a coffeescript compile error, just do all the other modules. Or on a `combined` conversion when a 'global' has no 'var' association anywhere, just hold on, ignore this global and continue.

@note: Not needed when `watch` is used.

      continue: false

## build.optimize

Optimizes output files (i.e it minifies/compresses them for production).

@todo: PARTIALLY IMPLEMENTED - Only working for `combined` template, delegating the option to `r.js`

@options

* *false*: no optimization (r.js build.js optimize: 'none')

* *true*: uses sane defaults to minify, using 'uglify2' through r.js

* 'uglify' / 'uglify2': specifically select either with their r.js default settings.

* [r.js optimize object] like ['uglify'](https://github.com/jrburke/r.js/blob/f021df4d2b68/build/example.build.js#L138-154) or ['uglify2'](https://github.com/jrburke/r.js/blob/f021df4d2b68/build/example.build.js#L161-176) for example `optimize: {uglify2: output: {beautify: true}, compress: {...}, warnings: true}`


      optimize: false
      _optimizers: ['uglify2', 'uglify']


# Other draft ideas / requirements - dont read this if you're on delivery mode :-)

- modules to exclude their need from either AMD/UMD or combine and allow them to be either
  - accessed through global object, eg 'window'
  - loaded through RequireJs/AMD if it available
  - Loaded through nodejs require()
  - other ?
With some smart code tranformation they can be turned into promises :-)


