**Resource Converters** is a powerful, generic and evolving **in-memory conversions workflow**, that is trivial to use and extend to cater for all common conversions (eg coffeescript, Livescript, coffeecup, less, jade etc).

## Literate Coffescript

This file is written in [Literate Coffeescript](http://ashkenas.com/literate-coffeescript): it serves both as *markdown documentation* AND the *actual code*, just like [MasterDefaultsConfig](MasterDefaultsConfig.coffee#Literate-Coffeescript).

NOTE: This file primary location is https://github.com/anodynos/uRequire/blob/master/source/code/config/ResourceConverters.coffee.md & copied over to the urequire.wiki - DONT edit it separatelly in the wiki.

## What are Resource Converters ?

**Resource Converters (RC)** is a *conversions workflow* system that is comprised of simplistic, yet powerful declarations of compilers/converters/transpilers etc. Each RC performs a conversion from one resource format (eg *coffeescript*, *less*) to another **converted** format (eg *javascript*, *css*) for the files it matches in the [bundle](MasterDefaultsConfig.coffee#bundle).

The workflow has the following principles :

  * **simple callback API** that enables any kind of conversion, even with *one-liners*. This is an actual RC :
    `[ '$coco', [ '**/*.co'], (->(require 'coco').compile @source, bare:true), '.js']`

  * focus to an **in-memory conversions pipeline**, to save time loading & saving from the filesystem.

  * powerful **only-when-needed** workflow, where each file is processed/converted *only when it really needs to*.

  * *seamlessly integrated* with `bundle` & `build` paths, unobtrusively loading & saving with the leanest possible configuration. It also works smoothly with `build.watch` and the whole uRequire building process.

## How do they work ?

All [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) are matched against the Resource Converters in [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) of your config. Each RC that matches a file, marks it as a **resource** that needs conversion with it. *Not matched at all files are still useful for declarative binary copy*.

## Defining in `bundle.resources`

A *Resource Converter* (RC) can be user-defined inside [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) either as:

* an Object {}, [as described bellow](#Inside-a-Resource-Converter).

* an Array [], (a shortcut spec) omitting property names that are inferred by position - see [alternative array way](#the-alternative-less-verbose-array-way-using-an-instead-of-.) and [The shortest one-liner-converter](#the-shortest-way-ever-a-one-liner-converter).

* by searching/retrieving an already registered RC, either by :

  a) a String 'name', used to retrieve an RC.

  b) by a function, whose context (`this`) is a search-by-name function that returns the proper RC instance. It can then be changed, cloned etc and return the RC used in [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources)
  
Example :
```
bundle: resources : [

  {name:"RCname1", descr:"RCname1 description"....}

  ["RCname2", "RCname2 description", ....]
  
  "RCname3"

  function(){ rc = this("RCname4").clone(); rc.filez.push '!**/DRAFT*.*'; return rc} 
]

```

Also see [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) and the real [Default Resource Converters](#Default-Resource-Converters).

## Inside a Resource Converter

Ultimately, a **Resource Converter** has these fields:

 * `name` : a simple name eg. `'coffee-script'`. A `name` can have various flags at the start of its initial name - see below - that are applied & stripped each time name is set. A `name` should be unique to each RC; otherwise it updates the registered RC by that name (registry is simply used to lookup RCs).

 * `descr` : any optional details to keep the name tidy.

 * `filez` : the same format as [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) spec ([] of minimatch & RegExp). It matches the files this RC deals with (always within the boundaries of `bundle.filez` files).

 * `convert()` :  the actual conversion callback `function(resource){return 'convertedText'}` that converts some resource's data (eg `source`, `converted` etc) and returns it. The only argument passed is a `resource` (the representation of a file under processing); for convenience the context (value of `this`) is also set to the resource.
  
 The return value of `convert()` is stored as `resource.converted` and its possibly converted again by a subsequent converter (that has also matched the file), leading to an in memory *conversion pipeline*. 
 
 Finally, after all conversions are done (for current build), if `resource.converted` is a non-empty String, its saved automatically at `resource.dstFilepath` (which uses [`build.dstPath`](MasterDefaultsConfig.coffee#build.dstPath)) & `convFilename` below.

 * `convFilename` :

  * a `function(dstFilename, srcFilename){return "someConvertedDstFilename.someext")}` that converts the current `dstFilename` (or the `srcFilename`) to its new *destination* `dstFilename`, eg `"file.coffee"` to `"file.js"`.

  * a `String` which can be either a) starting with "." (eg ".js"), where its considered an extension replacement. By default it replaces the extension of `dstFilename`, but with the "~" flag it performs the extension replacement on `srcFilename` (eg `"~.coffee.md"`). b) a plain String, returned as is (*note: duplicate dstFilename currently cause a build error*).

 * [`type`](#resource-types:-the-type-field) & flags [`isTerminal`](#isTerminal), [`isAfterTemplate`](#isAfterTemplate) & [`isMatchSrcFilename`](#isMatchSrcFilename) that can be easily defined via `name` flags - explained right below.

### Resource types: the `type` field

The `type` is user set among ['bundle', 'file', 'text', 'module'] -the default is undefined- or it can be set by a *name flag* for simplicity:

|[ name flag (striped on set)]|[ type (user set) ]| [ clazz (system set) ]|
| :---:|  :---:   | :---:          |
| '&'  | 'bundle' | BundleFile    |
| '@'  | 'file'   | FileResource  |
| '#'  | 'text'   | TextResource  |
| '$'  | 'module  | Module        |

#### Attaching some clazz

Each Resource Converter in [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) is *attached* to each matching resource (i.e file in [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) ) and its `type` (`clazz` internally) *marks* the resource's instance (to be created) either as `BundleFile`, `FileResource`, `TextResource` or `Module`.

**IMPORTANT**: Resource Converters order inside [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) does matter, since **only the last matching RC (with a `type`) determines the actual class** of the created resource.

At each build/conversion cycle, each `resource` is passed to the `convert(resource)` of its matched RCs, in the order defined in `resources`.

The RC's `convert(resource)` call converts the `source` or `converted` of the resource and returns the result, or performs any other conversion on the file (eg spawing external tools, load as a module and use, copy it etc). The result is stored at `resource.converted`, available to the next RC in line.

### Resource classes

Each file in [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) can be instantiated as a :  
_____
#### BundleFile

All [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) that are NOT matched by any RC (with a `type`), or those marked as `type:'bundle'` (or name-flagged with `'&'`) are instantiated as a `BundleFile`. 

BundleFiles instances are NOT converted at all - they are never passed to `convert()`. Also their contents are unknown. They can just be easily binary copied if they match [`bundle.copy`](MasterDefaultsConfig.coffee#bundle.copy).

##### Watching BF changes 

When watching, a BundleFile instance is considered as changed, only when fs.stats `size` & `mtime` have changed since last build.

##### Properties 

BundleFile class serves as a base for all resource types (its the parent class of all others). Each BF instance (and consequently each resource instance passed to `convert()`) has the following properties :

###### Filename properties

* `srcFilename` : the source filename, within the bundle, Eg `'models/initialValues.json'` or `'models/Person.coffee'`

* `srcFilepath` : calculated to include [`bundle.path`](MasterDefaultsConfig.coffee#bundle.path), eg `'source/code/models/initialValues.json'`

* `srcRealpath` : the full OS path, eg `'mnt/myproject/source/code/models/initialValues.json` - useful for `require`ing modules without worrying about relative paths.

* `dstFilename` : as it is returned by the last executed `convFilename`. Its initial value is `srcFilename`. Eg `'models/initialValues.json'` or `'models/Person.js'`.

* `dstFilepath` : calculated to include [`build.dstPath`](MasterDefaultsConfig.coffee#build.dstPath), eg `'build/code/models/Person.js'`

* `dstRealpath` : the full OS destination path, eg `'mnt/myproject/build/code/models/Person.js`

@note `dstXXX` : **When two ore more files end up with the same `dstFilename`**, build halts. @todo: This should change in the future: when the same `dstFilename` is encountered in two or more resources/modules, it could mean Pre- or Post- conversion concatenation. Pre- means all sources are concatenated & then passed once to `convert`, or Post- where each resource is `convert`ed alone & but their outputs are concatenated onto that same `dstFilename`.

###### Info properties

* `fileStats` : auxiliary, it stores ['mtime', 'size'] from nodejs's `fs.statSync`, 
needed internally to decide whether the file has changed at all (mainly for watch events).

* `sourceMapInfo` : calculates sourceMap info (reserved for the future) - eg with 

  `{srcFilepath: 'source/code/glink.coffee', dstFilepath: 'build/code/glink.js'}`

  sourceMapInfo will be:

  ```
  { file:"file.js", sourceRoot:"../../source/code", sources:["file.coffee"],
  sourceMappingURL="
      /*
      //@ sourceMappingURL=file.js.map
      */"
  }
  ```

###### Utility functions

* `copy()` : each instance is equiped with a `copy(srcfile, dstfile)` function, that binary copies a file (synchronously). It can be used without one or both arguments, where the 1st defaults to `@srcFilename` and 2nd to `build.dstPath/@srcFilename`. With this you can have a converter that simply copies a file, eg:
`['@copyVendorJs', ['vendorJs/**/*.js'], -> @copy()]`

* `requireUncached` : a special utility nodejs `require`, that makes sure the cached module (and its dependencies) is cleared before loading it. Useful if you want to load file resources (that change on disk) as nodejs modules (that are cached and don't care about disk changes). Its really a static method of BundleFile, added to instance for convenience.

There are also some other methods that are used *internally only*, like `refresh()` & `reset()` - don't use them!

_____
#### FileResource extends BundleFile

Represents an external file, whose `source` contents we know nothing of: we dont read it upon refresh() or base our 'hasChanged' decision on its source.

The `convert()` is called for each matched instance passing a `FileResource` (or a subclass) instance. `FileResource` instances/converters are useful when we want to `fs.read` their contents our selves or load 'em as modules, copy 'em, spawn external programs etc, but their `source` contents are not really useful or we simply want to save time from double-reading. As an example consider 'teacup' in [Extra Resource Converters](#Extra-Resource-Converters).

If `convert()` returns a String, it is stored as @converted on the instance and it is saved at `@dstFilename` at each build cycle.

**Paradoxically**, FR has a `read: (filepath=@srcFilepath)->` function that reads and returns the `utf-8` contents of the file; you can use on demand from within `convert()`.

**Watching FR changes** : (When watching suggests the underlying file has changed) a `FileResource` instance is considered as changed, only when `fs.stats`'s `size` & `mtime` have changed, just like BundleFile. Otherwise RCs `convert()` is not called at all.

_____
#### TextResource extends FileResource

A subclass of FileResource, it represents any *textual/utf-8* **Resource**, (eg a `.less` file). The only difference is that it calls `read` each time it refreshes and stores the result as `@source` (and initial value of `@converted`) and then it takes @source into account for watching.

**Watching TR changes** : a `TextResource` instance is considered as changed, if parent says so (`fs.stats`'s `size` & `mtime`), but also if the source (eg the .coffee contents) has changed. This is to prevent processing/converting files that the editor has saved/changed, but no real changes occurred.

_____
#### Module extends TextResource 

A **Module** is **javascript code** with node/commonjs `require()` or AMD style `define()`/`require()` dependencies.

Each Module instance is converted just like a **TextResource**, but its dependencies come into play and it adjusts its *module info* at each refresh. Ultimately it is converted through the chosen [`build.template`](MasterDefaultsConfig.coffee#build.template).

**Watching Module changes** : a `Module` instance is considered as changed (hence its module info adjusting), if parent says so (`fs.stats` & @source), but also if the *Javascript source* has changed. This is i.e to prevent processing a module whose coffeescript source changed eg whitespaces, but its javascript compiled code remained the same.


### Flags & Name Flags 
___
#### isTerminal - "|"

A converter can be `isTerminal:false` (the default) or `isTerminal:true`.

uRequire uses each matching converter in turn during each build, converting from one format to the next, using the @converted and @dstFilename as the input to the next converter. All that until the first `isTerminal:true` converter is encountered, where the conversion process for this resource instance stops.

You can denote an RC as `isTerminal:true` in the {} format or with name flag `'|'`.
___
#### isAfterTemplate - "!"

A converter with `isAfterTemplate:true` (refers only to "Module" instances) will run after the module is converted through its template (eg 'UMD'). By default `isAfterTemplate:false`. Use the `'!'` name flag to denote `isAfterTemplate:true`.
___
#### isMatchSrcFilename - "~"

By default (`isMatchSrcFilename:false`) filename matching of `filez` uses the instance `dstFilename`, which is set by the last `convFilename()` that run on the instance (initially its set to srcFilename). Use "~" name flag or (`isMatchSrcFilename:true`) if you want to match `filez` against the original source filename (eg. `'**/myfile.coffee'` instead of `'**/myfile.js'`). The sane default allows the creation of RCs that are agnostic of how the source files came about, whether they are actual matched files on disk or part of the in-memory conversion pipeline.
___
#### Flag updating notes

Note: when you change `name`, `type` and `convFilename` of an RC, the properties are correctly updated (flags are set etc). The name searching can also carry flags, which are applied on the found RC, for example `"#coco"` will find 'coco' RC and apply the `'#'` flag to it (`type:"TextResource"), before stripping it.
___

# Default Resource Converters

The following code [(that is actually part of uRequire's code)](#Literate-Coffescript), defines the **Default Resource Converters** `'javascript', 'coffee-script', 'LiveScript' & 'coco'` all as `type:'module' (via '$' flag). They are the default [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources):

    defaultResourceConverters = [

### The formal **Object way** to define a Resource Converter

This is a dummy .js RC, following the [formal RC definition](#Inside-a-Resource-Converter):

        {
          name: '$javascript'             # '$' flag denotes `type: 'module'`.

          descr: "Dummy js converter, does nothing much but marking `.js` files as `Module`s."

          filez: [                        # type is like `bundle.filez`, defines matching files, matched, marked and converted with this converter
            '**/*.js'                     # minimatch string (ala grunt's 'file' expand or node-glob), with exclusions as '!**/*temp.*'
                                          # RegExps work as well - use [..., `'!', /myRegExp/`, ...] to denote exclusion
            /.*\.(javascript)$/
          ]

          convert: -> @source             # javascript needs no compilation - just return source as is

          convFilename: (srcFilename)->   # convert .js | .javascript to .js
            (require '../paths/upath').changeExt srcFilename, 'js'

          type: 'module'                  # not really needed, since we have '$' flag to denote `type: 'module'`

          # these are defaults, you can ommit them
          isAfterTemplate: false
          isTerminal: false
          isMatchSrcFilename: false
        }

### The alternative (less verbose) **Array way**

This RC is using an [] instead of {}. Key names of RC are assumed from their posision in the array:

        [
          '$coffee-script'                                                  # `name` & flags as a String at pos 0

                                                                            # `descr` at pos 1
          "Coffeescript compiler, using the locally installed 'coffee-script' npm package. Uses `bare:true`."

          [ '**/*.coffee', /.*\.(coffee\.md|litcoffee)$/i]                  # `filez` [] at pos 2

          do ->                                                             # `convert` Function at pos 3
            coffee = require 'coffee-script'                                # 'store' `coffee` in closure
            -> coffee.compile @source, bare:true                            # return the convert fn

          (srcFn)->                                                         # `convFilename` Function at pos 4
            ext = srcFn.replace /.*\.(coffee\.md|litcoffee|coffee)$/, "$1"  # retrieve matched extension, eg 'coffee.md'
            srcFn.replace (new RegExp ext+'$'), 'js'                        # replace it and return new filename
        ]

### The alternative, even shorter `[]` way

        [
          '$LiveScript'                                                     # `name` at pos 0
          [ '**/*.ls']                                                      # if pos 1 is Array, then there's *undefined `descr`*
          ->(require 'LiveScript').compile @source, bare:true               # `convert` functions at pos 2
          '.js'                                                             # if `convFilename` is String starting with '.',
        ]                                                                   # it denotes an extension replacement of @dstFilename
                                                                            # if `~` flag is used, eg `~.js`, ext replacement is applied on @srcFilename

### The shortest way ever, a one-liner converter!

        [ '$coco', [ '**/*.co'], (-> require('coco').compile @source, bare:true), '.js']

    ]

How do we get such flexibility with both [] & {} formats? Check [ResourceConverter.coffee](https://github.com/anodynos/uRequire/blob/master/source/code/config/ResourceConverter.coffee)

### Extra Resource Converters

We register some **Extra Resource Converters** on registry with `name` as key.

The registry is populated with all Default and user-defined RCs.

The registry allows to easily **look up, clone, change, reuse or even call functions** of registered RCs.

To save loading & processing time, these RC-specs aren't instantiated as proper RC instances and not added to [bundle.resources](MasterDefaultsConfig.coffee#bundle.resources) until they are retrieved/used in a user's config `bundle.resources`. 

    extraResourceConverters =

      teacup: [
         '@~teacup'
         'Renders teacup nodejs modules (that export the plain template function), to HTML. FileResource means its source is not read/refreshed.'
         ['**/*.teacup']
         do ->
            require.extensions['.teacup'] = require.extensions['.coffee']     # register extension once
            -> @requireUncached(@srcRealpath)()                               # return our `convert()` function

         '.html'
      ]

# Finito 

Just export default and extra RCs and go grab a cup of coffee!

    module.exports = {
      defaultResourceConverters       # used as is by `bundle.resources`
      extraResourceConverters         # registered on `ResourceConverter` registry, instantiated on demand.
    }
