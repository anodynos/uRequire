# Introduction

The *master & defaults* configuration file of *uRequire*.

## Note: Literate Coffescript

This file is written in [Literate Coffeescript](http://ashkenas.com/literate-coffeescript): it serves both as *markdown documentation* AND the *actual code* that represents the *master config*. The code blocks shown are the actual code used at runtime, i.e each key declares its self and sets a default value.

    module.exports = MasterDefaultsConfig =

NOTE: This file primary location is https://github.com/anodynos/uRequire/blob/master/source/code/config/MasterDefaultsConfig.coffee.md & copied over to the urequire.wiki - DONT edit it separately in the wiki.

## Config Usage

A `config` determines a `bundle` and a `build` that uRequire will process. A config is an object with the expected keys and can be used as:

* **File based**, using the urequire CLI (from `npm install urequire -g`) as `$ urequire config myConfig.js`, where `myConfig.js` is a node module file that exports the `config` object. The file can actually be a `.coffee` or `.js` node module, or a `.json` file as well as many other formats - see [butter-require](https://github.com/anodynos/butter-require).
 The value of an 'XXX' ['derive'](#derive)d parent in a file-based config can be another file `configFilename.yml`, relative to the 1st children's path. @todo: make relative to each children's path).

* Using [**grunt-urequire**](https://github.com/aearly/grunt-urequire), having (almost) the exact `config` object of the file-base, but as a `urequire:XYZ` grunt task. The main difference is that a XXX ['derive'](#derive)d parent in grunt-urequire config can be another `urequire:XXX` task, and if none is found then its assumed to be a filename, relative to grunt's config.

* Within your tool's code, [using `urequire.BundleBuilder`](Using-uRequire#Using-within-your-code).

## Versatility

uRequire configs are extremely versatile:

* understands keys both in the 'root' of your config *OR* in ['bundle'/'build' hashes](MasterDefaultsConfig.coffee#bundle-build)

* provides short-cuts, to convert simple declarations to more complex ones.

* has a unique inheritance scheme for 'deriving' from parent configs.

## Deriving

A config can **inherit** the values of a parent config, in other words it can be **derived** from it. Its similar to how a subclass *overrides* a parent class in classical OO [(but much better)](#Deeper-Behavior).

### Parents & Children

For example if you have a child `DevelopementConfig` derived from a parent `ProductionConfig`, then the child will inherit all the values/defaults and perhaps override (or ammend, append etc) the values of the parent. A child can inherit from one or more Parents, with precedence given to whichever parent comes first.

Ultimately all configs are derived from `MasterDefaultsConfig` (this file) which holds all default *parent-y* values.

### Deeper Behavior

Derivation is but much more flexible that simple OO inheritance in classical OO platforms :

  * It inherits deeply all keys, i.e `{a:b1:0, b4:4}` <--deriveFromParent-- `{a:{b1:1, b2:2}}` gives `{a:{b1:1, b2:2, b4:4}}`

  * At each key of the deep derivation, there might be a different **behavior** for how to *blend* or *integrate* with the parent's existing data - eg [see ArrayizePush in @derive](#ArrayizePush).


# @ tags legend

Each key description might have some of these tags, starting with @:

## @derive

Describes the derive behavior, i.e how values are derived from other parent configs.

**Standard derivation behaviors** are listed here:

#### ArrayizePush

Both source and destination values are [_B.arrayize](https://github.com/anodynos/uBerscore/blob/master/source/code/collections/array/arrayize.co)-ed first.

Then the items on child configs are pushed *after* the ones higher up.

For example consider key `bundle.filez` (that has the **arrayizePush derive behavior**).

* parent config `bundle:filez: ['**.**', '!DRAFT/*.*']`

* child config `bundle:filez: ['!vendor/*.*]`

* blended config: `bundle: filez: ['**.**', '!DRAFT/*.*', '!vendor/*.*]`. Use your imagination for the possiblities.

###### type

The type for both src & dst (child and parent respectively) are either `Array<Anything>` or `Anything` (but Array, which is arrayized first).

###### reset parent

To reset the inherited parent array (always in your new destination array), use `[null]` as the 1st item of your child array. For example

* parent config `bundle:filez: ['**.**', '!DRAFT/*.*']`

* child config `bundle:filez: [[null], 'vendorOnly/*.*]`

* blended config: `bundle: filez: ['vendorOnly/*.*]`.

@todo: use a function callback on child, that receives parent value (& a clone:-) and returns the resulted blended array.

##### ArrayizeUniquePush

Just like [*ArrayizePush*](#ArrayizePush), but only === unique items are pushed to the result array.


### @stability: (1-5)
A [nodejs-like stability](http://nodejs.org/api/documentation.html#documentation_stability_index) of the setting. If not stated, its assumed to be a "3 - Stable".

### @optional

setting this key is optional, unless otherwise specified.

### @todo:
This file is documentation & code. `@todo`s should be part of any code and a great chance to highlight future directions! Also watch out for **NOT IMPLEMENTED** features - its still v0.x!

### @type

A description of valid value type(s) - usually there is a lot of flexibility of the types of values you can use.

### @alias

Usually DEPRECATED (but still supported) keys.

### @note

Any other note that requires attention

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

@alias `bundleName` DEPRECATED

      name: undefined

## bundle.main

The `'main'` or `'index'` module file of your bundle, that `require`s and kicks off all other modules (perhaps implicitly).

@optional and useless, unless 'combined' template is used. 

### Details:

* `bundle.main` is used as 'name' / 'include' on RequireJS build.js, on [combined/almond template](combined-Template).

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

@alias `bundlePath` DEPRECATED

      path: undefined

## bundle.filez

All files that somehow participate in the `bundle` are specified here.

@optional 

@type filename specifications (or simply filenames), expressed in either:

  * *gruntjs*'s expand minimatch format (eg `'**/*.coffee'`) and its exclusion cousin (eg `'!**/DRAFT*.*'`)
  
  * `RegExp`s that match filenames (eg `/./`) again with a `[..., '!', /regexp/]` exclusion pattern.

  * A `function(filename){}` callback, returning true for filename argument to be included. Consistently it can have a negation/exclusion flag before it, `[..., '!', function(f){return f === 'allowMe.js'}, ...]`

@example 
```
bundle: {
  filez: [
    '**/recources/*.*'
    '!dummy.json'
    /\.someExtension$/i
    '!', /\.excludeExtension$/i
    (filename)-> filename is 'includedFile.ext'
  ]
}
```

@derive: [ArrayizePush](#ArrayizePush).

@note all files are relative to [bundle.path](#bundle.path)

@note the `z` in `filez` is used to segregate from gruntjs `files`, when urequire is used within [grunt-urequire](https://github.com/aearly/grunt-urequire) and allow its different features like RegExp & deriving.

@note: The master default is `undefined`, so the highest `filez` in derived hierarchy determines what is ultimately allowed.

@default: NOTE: The actual default (runtime hard-coded), if no `bundle.filez` exists in the final cfg, is `['**/*.*']` (and not `undefined`). That's why its optional!

@alias `filespecs` DEPRECATED

      filez: undefined

## bundle.resources

An Array of [**ResourceConverters (RC)**](ResourceConverters.coffee) (eg compilers, transpilers etc), that perform a conversion on the `bundle.filez`, from one resource format (eg coffeescript, teacup) to another **converted** format (eg javascript, HTML).

**ResourceConverter** is a generic and extendible in-memory conversions workflow, that is trivial to use and extend with your own, perhaps one-liner, converters (eg `['$coco', [ '**/*.co'], ((r)-> (require 'coco').compile r.source), '.js']` is an RC).

The workflow unobtrusively uses `bundle` & `build` info like paths and is a highly *in-memory-pipeline* and *read-convert-and-save only-when-needed* workflow, with an integrated [`build.watch`](MasterDefaultsConfig.coffee#build.watch) capability (grunt or standalone).

Read all about them in [**ResourceConverters.coffee**](ResourceConverters.coffee).

**Quick notes on RCs:**

* Each file in [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) that is matched by an RC is considered a [`Resource`](resourceconverters.coffee#fileresource-extends-bundlefile) that needs `convert()`-ing.

* All non-matching filez are just [`BundleFile`](resourceconverters.coffee#bundlefile)s - useful for *declarative sync [`bundle.copy`](MasterDefaultsConfig.coffee#bundle.copy)ing at each build*.

@optional unless you want to add you own *Resource Converters* for your conversion needs.

@derive [ArrayizePush](#ArrayizePush). You can use [null] as the 1st item to reset inherited array items (i.e the ResourceConverters defined in parent configs).

@stability: 3 - Stable

@type An Array<ResourceConverer>, where a `ResourceConverter` can be either :

* an ['Object'](ResourceConverters.coffee#Inside-a-Resource-Converter), for [boring formal RC definitions](ResourceConverters.coffee#The-formal-Object-way-to-define-a-Resource-Converter).

* an ['Array'](ResourceConverters.coffee#The-alternative-less-verbose-Array-way) (for fancy RC-specs)

* a 'String' name search of a previously registered RC, eg `'teacup'`.

* a function that returns an RC. This function is called with the 1st argument & `this` with a *searchOrMaterialize*  function that takes a String name (or an Array-spec) of an RC and returns a looked up (or materialized RC). For example:

```javascript
// example - not part of coffee.md source
// as comments cause literate coffeescript considers
// indented lines as code, even in ` ` ` blocks
//
// resources: [
//  ...
//  function(){
//    // lookup & clone RC (best use rc.clone(), to get proper instance)
//    rc = this("RCname4").clone();
//
//    // change its name & type to 'module' (via '$' flag)
//    // a shortcut to this is `rc = this("$RCname4").clone();`,
//    // which searches and changes name.
//    rc.name = '$MyRCname4';
//
//    // add some file specs to `filez`
//    rc.filez.push('!**/DRAFT*.*');
//    // return the new RC.
//    return rc;
//  }
//  ...
//  ]
```      
    
If the function returns null or undefined, its not added to the Array.

**Important**: The **order of RCs in `resources` does matter**, since *only the last matching RC determines the [actual class](ResourceConverters.coffee#Attaching-some-clazz))* of the created resource (file). 

@example 

A dummy example follows (in coffeescript) :
```
# example - not part of coffee.md source
resources:
[
# search registered RC 'teacup' & use as-is
'teacup'

# search, clone, change, return in one line
-> tc = @('someRC').clone(); tc.filez.push('**/*.someExt'); tc

# define a new RC, with the fancy [] RC-spec
['$coco', ['**/*.co'], ((r)-> require('coco').compile r.source), '.js']

# define a new RC, with the grandaddy {} RC-spec
{
 name: 'kookoo'
 type: 'module'
 filez: [ '**/*.koo']
 convert: (r)-> require('kookoo').compile r.source
 convFilename: '.js'
}

# define a new RC, and reuse an existing
# with the magic search-create-alter function
# passed as `this` (@ in coffeescript)
->
  # lookup an existing
  kookoo = @ 'kookoo'

  # generate a new one, that uses `kookoo.convert`
  # and return it (note coffeescript returns last expression)
  @ ['$doodoo', [ '**/*.doo'], kookoo.convert, '.js']
]
```

@default By default `resources` has ResourceConverters
  `'javascript', 'coffee-script', 'LiveScript', 'iced-coffee-script' and 'coco'`
as defined in [Default Resource Converters](ResourceConverters.coffee#Default-Resource-Converters).

Also an [extra 'teacup' RC is registered](ResourceConverters.coffee#Extra-Resource-Converters), but not added to 'resources' - it can be used by searching for 'teacup'. More [Extra Resource Converters](ResourceConverters.coffee#Extra-Resource-Converters), will be added in future uRequire versions - feel free to contribute yours with a PR!

      resources: require('./ResourceConverters').defaultResourceConverters

## bundle.copy

Copy (binary & sync) of all non-resource [bundle.filez](MasterDefaultsConfig.coffee#bundle.filez) (i.e those that are [`BundleFile`]((MasterDefaultsConfig.coffee#bundlefile)s) to [`build.dstPath`](MasterDefaultsConfig.coffee#build.dstpath) as a convenience. If destination exists, it checks nodejs's `fs.statSync` 'mtime' & 'size' and copies (overwrites) ONLY changed files.

@optional

@example `copy: ['**/images/*.gif', '!dummy.json', /\.(txt|md)$/i]`

@type see [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez)

@derive [ArrayizePush](#ArrayizePush).

@alias `copyNonResources` DEPRECATED

@default `[]`, i.e no non-resource files are copied. You can use `/./` or `'**/*.*'` for all non-resource files to be copied.

      copy: []

## bundle.webRootMap

For dependencies that refer to web's root (eg `'/libs/myLib'`), it maps `/` to a directory on the file system **when running in nodejs**. When running on Web/AMD, RequireJS maps it to the **http-server's root** by default (eg http://example.com/).

`webRootMap` can be absolute or relative to [`bundle.path`](MasterDefaultsConfig.coffee#bundle.path). - it defaults to bundle.

@optional 

@example "/var/www" or "/../../fakeWebRoot"

@note `webRootMap` is not (yet) working with `combined` template.

      webRootMap: '.'

## bundle.dependencies

All information related to dependencies handling is listed here.

      dependencies:

### bundle.dependencies.node

Dependencies listed here are treated as node-only, hence they aren't added to the AMD dependency array (and hence not available on the Web/AMD side). Its up to your code to make sure the dep is not used outside node (you can use `__isNode`, `__isAMD`, `__isWeb` globals available in uRequire compiled modules.)

Its the same as using the `node!` fake plugin, eg `require('node!my_fs')`, but probably more useful cause your code can execute on nodejs without the template conversion that strips 'node!'.

@type String or Array<String>

@derive [ArrayizeUniquePush](#ArrayizeUniquePush).

@example `node: ['myUtil', 'my_fs']`

@alias noWeb DEPRECATED

@default All known built-in nodejs packages (as of 10.8) like `'util'`, `'fs'` etc are the default of  `bundle.dependencies.node`. Use `node: [[null], 'myNodeModule']` to reset the `node` array with only your modules.

@todo: Default can lead to in-advertised feature leak if there's a user's module with these names - issue a warning ?

        node: [
          'fs', 'events', 'util', 'http', 'path', 'child_process',
          'events', 'crypto', 'string_decoder', 'timers', 'tls'
          'domain', 'buffer', 'stream', 'net', 'dgram', 'dns',
          'https', 'url', 'querystring', 'punycode', 'readline',
          'repl', 'vm', 'assert', 'tty', 'zlib', 'os', 'cluster'
        ]

### bundle.dependencies.depsVars

Its an optional field, mainly as a *type reference* and a retrospection / backup (when dep-vars binding can't be inferred). 

It lists dependencies that bind with one or more variable names - for example 'underscore' binds with '_', jquery binds with '$' and so on. 

Variable names can be inferred from the code by uRequire, when you used this binding implicitly in your bundle, for example `define(['jquery'], function('$'){...})` or `var $ = require('jquery')` binds variable `$` with dependency `'jquery'`. You can choose to list them here for introspection (if it can't be inferred), but its otherwise useless.

Binding variables are useful when injecting dependencies, when exporting through [`bundle.dependencies.exports.bundle`](#bundle.dependencies.exports.bundle), when converting through 'combined' template etc. 

For example, global dependencies (like 'underscore' or 'jquery') are by default not part of a `combined` file. Each global dep has one or more variables it is exported as (binds with), eg `jquery: ["$", "jQuery"]`. At run time, when running on web side as a standalone .js <script/>, the script will _grab_ the dependency using the binding variable (eg '$') from the global object.

@optional

@type the **formal depsVars type** is: 

 * Object: `{ dep1: ['dep1VarName1', 'dep1VarName2'], dep2:['dep2VarName1', ...], ...}`

Alternative @type: `depsVars` type is used in many other places (eg [`bundle.dependencies.exports.bundle`](#bundle.dependencies.exports.bundle) and can be have any of these types: 
 
 * Array: eg `['dep1', 'dep2', ..., 'depn']`, in which case the variables these deps bind with are inferred by the code (or `bundle.dependencies.depsVars`, `bundle.dependencies._knownDepsVars` and so on) .

 * String: eg `'dep'`, with just one dep, again with inferred binding variable(s).

@derive Each dependency name/key of child configs is added to the resulted object, if not already there. Its variables are then [ArrayizeUniquePush](#ArrayizeUniquePush)-ed onto the array.

For example with a parent `{myDep1: ['myDep1Var1', 'myDep1Var2']}` and a child `{myDep1: ['myDep1Var1', 'myDep1Var3'], myDep2: 'myDep2Var'}` the result derived object will be `{myDep1: ['myDep1Var1', 'myDep1Var2', 'myDep1Var3'], myDep2: ['myDep2Var']}`.

@note In case variable names can't be inferred for a global dependency (i.e you only used `require('myGlobalDep')` and not assigned it to any *variable*), and aren't in `bundle.dependencies.depsVars` (or `_knownDepsVars` below), 'combined/almond' build will fail cause it will not know where to grab it from when running on web without an AMD loader.

@alias variableNames DEPRECATED

        depsVars: {}

### bundle.dependencies._knownDepsVars

Some known depsVars, have them as backup - its a private field, not meant to be extended by users (use depsVars).

@type see [`bundle.dependencies.depsVars`](MasterDefaultsConfig.coffee#bundle.dependencies.depsVars)

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

### bundle.dependencies.exports

Holds keys related to binding and exporting modules (i.e making them available to other modules, via a variable name)

        exports:

#### bundle.dependencies.exports.bundle

Allows you to export (i.e have available) modules throughout the bundle (eg 'underscore', 'Backbone' etc) under given variable names.

Each dependency will be available in the *whole bundle* under varName(s) - i.e they will be like *globals* to your bundle. Effectively this means that each module will have an *injection* of all `dependencies.exports.bundle` dependencies/var bindings, so you don't have to list them in each module.

@type see [`bundle.dependencies.depsVars`](MasterDefaultsConfig.coffee#bundle.dependencies.depsVars)

@derive see [`bundle.dependencies.depsVars`](MasterDefaultsConfig.coffee#bundle.dependencies.depsVars)

@example 
```
    {
     'underscore': '_', 
     'jquery': ["$", "jQuery"], 
     'models/PersonModel': ['persons', 'personsModel']
    }
``` 
will make 'underscore', 'jquery', and 'models/PersonModel' dependencies and all their corresponding variables injected in each module (or the bundle's closure if `'combined'` template is used). So in each module, you can safely access `persons`, without ever having to list it as a dependency.

You can also use the short format: 
```
 ['underscore', 'jquery', 'models/PersonModel']
```
in which case the variable names these dependencies bind with (and are exported throughout the bundle) are inferred.

@alias `bundleExports` DEPRECATED

          bundle: {}

#### bundle.dependencies.exports.root

Make a module be available GLOBALY (i.e `window` object) under varName(s), same as in (Exporting-Modules)[Exporting-Modules]).

Access via plain `varName` works both in browser and nodejs. On browser its attached as a property to `window` object, in nodejs its attached to the 'global' object with the same effect: accessing it via its name from everywhere. 

Both 'window' and 'global' objects exist as an alias of each other on the 'combined' template.

When `dependencies.exports.root` is used (instead of precise (Exporting-Modules)[Exporting-Modules]), `noConflict` is always true.

@example

  `{'models/PersonModel': ['persons', 'personsModel']}`

is like having a

  `({rootExports: ['persons', 'personsModel'], noConflict:true});`

in module 'models/PersonModel'.

          root:{}

### bundle.dependencies.replace

Replace all right hand side dependencies (String value or []<String> values), to the left side (key) in the build modules.

@example

  `{lodash: ['underscore', '_underscore']}`

replaces all 'underscore' or '_underscore' deps to 'lodash', in all modules.

@type:

  `{ newDep1Name: ['oldDep1Name1', 'oldDep1Name2'], newDep2Name: 'oldDep2Name1'...}`


@derive paradoxically its like [`bundle.dependencies.depsVars`](MasterDefaultsConfig.coffee#bundle.dependencies.depsVars)

@see [inject / replace dependencies](resourceconverters.coffee#inject-replace-dependencies)

          replace: undefined

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

@alias `outputPath` DEPRECATED

      dstPath: undefined


## build.forceOverwriteSources

Output on the same directory as the _source_ [`bundle.path`](MasterDefaultsConfig.coffee#bundle.path), overwriting all files. Useful if your sources are not *real sources*.

@note: Be warned that when `true`, [build.dstPath](MasterDefaultsConfig.coffee#build.dstPath) is ignored and always takes the value of [`bundle.path`](MasterDefaultsConfig.coffee#bundle.path).

      forceOverwriteSources: false

## build.template

A string in [Build.templates](https://github.com/anodynos/uRequire/blob/master/source/code/process/Build.coffee) = ['UMD', 'AMD', 'nodejs', 'combined']

@see *Conversion Templates* in docs.

      template: 'UMD'

## build.watch

Watch for changes in bundle files and reprocess/re output *only* those changed files.

The *watch feature* of uRequire works with:

* Standalone urequireCmd, setting `watch: true` or -w flag.

* Instead of `watch:true`, you use [grunt-urequire >=0.6.x](https://github.com/aearly/grunt-urequire) & [grunt-contrib-watch >=0.5.x](https://github.com/gruntjs/grunt-contrib-watch).

@note at each `watch` event there is a *partial build*. The first time a partial build is carried out, a full build is automatically performed. **You don't need (and shouldn't) perform a full build** before the watched task (i.e dont run the `urequire:xxx` grunt task before running `watch: xxx: tasks: ['urequire:xxx']`). A full build is always enforced by urequire.

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

@todo: make it less verbose - reassign levels

      debugLevel: 0

## build.continue

Dont bail out while processing when there are **module processing errors**.

For example ignore a coffeescript compile error, and just do all the other modules. Or on a `combined` conversion when a 'global' has no 'var' association anywhere, just hold on, ignore this global and continue.

@note: Not needed when `build.watch` is used - the `continue` behaviour is applied to `build.watch`.

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


## build.out

Callback to pass you the 'converted' content & `dstFilename`, instead of saving to fs under `dstPath/dstFilename` via [`FileResource.save()`](resourceconverters.coffee#fileresource-methods).

Mind you, its not working on the 'combined' template, cause r.js optimizer doesn't yet work *in-memory*.

@type `function (dstFilename, converted){}`

@optional

@default undefined - uses [`FileResource.save()`](resourceconverters.coffee#fileresource-methods) instead.

## build.done

This is set by either *urequireCMD* or [grunt-urequire](https://github.com/aearly/grunt-urequire) to signify the end of a build.

@todo: **NOT IMPLEMENTED** for user configs!

      done: (doneVal)-> console.log "done() is missing and I got a #{doneVal} on the default done()"

## build.clean

Clean all files & folders from `build.dstPath` before each non-watched, non-partial build.

@todo: NOT IMPLEMENTED

      clean: undefined

# Examples

Taken from the [Grunt config with comments](https://github.com/anodynos/uBerscore/blob/master/Gruntfile.coffee) of [uBerscore](github.com/anodynos/uBerscore), which also powers uRequire.

The `'urequire:uberscore'` task:

  * filters some `filez`
  * converts each module in `path` to UMD
  * everything saved at `dstPath`
  * copies all other files there
  * injects deps in each module
  * exports a global `window._B` with a `noConflict()`
  * injects a VERSION string inside the body of a file *
  * adds a banner (after UMD template conversion)

```coffeescript
uberscore:
  filez: ['**/*.*', '!draft/*.*']
  path: "#{sourceDir}"
  dstPath: "#{buildDir}"
  copy: [/./]
  dependencies: exports:
    bundle: ['lodash', 'agreement/isAgree']
    root: 'uberscore': '_B'

  resources: [
     # as comments cause literate coffeescript considers
     # indented lines as code, even in ` ` ` blocks

#    [ '~+inject:VERSION', ['uberscore.coffee'],
#      (m)-> m.beforeBody = "var VERSION='#{pkg.version}';"]
#
#    [ '!banner:uberscore', ['uberscore.js'],
#      (r)->"#{banner}\n#{r.converted}" ]
  ]
```

The `'urequire:min'` task :

  * derives all from the above `'uberscore'`, with the following differences
  * filters some more `filez`
  * converts to a single `uberscore-min.js` with `combined` template (r.js/almond)
  * uglifies the combined file with some `uglify2` settings
  * injects **different deps** in each module than its parent
  * manipulates each module:
   * removes some matched code 'skeletons'
   * replaces some deps in arrays, `require`s etc
   * removes some code and a dependency from a specific file.

```coffeescript
# min:
   derive: ['uberscore']
   filez: ['!blending/deepExtend.coffee']
   dstPath: './build/dist/uberscore-min.js'
   template: 'combined'
   main: 'uberscore'
   optimize: {uglify2: output: beautify: true}
   dependencies: exports: bundle: [
     [null], 'underscore', 'agreement/isAgree']
   resources: [
#       # as comments cause literate coffeescript considers
#       # indented lines as code, even in ` ` ` blocks
#     [
#       '+remove:debug/deb & deepExtend', [/./]
#
#       (m)->
#         for code in ['if (l.deb()){}', 'if (this.l.deb()){}',
#                      'l.debug()', 'this.l.debug()']
#           m.replaceCode code
#
#         m.replaceDep 'lodash', 'underscore'
#
#         if m.dstFilename is 'uberscore.js'
#           m.replaceCode {
#             type: 'Property'
#             key: {type: 'Identifier', name: 'deepExtend'}
#           }
#
#           m.replaceDep 'blending/deepExtend'
#    ]
   ]
###
```

Finally we easily configure our `grunt-contrib-watch` tasks

```
watch:
  UMD:
    files: ["#{sourceDir}/**/*.*", "#{sourceSpecDir}/**/*.*"]
    tasks: ['urequire:UMD' , 'urequire:spec', 'mocha', 'run']

  min:
    files: ["#{sourceDir}/**/*.*", "#{sourceSpecDir}/**/*.*"]
    tasks: ['urequire:min', 'urequire:specCombined',
            'concat:specCombinedFakeModuleMin', 'mochaDev', 'run']

  options: spawn: false
```
