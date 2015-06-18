# Introduction

_**NOTE Work In Progress** Currently migrating docs from 0.6.x to 0.7.0. Everything works, but there are some undocumented parts._

The **config** is the heart of *uRequire*, to the user's side. This file is both **docs** & the **defaults** of the [config file/object](#Config-Usage).

Scroll to some super cool [config examples](#Examples), that show the power of uRequire & its config.

## Note: Literate Coffescript

This file is written in [Literate Coffeescript](http://ashkenas.com/literate-coffeescript): it serves both as *markdown documentation* AND the *actual code* that represents the *master config*. Most code blocks shown (unless otherwise noted) are the actual code, i.e each key declares **name** and **default value**.

    module.exports = MasterDefaultsConfig =

NOTE: This file primary location is https://github.com/anodynos/uRequire/blob/master/source/code/config/MasterDefaultsConfig.coffee.md & copied over to the urequire.wiki - DONT edit it separately in the wiki.

@see the [*tags legend*](tags-legend) of the documentation

## Config Usage

A `config` determines a `bundle` and a `build` that uRequire will process. A config is an `{}` with [expected keys](MasterDefaultsConfig.coffee#the-bundle-and-the-build) & can be used as:

* **File based**, using the urequire CLI (from `npm install urequire -g`) as `$ urequire config myConfig.js`, where `myConfig.js` is a node module file that exports the `config` object. The file can actually be a `.coffee` or `.js` node module, or a `.json` file as well as many other formats - see [butter-require](https://github.com/anodynos/butter-require).
 The 'XXX' of [`derive:'XXX'](types-and-derive#Deriving-behaviors) can be another **parent file** (eg `parentConfig.yml`), relative to the 1st children's path. @todo: make relative to each children's path).

* Using [**grunt-urequire**](https://github.com/aearly/grunt-urequire) (preferred), having (almost) the exact `config` object of the file-base, but as a `urequire:XYZ` grunt task. The difference is that [`derive:'XXX'](types-and-derive#Deriving-behaviors) can be another `urequire:XXX` task, and if its not found its assumed to be a filename, relative to `Gruntfile.js`.

* Within your tool's code, [using `urequire.BundleBuilder`](Using-uRequire#Using-within-your-code).

## Versatility

uRequire configs are extremely versatile:

* reads keys both in the 'root' of your config *OR* in ['bundle'/'build' hashes](MasterDefaultsConfig.coffee#the-bundle-and-the-build)

* provides [short-cuts](Types-and-derive#shortcut-depsvars-types), to convert simple syntax to more complex.

* has a unique inheritance scheme, **[deriving](types-and-derive#Deriving-behaviors) from parent configs**.


# The 'bundle' and the 'build'

**uRequire config** has 2 top-level keys/hashes: [`bundle`](#bundle) and [`build`](#build). All related information is nested bellow these two keys.

**@note: user configs (especially simple ones) can safely omit `bundle` and `build` hashes and put the keys belonging on either on the 'root' of their config object. uRequire safely recognises where keys belong, even if they're not in `bundle`/`build`.**

_______
# bundle

The `bundle` hash defines what constitutes a bundle, i.e where files are located, which ones are converted and how etc. Consider a `bundle` as the 'source' or the 'package' that is then *processed* or built, based on the `build` part of the config.

    bundle:

## bundle.path

The filesystem path where source files reside (relative to urequire's CWD, or `Gruntfile.js` for [grunt-urequire](https://github.com/aearly/grunt-urequire)).

@mandatory But, if `bundle.path` is ommited, it is implied by the 1st config's file position (only for file-based 'config' command, not in [grunt-urequire](https://github.com/aearly/grunt-urequire)'s config).

@example `'./source/code'`

@alias `bundlePath` DEPRECATED

      path: undefined

## bundle.filez

All files that participate in the `bundle` are specified here. Its the ultimate filter of your bundle, virtually including or excluding files. Its very versatile

@type [filespecs](types-and-derive#filespecs)

@derive [arrayizeConcat](types-and-derive#arrayizeConcat).

@note all files are relative to [bundle.path](#bundle.path)

@alias `filespecs` DEPRECATED

@note the `z` in `filez` is used to segregate from gruntjs `files`, when urequire is used within [grunt-urequire](https://github.com/aearly/grunt-urequire) and allow its different features like RegExp & deriving.

@note: The master default is `undefined`, so the last child `filez` in derived hierarchy determines what is ultimately allowed.

@default: *The actual default (runtime hard-coded)*, if no `bundle.filez` exists in the final cfg, is `['**/*']` (and not `undefined`). That's why its optional!

      filez: undefined

## bundle.copy

Copy (binary & sync) of all non-resource [bundle.filez](MasterDefaultsConfig.coffee#bundle.filez) (i.e those that are [`BundleFile`]((MasterDefaultsConfig.coffee#bundlefile)s) to [`build.dstPath`](MasterDefaultsConfig.coffee#build.dstpath) as a convenience. If destination exists, it checks nodejs's `fs.statSync` 'mtime' & 'size' and copies (overwrites) ONLY changed files.

@example `copy: ['**/images/*.gif', '!dummy.json', /\.(txt|md)$/i]`

@type [filespecs](types-and-derive#filespecs)

@derive [arrayizeConcat](types-and-derive#arrayizeConcat).

@alias `copyNonResources` DEPRECATED

@default `[]`, i.e no non-resource files are copied. You can use `/./` or `'**/*'` for all non-resource files to be copied.

      copy: []

## bundle.name

The *name* of the bundle, eg 'MyLibrary'.

@note: `bundle.name` serves as the 1st default for [`bundle.main`](#bundle.main) (if main is not explicit).

@alias `bundleName` DEPRECATED

      name: undefined

## bundle.main

The `'main'` or `'index'` module file of your bundle, that `require`s and kicks off all other modules (perhaps implicitly).

@optional unless ['combined' template](combined-template) is used, or you have a [`build.template.banner`](#build.template).

@example

```coffee
 bundle: main: "MyAwesomeLibrary"
```

whereas `'MyAwesomeLibrary.js'` would be something like:

```
 define(function(){
    return {
      aModule: require('somepath/aModule'),
      anotherModule: require('somepath/anotherModule')
    }
 }

```

or the `module.exports = {...}` version.

### Details:

  * `bundle.main` is used as 'name' / 'include' on RequireJS build.js, on [combined/almond template](combined-Template).

  *  It should be the 'entry' point module of your bundle, where all dependencies are `require`'d. Then **r.js** recursively adds all dependency tree to the ['combined'](combined-template) optimized file.

  * It is also used to as the initiation `require` on your [combined](combined-template) bundle.
    It is the module just kicks off the app and/or requires all your other library modules.

  * Defaults to `bundle.name`, `'index'`, `'main'`: If `bundle.main` is missing, it defaults to `bundle.name`, *only* if there is a module by that name. If `bundle.name` fails to match an existing module, `'index'` or `'main'` are used as `bundle.main` (again provided there is a module named `'index'` or `'main'` - which ever found first). In all cases of automatic discovery, uRequire will issue a warning.

  * Its the name of the module [`build.template.banner`](#build.template) is added.

If `bundle.main` can't match an existing module, it will cause a ['combined' template](combined-template) error.

      main: undefined

## bundle.dependencies

All information related to dependencies handling is listed here.

      dependencies:

#### bundle.dependencies.imports

Allows you to *export* or [*inject*](resourceconverters.coffee#inject-replace-dependencies) (i.e have available) specific dependencies (other modules) throughout the *whole bundle*, under the given variable name(s).

Eg you want to access `'underscore'` from  `_`, `'backbone'` from `Backbone` etc, from all modules, without having to declare it in each module.

Effectively this means that each module will have an *injection* of all `dependencies.imports`, so you don't have to list them in each module.

@example

```
{ 'underscore': '_',
 'jquery': ["$", "jQuery"],
 'models/PersonModel': ['persons', 'personsModel'] }
```

will give you :

* Injection of Modules / dependencies `'underscore'`, `'jquery'`, and `'models/PersonModel'` to each module in the bundle.

* Access of `_`, `$`, `jQuery`, `persons` & `personsModel` variables everywhere, without listing them once on any module's code.

* Working the same way on all templates, on any environment (AMD, nodejs, Web/Script).

* Saving space: on ['combined' template](combined-template), they are listed & loaded only once, made available only within bundle's 'combined' closure.

@type [depsVars](types-and-derive#depsVars)

@derive [dependenciesbindings](types-and-derive#dependenciesbindings)

@note the [shortcut depsvars format](Types-and-derive#shortcut-depsvars-types), can also be used (eg `['underscore', 'jquery', 'models/PersonModel']`), in which case the [vars are inferred]](types-and-derive#inferred-binding-idenifiers).

@alias `bundleExports`, `exports.bundle` both DEPRECATED

        imports: {}

#### bundle.dependencies.rootExports

Make a module be available GLOBALY (by attaching it to `window` and/or nodejs's `global` object) under `varName`(s), same as in [Exporting Modules](Exporting-Modules).

Access via plain `varName` works both in browser *and* nodejs.

  * On browser its attached as a property to `window` object

  * On nodejs its attached to the `global` object with the same effect: accessing it via its name from everywhere.

@note: When `bundle.dependencies.rootExports` is present, you control `noConflict` via [`build.rootExports.noConflict`](#build.rootExports.noConflict) which defaults to `true` (overriding `noConflict` defined within the module, as described in [Exporting Modules](Exporting-Modules)).

@example

  `bundle: dependencies: rootExports: {'models/PersonModel': ['persons', 'personsModel']}`

is like having a

  `({rootExports: ['persons', 'personsModel'], noConflict:true});`

in module `'models/PersonModel'` as described in [Exporting Modules](Exporting-Modules).

@type [depsVars](types-and-derive#depsVars)

@derive [dependenciesbindings](types-and-derive#dependenciesbindings)

@note both `window` and `global` objects exist as an alias of each other on the ['combined' template](combined-template) or when [`build.globalWindow: true`](#build.globalWindow) (the default) on all other templates.

@alias `dependencies: exports: root` DEPRECATED

        rootExports: {}

### bundle.dependencies.replace

Replace one or more dependencies with another. Enables you to substitute with mocks, substitutes or provide compatibility etc.

It replaces all right hand side dependencies (String value or []<String> values), to the left side (key) in the build modules.

@example
```
{
  lodash: ['underscore', 'otherscore'],
  newDep2Name: 'oldDep2Name'
}```

replaces all `'underscore'` or `'otherscore'` deps to `'lodash'` and all `'oldDep2Name'` with `'newDep2Name'` in all modules of the bundle.

All deps are considered / translated to [bundleRelative](http://urequire.org/flexible-path-conventions#bundlerelative-vs-filerelative-paths):

 * `'depDir/dep'` matches and/or replaces the deps that resolved to this as bundle relative, even if they are declared in the code of `'someOtherdir/someModule'` as `require('../depDir/dep')` (when authored with the nodejs fileRelative path convention).

 * `'../../some/external/dep'` will fall outside the bundle, it refers to a directory that is two '..' steps before `bundle.path` and will match `require('../../../some/external/dep')` declared in `'someOtherdir/someModule'`.

@see [inject / replace dependencies](resourceconverters.coffee#inject-replace-dependencies) in [Manipulating Modules](resourceconverters.coffee#manipulating-modules).

@type [depsVars](types-and-derive#depsVars)

@derive paradoxically its [dependenciesbindings](types-and-derive#dependenciesbindings)

        replace: {}

### bundle.dependencies.node

Dependencies ([declared as filespecs](types-and-derive#filespecs)) listed here are treated as node-only: they aren't added to the AMD dependency array (and hence **not available** on the Web/AMD side).

Your code should not use these deps outside node - you can use `__isNode`, `__isAMD`, `__isWeb` available in uRequire compiled modules with [`build.runtimeInfo`](#build.runtimeInfo) to follow a different branch in your code.

Using `bundle.dependencies.node` has the same effect as the `node!` fake plugin, eg `require('node!my_fs')`, but its probably more useful cause your code can execute on nodejs without the template conversion that strips `'node!'` and you can declare in them in bulk without poluting the source code.

@type [filespecs](types-and-derive#filespecs), **used WITHOUT extensions (.js)**, only as deps.

@derive [arrayizeConcat](types-and-derive#arrayizeConcat).

@example `node: ['myUtil', 'my_fs', 'node/*', '!stream']`

@alias noWeb DEPRECATED

@stability 2

@default All known built-in nodejs packages (as of 10.8) like `'util'`, `'fs'` etc are the default of  `bundle.dependencies.node`. Use `node: [[null], 'myNodeModule']` to reset the `node` array with only your modules.

@note: If your bundle contains a dependency that is also in `dependencies.node` (eg you have 'url.js' *in the root of you bundle*), then **this is considered to be a node-only dep**, so you DO need to exclude it with `'!url'`, or it wont be available on the AMD side.

        node: [
          'fs', 'events', 'util', 'http', 'path', 'child_process',
          'events', 'crypto', 'string_decoder', 'timers', 'tls'
          'domain', 'buffer', 'net', 'dgram', 'dns', 'stream',
          'https', 'querystring', 'punycode', 'readline', 'url',
          'repl', 'vm', 'assert', 'tty', 'zlib', 'os', 'cluster'
          'console', 'freelist', 'sys', 'constants' # 'module' conflicts with dep.isSystem
        ]

### bundle.dependencies.locals

Declare your local packages, like `'lodash'` or `'when'` that are installed either on npm (i.e `node_modules`), bower (i.e `bower_components`) or vanilla (eg `/vendor`). Local deps are NOT considered part of the bundle, hence they are not reported as _"Bundle-looking dependencies not found in bundle"_.

All deps that have no nested path (i.e no `'/'`) and are not in the bundle's path (eg `'lodash'`) are considered as local automatically. **The only reason you would need to declare a dep as local is :**

 * you use something like `require('when/callbacks')` and it's reported as _"Bundle-looking dependencies not found in bundle"_, but it shouldn't be. So you list `when` in `locals` and everything that falls below `'when/**/*'` is also considered local.

@optional

@stability 3

@example `locals: ['when']` or `locals: {'when': 'bower_components/when'}`

@type :

 * Array<String>, eg ['when', 'backbone', 'lodash']. **Declare only the first path part of you local-only deps, eg `'when'`, instead of `'when/node/function'`**

 * [depsVars](types-and-derive#depsVars) type where

   * keys are the first part of the local dep name

   * value(s) are the paths when the dependency 'main' can be found. eg
    ```
     {
      'when': "bower_components/when"
      'backbone': "node_modules/backbone"
      'lodash': "node_modules/lodash"
     }
    ```

        locals: {}

@example

```
dependencies:
 imports:
  'when/callbacks': 'whenCallbacks'

 locals:
  'when': 'bower_components/when'
```

Doesn't work with `combined` template running as plain script - `when` needs to be combined too - check their docs.


### bundle.dependencies.paths

        paths:
          useCache: true
          override: undefined
          bower: undefined
          npm: undefined

        shim: true

### bundle.dependencies.depsVars

List of dependencies bound with one or more vars.

@optional list them only as reference/backup, when they [cant be inferred]](types-and-derive#inferred-binding-idenifiers), or some specific deps shouldnt be inferred.

@note In case identifiers can't be inferred (i.e only used `require('myLocalDep')` without assigning to a var) and bindings aren't in `bundle.dependencies.depsVars` (or `_knownDepsVars` below), then the [build will fail](types-and-derive#Binding-deps-and-vars-is-required).

@example `{ underscore: ['_'], jquery: ['$', 'jQuery'], }`.

@type [depsVars](types-and-derive#depsVars)

@derive [dependenciesBindings](types-and-derive#dependenciesbindings)

@alias variableNames DEPRECATED

        depsVars: {}

### bundle.dependencies._knownDepsVars

Some known depsVars, have them as backup - its a private field, not meant to be extended by users (use depsVars).

@type [depsVars](types-and-derive#depsVars)

@derive [dependenciesBindings](types-and-derive#dependenciesbindings)

@alias _knownVariableNames DEPRECATED

@todo: provide some 'common/standard' ones.

        _knownDepsVars:
          chai: 'chai'
          mocha: 'mocha'
          lodash: "_"
          underscore: "_"
          jquery: ["$", "jQuery"]
          backbone: "Backbone"
          knockout: ["ko", 'Knockout']

____

## bundle.resources

An Array of [**ResourceConverters (RC)**](ResourceConverters.coffee) (eg compilers, transpilers etc), that perform a conversion from one resource format (eg coffeescript, teacup) to another **converted** format (eg javascript, HTML).

**ResourceConverters** is a generic and extendible in-memory conversions workflow, that is trivial to use and extend with your own, perhaps one-liner, converters (eg `['$coco', [ '**/*.co'], ((r)-> (require 'coco').compile r.converted), '.js']` is an RC).

The workflow unobtrusively uses `bundle` & `build` info like paths and is a highly *in-memory-pipeline* and *read-convert-and-save only-when-needed* workflow, with an integrated [`build.watch`](MasterDefaultsConfig.coffee#build.watch) capability (grunt or standalone).

Read all about them in [**ResourceConverters.coffee**](ResourceConverters.coffee).

### Notes on RCs:

* Each file in [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) that is matched by an RC is considered a [`Resource`](resourceconverters.coffee#fileresource-extends-bundlefile) that needs `convert()`-ing.

* All non-matching filez are just [`BundleFile`](resourceconverters.coffee#bundlefile)s - useful for *declarative sync [`bundle.copy`](MasterDefaultsConfig.coffee#bundle.copy)ing at each build*.

@optional unless you want to add you own *Resource Converters* for your conversion needs.

@derive [arrayizeConcat](types-and-derive#arrayizeConcat). Hint: You can use [null] as the 1st item to [reset inherited/parent array items](types-and-derive#reset-parent) (i.e the ResourceConverters defined in parent configs) and add your own RC or lookup, clone and change an existing one.

@stability: 3 - Stable

@type An Array<ResourceConverter>, where a `ResourceConverter` can be either :

* an ['Object'](ResourceConverters.coffee#Inside-a-Resource-Converter), for [boring formal RC definitions](ResourceConverters.coffee#The-formal-Object-way-to-define-a-Resource-Converter).

* an ['Array'](ResourceConverters.coffee#The-alternative-less-verbose-Array-way) (for fancy RC-specs)

* a 'String' name search of a previously registered RC, eg `'teacup'`. Note that [name flags](ResourceConverters.coffee#Flags-and-Nameflags) passed on the search (eg `'#teacup'`), find the actual RC, modify it according to the name flags, strip the flags and then return the RC.

* a function that returns an RC. This function is called with the 1st argument & `this` with a *searchOrMaterialize*  function that takes a String name (or an Array-spec) of an RC and returns a looked up (or materialized RC). For example:

  ```javascript
  // example - not part of coffee.md source
  resources: [
    // lookup & clone an RC 
    function(search){
      // (use rc.clone() to get a proper instance)
      var rc = search("RCname").clone();
      // change the clone's name
      // & type to 'module' via '$' name flag
      rc.name = '$MyNewRCname';
      // add some file specs to `filez`
      rc.filez.push('!**/DRAFT*.*');
      // return the new RC, which is
      // added to `resources` array
      return rc;
    },
    // create a new RC from an Array spec
    // add some fields and return it
    function(materialize){
      // create an RC {} from an RC []
      myRC = materialize([ 'myNewRC', [/./], convertToMoreFn]);
      // we now have an {} RC with above fields
      myRC.srcMain = 'main.lessIsMore';
      return myRC;
    }  
  ]
  ```      
    
  If the function returns null or undefined, its not added to the Array.

@note **Important**: The **order of RCs in `resources` does matter**, since *only the last matching RC determines the [actual class](ResourceConverters.coffee#Attaching-some-clazz))* of the created resource (file).

@example 

A dummy example follows (in coffeescript) :

```
# example - not part of coffee.md source
resources: [
 # search registered RC 'teacup' & use as-is
 'teacup'
 
 # search RC, change its flags and return it
 '@someRCname' 

 # search, clone, change, return in one line
 -> tc = @('someRC').clone(); tc.filez.push('**/*.someExt'); tc

 # define a new RC, with the fancy [] RC-spec
 ['$koko', ['**/*.ko'], ((m)-> require('koko').compile m.converted), '.js']

 # define a new RC, with the grandaddy {} RC-spec
 {
   name: 'kookoo'
   type: 'module'
   filez: [ '**/*.koo']
   convert: (m)-> require('kookoo').compile m.source
   convFilename: '.js'
 }

 # define a new RC, and reuse an existing
 # with the magic search-create-alter function
 # passed as `this` (@ in coffeescript)
 ->
   # lookup an existing
   kookoo = @ 'kookoo'
   # return a new one, that uses `kookoo.convert`   
   ['$doodoo', [ '**/*.doo'], kookoo.convert, '.js']
]
```

@default 

By default `resources` has ResourceConverters `'javascript', 'coffee-script', 'livescript', and 'coco'` as defined in [Default Resource Converters](ResourceConverters.coffee#Default-Resource-Converters).

Some [extra RCs are registered](ResourceConverters.coffee#Extra-Resource-Converters), but not added to 'resources' - they can be used by searching for 'teacup', 'execSync' or 'lessc'. Feel free to contribute yours.

      resources: require('./ResourceConverters').defaultResourceConverters

## bundle.commonCode

This is an opportunity to add code once and have it included:

 * before each module's factory body (and before moddule's [`beforeBody`](ResourceConverters.coffee#beforeBody) & [`mergedCode`](ResourceConverters.coffee#mergedCode)) for all templates except ['combined' template](combined-template).

 * Once within the bundle's closure, available to all modules, when using the ['combined' template](combined-template).

In all templates, the code should access only `bundle.dependencies.imports` vars & other globals. It should not it self `require` anything, cause its depedencies are not (and should not be) analyzed.

@see [inject code and strings in modules](resourceconverters.coffee#inject-any-string-before-after-body) & [Merging code in bundles](combined-template#merging-code)

@example

      commonCode: undefined

## bundle.webRootMap

**When running on nodejs**, for dependencies that refer to web's root (eg `'/libs/myLib'`), it maps `/` to a directory on the nodejs file system.

When running on Web/AMD, the AMD loader (eg RequireJS) maps it to the **http-server's root** by default (eg http://example.com/).

`webRootMap` can be absolute (`'/mnt/libs/'`) or relative to [`bundle.path`](MasterDefaultsConfig.coffee#bundle.path). - it defaults to bundle.

@example "/var/www" or "/../../fakeWebRoot"

@note `webRootMap` is currently working only with `'UMD'` template.

      webRootMap: '.'
_______
# Build

The `build` hash holds keys that define the conversion or `build` process, such as *where* to output, details on *how* to convert/build etc.

    build:

## build.dstPath

Output converted files (Modules & Resources) onto this:

* directory, for all templates except ['combined'](combined-template)

* filename, if ['combined' template](combined-template) is used and [`build.template.combinedFile`](#build.template) is undefined.

  If using ['combined' template](combined-template) & `combinedFile`, you can:

  * omit `dstPath` and all converted resources will go in the same *directory* as the `combinedFile` file.

  * specify any alternative `dstPath`, where all other resources (non-modules) will be written.

@note: [`build.dstPath`](#build.dstPath), like [`bundle.path`](#bundle.path), is relative to urequire's CWD or `Gruntfile.js` for [grunt-urequire](https://github.com/aearly/grunt-urequire).

@mandatory unless [`build.forceOverwriteSources`](#build.forceOverwriteSources) or [`build.template.combinedFile`](#build.template) is used

@example `'build/code'` or `'build/dist/myLib-min.js'`

@alias `outputPath` DEPRECATED

      dstPath: undefined


## build.target

The name of the build target - when using [grunt-urequire](https://github.com/aearly/grunt-urequire), it becomes the multi-task `@target`. So with grunt config `{urequire: 'dev': {bundle : {...}, build:{target:undefined} }}`, `build.target` will become `'dev'`.

@optional coerced to @target if using grunt - otherwise set it what ever describes your build.

@example `'UMD'`, `'dev'`, `'min'`, `'specDev'` etc

      target: undefined

## build.forceOverwriteSources

Output on the same directory as the _source_ [`bundle.path`](MasterDefaultsConfig.coffee#bundle.path), overwriting all files. Useful if your sources are not *real sources*.

@note: Be warned that when `true`, [build.dstPath](MasterDefaultsConfig.coffee#build.dstPath) is ignored and always takes the value of [`bundle.path`](MasterDefaultsConfig.coffee#bundle.path).

      forceOverwriteSources: false

## build.template

The **template** to use to either convert:

  * each module file, to a new format like `'UMD'`, `'UMDplain'`, `'nodejs'`, `'AMD'` etc

  * all modules files into one `combined.js` file, using the special ['combined' template](combined-template) that actually drives an r.js/almond conversion.

@type

  * The _simple usage_ is a String of the **name of the template** as a string among the available [Build.templates](https://github.com/anodynos/uRequire/blob/master/source/code/process/Build.coffee) = ['UMD', 'UMDplain', 'AMD', 'nodejs', 'combined']

  * A hash that has the following optional values :
```
    template: {
      name: {String}
      moduleName: {String}
      banner: {String|Boolean|Function}
      debugLevel: {Number}
    }
```

### build.template.name

The String **name of the template**, as in _simple usage_ above.

#### Example

   name: 'combined'

### build.template.combinedFile

For the 'combined' template only, you can declare the `combinedFile`, if its different (or instead of) [`build.dstPath`](#build.dstPath).

#### Example

   combinedFile: 'build/someOtherPath/combinedModulesFilename.js'

#### Usage

The `combinedFile` and [`build.dstPath`](#build.dstPath) derive from each other, if either is undefined:

 * In the previous example, if `build.dstPath` is undefined, it will default to `'build/someOtherPath/'`

 * If `combinedFile` is undefined, it will use [`build.dstPath`](#build.dstPath) with a '.js' appended.

 * if both are undefined uRequire will quit (unless [`forceOverwriteSources`](#build.forceOverwriteSources) is true).

If both are defined, they will be respected, leading to a possible different path where `combinedFile` is written and where all other non-combined files (that are part the bundle) are written (eg [`bundle.copy`](bundle.copy), htmls, css etc).

### build.template.moduleName

By default, when AMD is present, 'combined' template calls `define()` that registers your combined bundle as an **anonymous module** - this registers in the AMD system with the name of its path (eg `uberscore-min`).

You can change this behavior and call `define` with a [moduleName](http://www.requirejs.org/docs/api.html#modulename) eg `moduleName: "foo/title"` here.
Its useful when you want to 'inject' it inside some other hierarchy (than what its filename implicitly defines it as), eg you want to have `'foo/bar' as a separate package `foo_bar.js` but correctly register its self on your dependency tree.

You can even load such a combined file with `moduleName` via plain script eg `<script src='foo_bar.js'>`, without RequireJS throwing the `Error: Mismatched anonymous define()` and then you can do a `require(['foo/bar', function(foo_bar){ foo_bar.doStuff()})`.

Be careful with it though, cause RequireJS sometimes **silently fails** in some cases, if there's a mismatch between the declared `moduleName` and the name it would give it if it were anonymous when another module requires it. Its complicated and rough, as many things in AMD :-(

#### Example

   moduleName: 'foo/bar'.

### build.template.banner

Adds a banner at the top of either your `bundle.main` UMD/AMD/nodejs file, or the top of the combined file.

It works perfectly along with the [`build.optimize: true`](#build.optimize), knowing when to concat it. This has many positive implications, so for example when the rjs optimizer is used on the combined file, you can have a `build: rjs: preserveLicenseComments: false` to strip all other banners included in the bundle but yours which is added at the end of the process (but watch out for license deprivation).

The value can be of 4 different types:

* `String`: concatenated as-is.

* `Boolean`: a `true` value creates a default banner out of your `package.json` using `name, version, homepage, author, description, license/licenses, repository` and current date.

* `Object`: a hash with values resembling a `package.json`, using the default banner generator above.

* `Function(package, bower, bundle, build)`: is called with these parameters so you can build your own banner generator function that should return a `String`.

#### Examples

   banner: true

   banner: "/** I am a banner on top */"

   banner: {name: "MyProject", version: "2.0-beta"}

   banner: function(pkg) { return "/**" + name + " v" + version + "*/"; }

### build.template.debugLevel

Template debug - outputs section comments. Values are in the range of 10, 20, 30.
Multiply those by 10 and you'll get `console.log`s of sections while they load.
Highly experimental and for hard core debugging only!

#### Example

   debugLevel: 0

@see *Conversion Templates* in docs.

@default

      template: 'UMDplain'

## build.runtimeInfo

Adds `__isAMD`, `__isNode` & `__isWeb` variables to your modules, so you can easily determine the execution environment your module is running in.

For example they can be used to select a different execution branch, depending on where the module is executing. Make sure to add modules that are nodejs-only to [`bundle.dependencies.node`](#bundle.dependencies.node) so they aren't loaded in AMD (i.e not added to `define()` dependency array).

See a Q&A / tutorial on how this helps nodejs/browser cross development at [stackoverflow.com](http://stackoverflow.com/questions/22512486/nodejs-browser-cross-development).

@note ['combined' template](combined-template) always has `runtimeInfo` enabled cause it it.

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

@example `runtimeInfo: ['index', 'libs/**/*']`

      runtimeInfo: true

## build.bare

Like coffeescript `--bare`:

* if `bare: false` (*the default*), it encloses each module in an Immediately Invoked Function Expression (IIFE):

  ```
  (function () {
    .....
  }).call(this);
  ```

* if `bare: true` it doesn't.

The IIFE is just a top-level safety wrapper used to prevent leaking and have all variables as local to the module and to provide the [`build.globalWindow`](#build.globalWindow) functionality.

@note if `bare: true`, then [`build.globalWindow`](#build.globalWindow) **functionality is disabled**.

@note It doesn't apply to ['combined' template](combined-template): your modules & almond are always enclosed in a single IIFE, and `windows === global` is always true and the modules themselves are plain `define(...)` calls.

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

      bare: false

## build.useStrict

Add the famous `'use strict';` so you don't have to type it at each module.

Its added either at:

* the begining of each module's body, for modules that [pass filespecs](types-and-derive#booleanOrFilespecs) or to all modules if `build.useStrict: true`.

* once at the closure of the ['combined' template](combined-template), only if the value is `true`.

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

@default is `undefined`, which doesn't inject `use strict;` on any module, BUT in [combined template](combined-template) it enables the corresponding [rjs config `useStrict: true`](https://github.com/jrburke/r.js/blob/master/build/example.build.js). Effectively this allows 'use strict;' on the modules that already have it. Use `false` to give a false on rjs, which strips them off and `true` to inject it once on the combined template or on each module in UMD/AMD/nodejs (even if modules already have it).

      useStrict: undefined

## build.globalWindow

Allow `global` & `window` to be `global === window`, whether on nodejs or the browser. It works independently of [`build.runtimeInfo`](#build.runtimeInfo) but **it doesn't work if [`build.bare`](#build.bare) is `true`**. It uses the IIFE that's enclosing modules to pass `'window'` or `'global'` respectively.

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

@note the `global === window` functionality is always true in ['combined' template](combined-template) - `false`-ing it makes no difference!

      globalWindow: false

## build.injectExportsModule

Always inject `exports, module` as dependencies on AMD/UMD templates from modules that are originally AMD (it *always* inject them on originally nodejs/commonjs modules).

Having `exports` around solves the **[circular dependencies](http://stackoverflow.com/questions/4881059/how-to-handle-circular-dependencies-with-requirejs-amd) problem [with AMD](http://requirejs.org/docs/api.html#circular)**, so its enabled by @default as `true`.

@note to make this commonjs circular dependencies workaround work (see it in [requirejs docs](http://requirejs.org/docs/api.html#circular)), you need to **export only the plain `{}`** that `exports` already points to, not a `function` or any other value of your own. Eg you do only a `exports.myKey = 'myValue' and NOT an `module.exports = "my module value"`

@note uRequire fixes the AMD mandate that you still need to `return exports` or `return module.exports` that both point to {the:'module'} from the AMD factory (not just setting `module.exports = {the:'module'}`). With uRequire conversion you can use exports as you normally do with nodejs/commonjs modules, and never return it even from AMD modules.

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

@note modules originally `nodejs` and converted to `AMD`/`UMD` always have `exports, module` injected anyway, and ALL converted modules always get a `require` dependency, so you never have declare any of the 3 stooges.

@optional changing the @default being `true`, would save a few bytes in each module definition, with the cost of falling into the circular dep trap and having to `return exports` etc. Advice is to leave it on, and *never manually type* `define(['require', 'exports', 'module', ..], function(require, exports, module, ..){..}` etc again!

      injectExportsModule: true

## build.rootExports

Holds keys relating to how `bundle.dependencies.rootExports` are build into the converted modules.

      rootExports:

## build.rootExports.ignore

When evaluating to true for a module, it doesn't produce the boilerplate for [exporting modules (& `noConflict`())](exporting-modules). It ignores both :

 * `{ rootExports: ['persons', 'personsModel'] }` on top of `'models/PersonsModel.js'`.

 * [`bundle.dependencies.rootExports`](#bundle.dependencies.rootExports)

 * build.rootExports.runtimes (see below)

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

@alias `build.noRootExports` DEPRECATED

        ignore: false

## build.rootExports.runtimes

Builds modules in such a way that exporting `bundle.dependencies.rootExports` on root (i.e `window`/`global`) works only on the declared runtimes (among `'AMD'`, `'node'` and `'script'`).

@type Array with one or more among `'AMD'`, `'node'` and `'script'`, which represent the 3 common runtimes.

@derive none - child simply overwrites parent

@example if you want the root exports to work both when running as `script` (eg. `combined` template or [`noLoaderUMD`](#noLoaderUMD) ) but also on when `AMD` loader is used (see rationale in [`amdWebGlobal` UMD variant](https://github.com/umdjs/umd/blob/master/amdWebGlobal.js#L22), use `['AMD', 'script']`.

@note if you specify an empty array `[]`, its effectively like having `build.rootExports.ignore: true`.

@optional

@alias `build.exportsRoot` DEPRECATED

@default is to export only on 'script', not on node's `global` object and not on `window` when loading through AMD.

        runtimes: ['script']

## build.rootExports.noConflict

Controls the generation of the `noConflict` code - considered only when of `bundle.dependencies.rootExports` is present, in which case it overrides the `noConflict` value declared in the module it self (as described in [Exporting Modules](Exporting-Modules)).

        noConflict: true

## build.scanAllow

By default, ALL `require('missing/NodeStyle/Dep')` in your module are added on the dependency array `define(['existingArrayDep',.., 'missing/NodeStyle/Dep'], ...)`.

That's because, even if there is even one dep on the deps array, [runtime scan is disabled on RequireJs](https://github.com/jrburke/requirejs/issues/467#issuecomment-8666934). So, if any `require('dep1')` is not in that AMD deps array, requirejs loading halts. uRequire adds them all to prevent this problem, even if your have ommited them (and well you did, DRY is a virtue).

With `scanAllow: true` you allow the `require('')` scan of requirejs that happens either at runtime (costs at starting up) or when using the [combined-template](combined-template) at the rjs / almond optimization stage. This is meaningful **only for source modules that have no other `define([])` deps (even injected)**, i.e. modules using ONLY `require('')`, either written as a pure nodejs module or AMD.

@note: uRequire disables `scanAllow` per module, for modules having any of these :

 * [`rootExports` / `noConflict()`](exporting-modules)

 * [`bundle.dependencies.imports`](#bundle.dependencies.imports)

 * [injected deps](resourceconverters.coffee#inject-replace-dependencies)

 * [node-only deps](#bundle.dependencies.node)

all for a good reason.

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

      scanAllow: false

## build.allNodeRequires

Pre-require all `require('')` deps on node, even if they aren't mapped to any parameters, just like they are pre-loaded as AMD `define()` array deps. It preserves the same loading order as on Web/AMD, with a trade off of a possible slower starting up (they are cached nevertheless, so you gain speed later).

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

      allNodeRequires: false

## build.dummyParams

Add dummy params `__dummy__param__n` for deps that have no corresponding param in the AMD define array. Should not be needed but might solve some issues with dependencies not loading on nodejs.

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

      dummyParams: false

## build.noLoaderUMD

Allow modules to execute and register their exports (as defined in [`bundle.dependencies.rootExports`] or [rootExports](Exporting-Modules)), even when running without an AMD or CommonJS loader, i.e it runs on a browser via `<script src='my/UMDModule.js'>`. It works only:

 * on 'UMD' and 'UMDplain' templates.

 * if module has local/global dependencies only (eg `'underscore'`) and those have already load them selves (eg as `window._`).

If the UMD module has bundle deps (eg `'my/models/Person'`) it needs an AMD loader and loading as `<script src="require.js" data-main="MainModule">`.

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

      noLoaderUMD: false

## build.warnNoLoaderUMD

Provides a warning when a UMD module is loaded as <script>, but the `build.noLoaderUMD` generated code is missing.

@default true as a warning to new users, advice is to turn it off & save space (when you know AMD or CommonJs loader is present).

@see [`build.noLoaderUMD`](#build.noLoaderUMD)

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

      warnNoLoaderUMD: true

## build.watch

Watch for changes in bundle files and reprocesses *only* changed ones.

The *watch feature* of uRequire works with:

* Standalone urequireCmd, setting `watch: true` or -w flag.

* Instead of `watch:true`, you use [grunt-urequire >=0.7.x](https://github.com/aearly/grunt-urequire) & [grunt-contrib-watch >=0.5.x](https://github.com/gruntjs/grunt-contrib-watch).

@note In `grunt-urequire`, at each `watch` event there is a *partial build*. The first time a partial build is carried out, a full build is automatically performed instead. **You don't need (and shouldn't) perform a full build** before the watched task (i.e dont run the `urequire:xxx` grunt task before running `watch: xxx: tasks: ['urequire:xxx']`). A full build is always enforced by urequire.

@type `truthy`/`falsey` OR `Integer` which the [`_.debounce wait`](https://lodash.com/docs#debounce) (in milliseconds) after each file watch event (works *only* when using [urequire's](https://github.com/anodynos/uRequire-cli) watch instead of grunt's. Effectively its how long to wait to start the build, after each file watch event. DebounceWait defaults to `1000` otherwise.

      watch: false

## build.verbose

Print bundle, build & module processing information.

@type: Boolean

@todo: make it less verbose / work better with `build.debugLevel`

      verbose: false

## build.debugLevel

Debug levels *1-100*.

@todo: make it less verbose - reassign levels

      debugLevel: 0

## build.continue

Dont bail out while processing when there are **soft / module processing errors**.

For example ignore an RC conversion error or a missing dependency and just do all the other modules.

@note: Not needed when `build.watch` is used - the `continue` behaviour is applied to `build.watch`.

      continue: false

## build.optimize

Optimizes output files (i.e it minifies/compresses them for production).

@type

* *false*: no optimization.

* *true*: uses sane defaults of 'uglify2' to minify/compress.

* 'uglify2' / 'uglify': specifically select either (with default settings).
  **@note: 'uglify' works ONLY for ['combined' template](combined-template), delegating options to `r.js`.**

* Object - just like ['uglify'](https://github.com/jrburke/r.js/blob/f021df4d2b68/build/example.build.js#L138-154) or ['uglify2'](https://github.com/jrburke/r.js/blob/f021df4d2b68/build/example.build.js#L161-176).

@example

* `optimize: true` - simplest, minifies with 'uglify2' defaults.

* Passing options to [uglify2](https://github.com/mishoo/UglifyJS2), works the same on all templates & r.js optimization.

```
  optimize:
    uglify2:
      output: beautify: true
      compress: false
      mangle: false
```

      optimize: false
      _optimizers: ['uglify2', 'uglify']

## build.out

Callback to pass you the [`converted`](resourceconverters.coffee#converted) content & [`dstFilename`](resourceconverters.coffee#dstFilename) of each resource/module, instead of saving to filesystem under [`dstPath`](#build.dstPath)/[`dstFilename`](resourceconverters.coffee#dstFilename) via [`FileResource.save()`](resourceconverters.coffee#save).

@note: Its not working on the resources when ['combined' template](combined-template) is used, cause r.js optimizer doesn't yet work *in-memory*, so the files *have to* be saved for the r.js optimization to work.

@type `function (dstFilename, converted){}`

@default undefined - uses [`FileResource.save()`](resourceconverters.coffee#fileresource-methods) instead.

      out: undefined

## build.afterBuild

This is set by either *urequireCMD* or [grunt-urequire](https://github.com/aearly/grunt-urequire) to signify the end of a build.

      afterBuild: []

@alias `done` DEPRECATED (but still supported)

## build.clean

Clean directory or destination files in `build.dstPath`.

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs)

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

### clean rules

On every initial / full build:

If `clean: 'true'`,

  * on non-combined template builds, the whole `build.dstPath` directory is removed before reading anyfiles, just like a `grunt:clean` task against the directory.

  * on combined template, only the `combined.js` file (and possible leftover temp directory) is deleted (cause your directory might contain other files).

If `clean` is a [filesspec type](types-and-derive#filespecs) (eg `clean: ['some/**/file.someext', '!', (f)-> f is 'dontDeleteMe.txt']), only files passing the filespecs filter are deleted in any case (along with any possible leftover combinedFile temp directory).

On subsequent partial builds, **no files are deleted**.

      clean: true

## build.deleteErrored

Delete destination files when their source is at an error state. Useful when watching builds or when the directory is not [clean](#build.clean).

@note One successful conversion of the source file needs to be in place for `dstFilename` to be established.

@note On ['combined' template](combined-template), it also deletes the last `combinedFile.js` that was build.

@type [booleanOrFilespecs](types-and-derive#booleanOrFilespecs). Note: filespecs refer to **source** filenames (but of course only their corresponding destination files are deleted, not the source ones).

@derive [arraysConcatOrOverwrite](types-and-derive#arraysConcatOrOverwrite)

      deleteErrored: true

## build.rjs

The [r.js config] https://github.com/jrburke/r.js/blob/master/build/example.build.js,
when combining with r.js ([combined template](combined-template)).

Its keys are just `_.defaults` for urequire's idea about using r.js with combined template, *so use with caution*!

@stability 2

@example `build: rjs: preserveLicenseComments: false`

      rjs: undefined

# Examples

Borrowed from the [Grunt config with comments](https://github.com/anodynos/uBerscore/blob/master/Gruntfile.coffee) of [uBerscore](github.com/anodynos/uBerscore), which also powers uRequire.

The `'urequire: uberscore'` task:

  * read from `source`, write to `build`

  * filters some `filez`

  * converts each module in `path` to UMD (the default)

  * copies all other files to `build`

  * injects losash dep as `_` in each module

  * exports a global `window._B` with a `noConflict()`

  * injects a VERSION string inside the body of a file

  * adds a banner to main (ouside UMD template/minification)

  * cleans (deletes) `dstPath` before starting the build

  * watch changes, convert only what's really changed

```coffee
# config is .json, .js, gruntjs task, .coffee, .yml, you name it
uberscore:                    # serves as 'name' & consequently 'main'
  path: 'source'
  dstPath: 'build'
  filez: ['**/*']             # can be RegExp, Function, exclusion etc
  copy: [/./]                 # copy non-converted files, only if changed
  main: 'uberscore'
  dependencies:
    exports:
      bundle: 'lodash': '_'   # _ will always be there for you
      root: 'uberscore': '_B' # _B will always be there for everyone
  resources: [                # simple manipulative concat
    [ '+inject:VERSION',      # isBeforeTemplate: true, i.e AST is parsed & a module is there!
      ['uberscore.js'],       # only on this module, inject the following
      (m)-> m.beforeBody = "var VERSION = '0.0.15';"]
  ]
  template: banner: "// uBerscore v0.0.15"
  clean: true
  watch: true
```

Now, lets derive from the above and:

  * Use ['combined' template](combined-template)

  * adds a banner on top of the main / build file

  * all modules go into one file that runs everywhere

```
dev:
  derive: ['uberscore']
  template:
    name: 'combined'
    banner: '// I am a banner that goes on top'
  dstPath: 'build/uberscore-dev.js'
```

Finally the `'urequire: min'` task

* derives all from `'urequire: dev'`, with differences:

* filters some more `filez`

* converts to a single `uberscore-min.js` with ['combined' template](combined-template)

* injects deps (*different* than parent's)

* manipulates each module:

  * replaces 'lodash' with 'underscore' (for compatibility, mocking etc)

  * removes all debuging code, matching *skeletons*

  * removes code (eg debug stuff ) and a dependency from a specific file.

* disables runtime info, for all but one files

* minifies the combined file, with some `uglify2` options


```coffee
min:
  derive: ['uberscore']
  filez: [ '!**deepExtend.coffee' ]
  dstPath: 'build/uberscore-min.js'
  dependencies:
   exports: bundle: [
      [null], 'underscore', 'agreement/isAgree']
   replace: 'underscore': ['lodash']
  resources: [
  [
     '+remove:debug/deb & deepExtend', [/./]
     (m)->
       # match each of these code *skeletons*
       for code in [ 'if (l.deb()){}', 'if (this.l.deb()){}',
                     'l.debug()', 'this.l.debug()']
         # replace with undefined, i.e delete
         m.replaceCode code
       #
       # replace AST maching code & a dependency
       # from a specific file
       if m.dstFilename is 'uberscore.js'
         m.replaceCode
           type: 'Property'
           key: {type: 'Identifier', name: 'deepExtend'}
         # remove this dependency
         m.replaceDep 'blending/deepExtend'
   ]
  ]
  runtimeInfo: ['!**/*', 'Logger.js']
  optimize: { uglify2: output: beautify: false }
```

Finally we easily configure our `grunt-contrib-watch` tasks

```
watch:
  UMD:
    files: ["source/**/*"]
    tasks: ['urequire: uberscore', 'urequire: spec', 'mocha']
  options: spawn: false
```
