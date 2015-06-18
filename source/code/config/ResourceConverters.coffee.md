**Resource Converters** provide a powerful, generic and extendible **in-memory conversions workflow** / **assets pipeline**, that is expressive and flexible to cater for all common conversions needs (eg coffeescript, Livescript, coffeecup, less, jade etc).

*note: This file is written in [Literate Coffeescript](http://ashkenas.com/literate-coffeescript): it serves both as *markdown documentation* AND the *actual code*, just like [MasterDefaultsConfig](MasterDefaultsConfig.coffee#Literate-Coffeescript). This file primary location is https://github.com/anodynos/uRequire/blob/master/source/code/config/ResourceConverters.coffee.md & copied over to the urequire.wiki - DONT edit it separatelly in the wiki.*

## What is a ResourceConverter ?

A **ResourceConverter (RC)** is the *buidling block* of uRequire's *conversions workflow* system. An RC is a simplistic declaration and callback wrapping of a compiler/transpiler or any other converter/conversion.

Each RC instance performs a conversion from one resource format (eg *coffeescript*, *teacup*) to another **converted** format (eg *javascript*, *html*), for all [bundle.filez](MasterDefaultsConfig.coffee#bundle.filez) that also match its own [`ResourceConverter.filez`](#Inside-a-Resource-Converter).

RCs work in a serial chain: one RC's [`converted`](#converted) result, is the next RCs [`source`](#source).

## **ResourceConverter workflow** principles 

### **Simple authoring**...

...as a callback API that enables any kind of conversion, even with *one-liners*. This is an actual ResourceConverter :
   
   `[ '$coco', [ '**/*.co'], function(r){return require('coco').compile(r.convert)}, '.js']`
   
  Authoring an RC is very simple and has a [formal spec](#Inside-a-Resource-Converter) and [space saving shortcuts](#the-alternative-even-shorter-way). 

### **Blazing fast**...

...with focus to an **in-memory conversions workflow**, with an **only-when-needed** asset processing pipeline, where each file is processed/converted/saved/copied *only when it really needs to* (very useful when used with [build.watch](MasterDefaultsConfig.coffee#build.watch) or grunt's watch).

### **DRY (Dont Repeat Yourself)**...

...via the *seamlessly integrated* [uRequire's configuration](MasterDefaultsConfig.coffee) settings shared among all your conversion pipelines such as [bundle.filez](MasterDefaultsConfig.coffee#bundle.filez), [bundle.path](MasterDefaultsConfig.coffee#bundle.path), [build.dstPath](MasterDefaultsConfig.coffee#build.dstPath) etc, unobtrusively loading & saving with the leanest possible configuration. Check [an example](MasterDefaultsConfig.coffee#examples).

### **Dependencies Matter**... 
...uRequire provides the first **module & dependencies aware build system**, with advanced [module manipulation features](#Manipulating-Modules) such as injecting or replacing dependencies, matching and replacing/removing AST/String code fragments and more coming.

### **Transparent Power**...
...RCs empower any conversion (and most common ones that would otherwise require their own 'plugin'). In uRequire, many common tasks like **compilation** (currently Coffeescript, Livescript, coco, IcedCoffeeScript), **concatenation and banners** (i.e concat) or even **injections** of text/code fragments, minification (such as uglify), **copying** of resources, or *passing* them through arbitrary callbacks are all integrated [in one neat DRY configuration](MasterDefaultsConfig.coffee#examples).

## How do Resource Coverters work ?

Each file in [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) is matched against each ResourceConverter [`filez`](#Inside-a-Resource-Converter) in the order defined in your [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) of your config. Each RC that matches a file, marks it as a `resource` that needs conversion with it, in the order defined in [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources). *Files that are not matched by any RC are still useful for declarative binary copy*.

When a file (`resource`) changes, it goes through each matched ResourceConverter instance (`rc`) - always in the order defined in [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) - effectively `rc.convert()`-ing  `resource.source` to `resource.converted` at each subsequent step. 

The result of each `rc.convert()` (i.e `resource.converted`) is the input to the next matched RC's `rc.convert()`. The whole process is usually **in memory only**, with only the 1st [`read()`](resourceconverters.coffee#fileresource-methods) and last [`save()`](resourceconverters.coffee#fileresource-methods) being on the file system.

## Defining in `bundle.resources`

A *Resource Converter* (RC) instance is user-defined inside the [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) Array either as:

* an Object {}, [as described bellow](#Inside-a-Resource-Converter).

* an Array [], (a shortcut spec) omitting property names that are inferred by position - see [alternative array way](#the-alternative-even-shorter-way) and [The shortest one-liner-converter](#the-shortest-way-ever-a-one-liner-converter).

* by searching/retrieving an already registered RC, either by :

  a) a String 'name', used to retrieve an RC.

  b) by a function, whose context (`this`) is a search-by-name function that returns the proper RC instance. It can then be changed, cloned etc and return the RC to be added to [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources).
  
Example :
```
bundle: resources : [

  {name:"RCname1", descr:"RCname1 description"....}

  ["RCname2", "RCname2 description", ....]
  
  "RCname3"

  function(){
    rc = this("RCname4").clone();
    rc.filez.push '!**/DRAFT*.*';
    return rc;
  }
]

```

Also see [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) and the real [Default Resource Converters](#Default-Resource-Converters).

## Inside a Resource Converter

Ultimately, a **ResourceConverter** instance has these fields:

### `name`

A simple name eg. `'coffee-script'`, but can also have various flags at the start of its initial name - see below - that are applied & stripped each time name is set.

A `name` should be unique to each RC; otherwise it updates the registered RC by that name (registry is simply used to lookup named RCs).

### `descr`

Any optional details (i.e String) to keep the name tidy - it plays no other role.

### `filez`

A [filespecs](types-and-derive#filespecs) (i.e an `[]` of minimatch, RegExp or fns) that matches the files this ResourceConverter deals with, always within the boundaries of [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez).

### `convert()`

The actual conversion callback `function(resource){return 'convertedText'}` that converts some resource's data (eg `source`, `converted` etc) and returns it. The only argument passed is a `resource` (the representation of a file under processing, which might also be a Module).

   **NOTE: The context (value of `this`) is set to `this` ResourceConverter (uRequire >=0.6)**.
  
   The return value of `convert()` is stored as `resource.converted` and its possibly converted again by a subsequent converter (that has also matched the file), leading to an in memory *conversion pipeline*.
 
 Finally, after all conversions are done (for current build), **if `resource.converted` is a non-empty String**, its saved automatically at `resource.dstFilepath` (which uses [`build.dstPath`](MasterDefaultsConfig.coffee#build.dstPath)) & `convFilename` below.

### `convFilename`

How to convert th resource's filename. It can be :

* a `function (dstFilename, srcFilename) { return "someConvertedDstFilename.someext") }` that converts the current `dstFilename` (or the `srcFilename`) to its new *destination* `dstFilename`, eg `"file.coffee"` to `"file.js"`.

* a `String` which can be either:

  * starting with "." (eg ".js"), where its considered an extension replacement. By default it replaces the extension of `dstFilename`, but with the "~" flag it performs the extension replacement on `srcFilename` (eg `"~.coffee.md"`).

  * a plain String, returned as is (*note: duplicate `dstFilename` currently causes a build error*).

### `type`

The `type` is one of ['bundle', 'file', 'text', 'module'] and the **default is undefined**. For simplicity it can be set by a *name flag* :

|[ name flag]|[ type ]| [ clazz (used internally) ]|
| :---:|  :---:   | :---:         |
| '&'  | 'bundle' | BundleFile    |
| '@'  | 'file'   | FileResource  |
| '#'  | 'text'   | TextResource  |
| '$'  | 'module  | Module        |

Each RC in [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) is *attached* to each matching resource (i.e each file that passed through both [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) and [`filez`](#filez)) and its `type` (`clazz` internally) ** *marks* the resource's class (to be instantiated)** either as [`BundleFile`](#bundlefile), [`FileResource`](#fileresource-extends-bundlefile), [`TextResource`](#textresource-extends-fileresource) or [`Module`](#module-extends-textresource) - all [explained here](#Resource-classes).

**IMPORTANT**: Resource Converters order inside [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) does matter, since **only the last matching RC (with a `type`) determines (marks) the actual class** of the created resource.

___
##### Flags an Nameflags

The following RC instance fields can be set either by :

 * setting the key on the object notation, eg `isMatchSrcFilename: true`

 * conveniently, by prefixing [`name`](#name) with the **name flag** , eg `name: '~myMatchSrcFilename_RC_name'`. or `['~myMatchSrcFilename_RC_name', ..rest of rc.. ]`

When you change `name`, `type` and `convFilename` of an RC, the properties are correctly updated and flags are always set and then stripped.

The *name searching can also carry flags*, which are applied on the found RC, for example having `"#coco"` on [`bundle.resources`](masterdefaultsconfig.coffee#bundle.resources) will both find 'coco' RC and also apply the `'#'` flag to it (`type:"TextResource"`), before stripping it and leaving 'coco' as the name of the RC.

The name flag follows the key name, eg as in :

### `isMatchSrcFilename` - `"~"`

By default (`isMatchSrcFilename: false`) filename matching of `ResourceConverter.filez` uses the file's resource instacnce `dstFilename`, which is set by the last `convFilename()` that run on the instance (with initial value that of `srcFilename`).

Use the `'~'` name flag or (`isMatchSrcFilename:true`) if you want to match `filez` against the original source filename (eg. `'**/myfile.coffee'` instead of `'**/myfile.js'`).

#### Why ?

The sane default allows the creation of reusable RCs, that are agnostic of how the input resource came about.
RCs should be as gneric as possible. Whether its `filez` actual matchedes '.js' file on disk, or became a '.js' from a '.coffee' as part of an in-memory conversion pipeline.

___
### `isTerminal` - `"|"`

If an `isTerminal:true` converter is encountered while processing a file, the conversion process (for that current file/resource) terminates after this RC is done.

You can denote an RC as `isTerminal:true` in the {} format or with *name flag* `'|'`. THe default is ofcourse `isTerminal: false`.

___
### `isBeforeTemplate` - `"+"`

A converter with `isBeforeTemplate: true` is a special case:

It refers only to [Module](#Module-extends-textresource) instances and will run just BEFORE the module is converted through [`build.template`](MasterDefaultsConfig.coffee#build.template).

The `convert(module)` function of `isBeforeTemplate` RCs will always receive a Module instance ([Module is a subclass of BundleFile/Resource](#module-extends-textresource)), that has :

* parsed javascript in [Mozzila Parser AST](https://developer.mozilla.org/en/SpiderMonkey/Parser_API) format. 

* extracted/adjusted dependencies data, allowing an [advanced manipulation of module's dependencies](#inject-replace-dependencies)

* Methods & members to [manipulate the module instance, including code](#Manipulating-Modules) in amazing ways.

* Note: for `isBeforeTemplate` RCs only the **return value of `convert(module)` is ignored** - the template uses only AST code and its dependencies arrays to produce its `@converted` string at the next step (the template rendering).* You can affect the produced code (template rendering) only through [manipulating the Module](#Manipulating-Modules).
___
### `isAfterTemplate` - `"!"`

A converter with `isAfterTemplate:true` refers only to [Module](#module-extends-textresource instances and will run right AFTER the module is converted through [`build.template`](MasterDefaultsConfig.coffee#build.template).

By default `isAfterTemplate:false`. Use the `'!'` name flag to denote `isAfterTemplate: true`.

Following the norm, the return value of [`convert(module)`](#convert) is assigned to [`converted`](#converted) and (assuming its the last RC) it is the value to be saved as [`dstFilename`](#dstFilename) (assuming its a non-empty String).

This is the right place to add banners, custom code injections etc, *outside* of the UMD/AMD/nodejs template and its enclosures.

@see [build.template.banner](MasterDefaultsConfig.coffee#build.template.banner)

@note [Module Manipulation](#Manipulating-Modules) **will make no effect in `isAfterTemplate: true` RCs**, only the return of `convert()` matters like in all normal RCs!

### `isAfterOptimize` - `"%"`

Just like [`isAfterTemplate`](#isAfterTemplate), but runs after [`build.optimize`](MasterDefaultsConfig.coffee#build.optimize) is run (if any, or after `isAfterTemplate` otherwise).

# Resource classes

Each file that passes through [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) will be instantiated as one of 4 classes (each extending the previous one):

**BundleFile** <-- **FileResource** <-- **TextResource** <-- **Module**

_____
## BundleFile

Represents a generic file inside the bundle. It also stands as the **base class of all file/text resources/modules**.

All [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) that :

* are NOT matched by any RC at all

* are not matched by any RC that has some specific [`type`/`clazz`](#type),

* or last matched by an RC with an explicit `type: 'bundle'` (or name-flagged with `'&'`)

are instantiated as a `BundleFile`. BundleFile *instances* :

* are NOT converted at all - they are never passed to `convert()`. Consequently they have no [`converted`](#converted) content.

* their contents / ([`source`](#source)) are completely unknown / irrelevant. They might be binary files or non-urequire converted files.

* their sole puropse is they be easily (binary) copied if they match with a simple [`bundle.copy`](MasterDefaultsConfig.coffee#bundle.copy) filespec.

### Watching BundleFile changes

When watching, a BundleFile instance is considered as changed, only when fs.stats `size` or `mtime` have changed since the last refresh (i.e a partial/full build noting this file).

### BundleFile Properties

BundleFile class serves as a base for all resource types  - its the parent (and grand* parent) class of the others. Each BF instance (and consequently each resource/module instance passed to `convert()`) has the following properties :

#### Filename related

#### `srcFilename`

The source filename, within the bundle, Eg `'models/initialValues.json'` or `'models/Person.coffee'`

#### `srcFilepath`

Calculated to include [`bundle.path`](MasterDefaultsConfig.coffee#bundle.path), eg `'source/code/models/initialValues.json'`

#### `srcRealpath`

The full OS path, eg `'mnt/myproject/source/code/models/initialValues.json` - useful for `require`ing modules without worrying about relative paths.

#### `dstFilename`

The destination name of the BundleFile, as it is returned by the last executed [`convFilename`](#convFilename) on the file.

Its initial value is [`srcFilename`](#srcFilename). Eg `'models/initialValues.json'` or `'models/Person.js'`.

@note `dstXXX` : **When two ore more files end up with the same `dstFilename`**, build halts (unless [`srcMain`](#srcMain) is used). *@todo: This should change in the future: when the same `dstFilename` is encountered in two or more resources/modules, it could mean Pre- or Post- conversion concatenation. Pre- means all sources are concatenated & then passed once to `convert`, or Post- where each resource is `convert`ed alone & but their outputs are concatenated onto that same `dstFilename`*.

#### `dstFilepath`

Calculated to include [`build.dstPath`](MasterDefaultsConfig.coffee#build.dstPath), eg `'build/code/models/Person.js'`

#### `dstRealpath`

The full OS destination path, eg `'mnt/myproject/build/code/models/Person.js`

#### Various info properties

#### `fileStats`

Auxiliary, it stores ['mtime', 'size'] from nodejs's `fs.statSync`, needed internally to decide whether the file has changed at all (at watch events that note it).

#### `sourceMapInfo`

Calculates basic sourceMap info (reserved for the future) - eg with

  `{srcFilepath: 'source/code/glink.coffee', dstFilepath: 'build/code/glink.js'}`

  `sourceMapInfo` will become:

  ```
  sourceMapInfo: {
    file: "file.js",
    sourceRoot: "../../source/code"
    sources: ["file.coffee"]
    sourceMappingURL="
        /*
        //@ sourceMappingURL=file.js.map
        */"
  }
  ```

  Note: As of uRequire 0.6.8, generating SourceMaps while converting Modules with Template (UMD / AMD / nodejs / combined) [**is not implemented**](https://github.com/anodynos/uRequire/issues/24). Its only useful for compiling coffee to .js with an [RC like this](https://github.com/anodynos/uRequire/issues/24).

#### Utility methods

#### `copy()`

Each BundleFile (or subclasses) instance is equiped with a `copy(srcFilename, dstFilename)` function, that binary copies a file (synchronously) from its source (`bundle.path` + `srcFilename`) to its destination (`build.dstPath` + `dstFilename`).
 
It can be used without any or both arguments, where the 1st defaults to [`srcFilename`](#srcFilename) and 2nd to [`dstFilename`](dstFilename).

Both filenames passed as arguments are appended respectively to [`bundle.path`](MasterDefaultsConfig.coffee#bundle.path) & [`build.dstPath`](MasterDefaultsConfig.coffee#build.dstPath), so they are *always read and written* within your bundle's boundaries.

@note: to avoid the appending to `bundle.path` & `build.dstPath`, use the static `resource.constructor.copy()` that has no default arguments or appending.

##### No redundancies

`copy()` always makes sure that **no redundant copies are made**: when the destination file exists, it checks nodejs's `fs.stat` `'mtime'`, `'size'` and copies over only if either is changed, and skips if they are the same. It returns `true` if a copy was made, `false` if it was skipped.

@example

With `copy()` you can have a converter that simply copies each file in `RC.filez`, eg:

`['@copyVendorJs', ['vendorJs/**/*.js'], (r)-> r.copy()]`

or copies them renamed, from `bundle.path` to `build.dstPath` eg

`['@copyRenamedVendorJs', ['vendorJs/**/*.js'], (r)-> r.copy(undefined, 'renamed_' + e.dstFilename)]`


#### `requireClean()`

A utility `function(moduleName)` that is a wrapper to nodejs's `require(moduleName)`, that makes sure the cached module (and its dependencies) is cleared before loading it.

Its useful if you want to load a file (that changed on disk's [`bundle.path`](MasterDefaultsConfig.coffee#build.dstPath)) as a nodejs module. The problem with plain `require` is that nodejs modules are cached and don't reload when file on disk changes.

The instance method is a wrapper to the `BundleFile.requireClean()` static method, added as instance method for convenience **with `resource.srcRealpath` as the default value** of the `name` argument.

Example: see `'teacup'` at [Extra Resource Converters](#Extra-Resource-Converters)

#### Can't touch these

There are also some other BundleFIle methods that are used *internally only*, like `refresh()` & `reset()` - you shouldn't use them!

_____
### FileResource extends BundleFile

ResourceConverters that mark files as `FileResource` have a name flag '@'  or `type: 'file'`

A `FileResource` represents an external file, whose `source` contents we know nothing of: we dont read it upon refresh() or base our 'hasChanged' decision on its source.

`FileResource` instances are useful when their corresponding file `source` contents are not useful (eg binary files), or we simply want to save time from double-reading them. For instance we might want to :

 * read their contents our selves
 
 * require them as modules (perhaps with [`requireClean()`](#requireClean)) and execute their code to get some result.
 
 * spawn external programs to convert them, copy 'em, etc

In all cases the call is synchronous.

Example: consider 'teacup' in [Extra Resource Converters](#Extra-Resource-Converters): each time the underlying FileResource changes, it loads it as a nodejs module (which returns a teacup function/template) and them renders it to HTML via the 'teacup' module.

If `convert()` returns a String, it is stored as `converted` on the instance and it is saved at `dstFilename` at each build cycle.

#### Watching FileResource changes

When watching suggests the underlying file has changed, a `FileResource` instance is considered as changed, only when `fs.stats`'s `size` & `mtime` have changed, functionality inherited by `BundleFile`. The contents are NOT checked on each refresh(). 

#### FileResource Methods

Paradoxically, a *FileResource* instance has instance methods to `read()` and `save()` (all synchronous):

#### `read()`

A `function(filename, options)` that reads and returns contents of the source file. It takes two **optional arguments**:

 * `filename`, which is appended to `bundle.path`. It defaults to `resource.srcFilename`.
 @note: Use the static `resource.constructor.read()` method to skip `bundle.path` appended to `filename`

 * `options` hash, passed as is to [`fs.readFileSync`](http://nodejs.org/api/fs.html#fs_fs_readfilesync_filename_options), with `utf8` as the default `encoding`.

 You can use `read()` on demand from within `convert()`, for example:  
 ```
 convert: function(fileResource){ return 'someContent' + fileResource.read() }
 ```

#### `save()`

A `function(filename, content, options)` that saves the contents to the destination file. It takes **three optional arguments**:

 * `filename`, appended to `build.dstPath` and defaults to `resource.dstFilename`
 @note: Use the static `resource.constructor.save()` that has no `dstPath` appending and default values (only 'utf8' is default)

 * `content`, the (String) contents to be saved, defaults to `resource.converted`

 * `options` hash which is passed to [`fs.writeFileSync`](http://nodejs.org/api/fs.html#fs_fs_writefilesync_filename_data_options) with 'utf8' as default encoding.

#### `srcMain`

If a ResourceConverter has an `srcMain`, then its *only* the `srcMain` that really needs processing (eg `main.less`).
The `srcMain` is copied to each `FileResource` matched and its role can be seen as to group all matching `ResourceConverter.filez` together and be converted as one main destination file, whenever each source file in the gorup changes. Resources with an `srcMain` can have the same `dstFilename` and are best to be kept as FileResource (and not for instance TextResource that reads the text content), since all `import 'otherstyle.less'` happens outside the control of uRequire and it would be pointless.

Since uRequire 0.7.0 ResourceConverter authors don't need to add any special `srcMain` sauce, it works out of the box.

_____
### TextResource extends FileResource

A subclass of [FileResource](#FileResource-extends-BundleFile), it represents any *textual/utf-8* **Resource**, (eg a `.coffee` file).

The only difference to its parent is that it calls `read()` each time it refreshes and stores it as `resource.source` (and the initial value of `resource.converted`) and then it takes `resource.source` into account for watching.

#### Watching TextResource changes

A `TextResource` instance is considered as changed, [if parents say so (`fs.stats`'s `size` & `mtime`)](#watching-fileresource-changes) and if they do, it checks if [`read()]`-ing(#read) the [`source`](#source) has changed.

This is to **prevent a lengthy processing/converting of files** that the editor has saved/changed/touched, but no real content change has occurred.

#### TextResource Properties

Along with from those inherited from [FileResource](#FileResource-extends-BundleFile)/ [BundleFile](#BundleFile), each TextResource has

####  `converted`

This represents the current converted contents of the file, as it was after the last [`ResourceConverter.convert`](#convert).

At each refresh, **`converted` is initialized to `source`**, so your first [`ResourceConverter.convert`](#convert) in chain will receive a `converted` that equals `source`.

Its best to use `converted` (instead of `source`) to read the contents of the last conversion, so that RCs are reusable and chainable.

####  `source`

This always represents the original contents of the file, as it was last read (automatically) when the file (changed &) refreshed. Keep in mind that:

* You **never need to set** this your self on a TextResource - its automatically set when needed.

* Paradoxically you should **rarely need to read** `source` within your [`convert()`](#convert), when you define a ResourceConverter.
Because RCs work best in chain, your RCs should read `converted` instead, which is the result of the previous ResourceConvert `convert`, and take it from there on.

That of course is unless you really want the orginal contents of the file, eg you might want to discard their `converted` so far and start afresh.

Note that even if you know there are no previous RCs run agaisnt your file (eg you are creating a new *HotCofreeScript* RC), you can still read `converted` instead of `source`, since `converted` is initialized to `source` each time a TextResource refreshes.

_____
### Module extends TextResource 

A **Module** is **javascript code**, usually with node/commonjs `require() / module.exports` or AMD style `define()` dependencies.

Each Module instance is refreshed/converted just like a [TextResource](#TextResource-extends-FileResource), but its javascript source and dependencies come into play:

* Its javascript source is parsed to [Mozilla Parser AST] (https://developer.mozilla.org/en/SpiderMonkey/Parser_API) via the excellent [esprima parser](http://esprima.org/).

* Its **module/dependencies info is extracted & adjusted** at each refresh ([when real javascript source changed](#Watching-Module-changes)). Ultimately its dependencies are analysed & adjusted and its factory body extracted as AST nodes

and finally

* The Module gets its `@converted` string through the chosen [`build.template`](MasterDefaultsConfig.coffee#build.template). It essentially regenerates the AST factoryBody surrounded by the template's data, dependency injections etc.

#### Watching Module changes

A `Module` instance is considered as changed (hence its module info adjusting), if [parent says so(`fs.stats` & @source)](#watching-textresource-changes), but also if the resulting *Javascript source* has changed. This is for example to prevent processing a module whose coffeescript/livescript/coco etc source has changed, but its javascript compiled code remained the same (eg you changed coffeescript's whitespaces).

## Manipulating Modules

The special [`isBeforeTemplate` flag of ResourceConverters](#isbeforetemplate) allows advanced manipulation of Modules: when this flag is true on an RC, **the ResourceConverter runs (only) just before the template is applied**, but after having AST parsed the javascript code and extracted/adjusted the module's dependencies.

Hence, the `convert()` RC method is passed a Module instance with **fully extracted & adjusted dependencies, with a parsed AST tree and with facilities to manipulate it at a very high level**, far more flexible than simple textual manipulation/conversion.

*Note: for [`isBeforeTemplate` RCs](#isbeforetemplate), the **return value of `convert()` is ignored** - the template uses only AST, dependencies & templates to produce its [`converted`](#converted) at the next step (template rendering). Use the [Module Members](#Module-Members) to affect the resulted `converted`.*

### Module Members 

The following member properties/methods manipulate a Module instance:

#### Inject any string before & after body

#### `beforeBody`

Any String that is concatenated just before the original 'body' on the template rendering, for example:

```
[ '+inject:VERSION', ['uberscore.js'], 
  function(modyle){modyle.beforeBody = "var VERSION='" + version + "';"}]
```            
Module 'uberscore.js' will *always* get this string injected before its main body, **inside the module**, in all templates.

#### `afterBody`

A String concatenated after the original body, just like `beforeBody`.

#### `mergedCode`

This is code (as String) that is considered common amongst *most* modules. Examples are initializations, exporting/importing variables etc.

It is added just before [beforeBody](#beforeBody) for all templates **except ['combined' template](combined-template)**.

Instead in ['combined' template](combined-template), the `mergedCode` code from all modules **is merged into one section** and its added to the closure only once. Thus its declarations are available to all modules, but it saves space & speed.

##### When to use `mergedCode`

It stands between [`beforeBody`](#beforeBody) and [`bundle.commonCode`](MasterDefaultsConfig.coffee#bundle.commonCode). The rationale for using it instead, is:

 * having common code to most/many modules

 * but wanting to exclude one or more Modules from having it.

Thus using

 * [`beforeBody`](#beforeBody) would waste space, since the same code would always be repeated in all modules, even on ['combined' template](combined-template).

 * [`bundle.commonCode`](MasterDefaultsConfig.coffee#bundle.commonCode) would have it included in *all* modules in non-combined templates, even those we don't want to.

@example: Consider this problem :

 * having a module `'stuff/myModule.js'` that exports an `{}` with an awful lot of properties `p1`, `p2`, ...`pN`.

 * You want to **import** all of these properties (i.e have them available as normal variables `p1`, `p2` etc) in **all other modules**.

What you can do is:

* define the importing code as `mergedCode` in all modules *but excluding the exporting one*, ie.
```
[ '+importMyModuleVars', ['**/*.js', '!stuff/myModule.js'],
  function(m){
    m.mergedCode = "var p1 = myModule.p1, p2 = myModule.p2, ..., pN = myModule.pN;"
  }
]
```
* make `stuff/myModule` available as an [`bundle.dependencies.imports`](MasterDefaultsConfig.coffee#bundle.dependencies.imports), with the `myModule` identifier.

```
 dependencies: exports: bundle: { 'stuff/myModule': 'myModule' }
```

That's it!

#### Manipulate/replace AST code

#### `replaceCode()`

A method `replaceCode(matchCode, replCode)` that replaces (or removes) a code statement/expression that matches a code 'skeleton'. It takes two arguments:

 * `matchCode` : (mandatory) the statement/expression to match in the AST body - it can be either: 

  * a **String**, which MUST BE a **single parseable Javascript statement/expression** (it gets converted to AST, getting the first only body[] node). For example:
 ```
 'if (l.deb()){}' // an if skeleton without else part
 ```

 will match all code like :

 ```
 if (l.deb(someParam, anotherParam)){
   statement1;
   statement2;
    ...
 } // no else or it wont match
 ```

  * or a more flexible **AST 'skeleton'** object (in [Mozzila Parser AST](https://developer.mozilla.org/en/SpiderMonkey/Parser_API)) like:

 ```coffee
 {
    type: 'IfStatement'
    test: 
        type: 'CallExpression'
        callee:
            type: 'MemberExpression'
            object: type: 'Identifier', name: 'l'
            property: type: 'Identifier', name: 'deb' 
 }
 ```
that matches an `if (l.deb())...` with or without an else part.

In both cases, the resulting AST 'skeleton' node will be compared against each traversed AST node in module's body, **matching only its existing object keys / array items and their values with the traversed node** - for example `{type: 'IfStatement'}` matches all nodes that have this key/value irrespective of all others.
  
 * `replCode`: (optional) the replacement code, taking the place of each node that matched `matchCode`. It can be either:

  * **undefined**, in which case each matched code node is removed from the AST tree (or replaced with an `EmptyStatement` if its not in a block).

  * A **String**, again of a single parsable javascript statement/expression.

  * a valid **AST fragment**, which should `escodegen.generate` to javascript

  * a **`function(matchingAstNode){return node}`** which again returns either undefined/null, a String with valid javascript or a generatable AST fragement.


@example

```
resources: [
  ...
  [
    '+remove:debug/deb', [/./]
    # perform the replacement / deletion
    # note: return value is ignored in '+' `isBeforeTemplate` RCs
    (modyle)-> modyle.replaceCode 'if (l.deb()){}'
  ]
  ...  
]
```

will remove all code that matches the `'if (l.deb()){}'` skeleton.

#### Inject / replace dependencies

#### `replaceDep()`

A method `replaceDep(oldDep, newDep, options)` that replaces dependencies in the resolved dependencies arrays and the body AST (i.e `require('../some/dep')` of this module. Its taking 3 arguments:

* `matchDep`: the dependency/ies to match and replace. It might be either :

 **String**: the dep either in [bundleRelative format](Flexible-Path-Conventions#bundlerelative-vs-filerelative-paths), eg `'models/Person'` where its calculated relative to bundle, or in fileRelative eg `'../models/Person'` where its calculated relative to this file/module by default (but can be overridden, see options).

 The String can also be either:

 * a partial match, denoted with `'|'` as the last char, eg `'data/models|'`, which triggers a partial replacement / translation, see [partial replacements](#Partial-replacements-translation) below.

 * a [mimimatch](https://npmjs.org/package/minimatch) String, eg `'**/model/Person*'`

 **RegExp**: a regexp that matches the dep (including the possible plugin and extension), that is caclulated according to options (fileRelative with both plugin and extension by default) @todo: examples

 **Function**: called with `depName`, `dep`, `options` @todo: explain better ?

* `newDep`: the dependency to replace with, which can be:

  **String**: of relative type in options eg `'mockModels/PersonMock'` or `'lodash'`

  **Dependency**: an internal class, not currently a documented part of the user API.

  **Function**: with arguments `depName` & `dep` of the dependency that matched, and returns either a String or a Dependency. @todo: document better ?

  **undefined/null**: If `newDep` is omitted (i.e undefined), the **dependency is removed** from the module's dependencies, along with its corresponding parameter (if any). *@note its not removed from the actual module's body, i.e if it exists as a `myDepVar = require('dep')`)*.

* `options` a hash with some of these props:
  **relative**: either `'bundle'` or `'file'`, defaults to `'file'` if matchDep as string starts with '.', `'bundle'` otherwise.
  **plugin**: boolean, whether to consider plugin
  **ext**: boolean, whether to consider extension

@example: `m.replaceDep('models/Person', 'mockModels/PersonMock')`

##### Partial replacements / translation

@todo: explain better

@example `mod.replaceDep('../lib|', '../UMD', {relative:'bundle'})` will replace the starting path of all (external) dependencies that start with `'../lib'` (when calculated relative to bundle), with `'../UMD'`.

 So if the module is `'somedir/myModule'` and has a fileRelative dep `'../../lib/someDir/someDep'` (i.e `'../lib/someDir/someDep'` if calculated relative to bundle taking the path of the module into account), the dep will be translated to ``'../../UMD/someDir/someDep'`.

#### `injectDeps()`

A method `injectDeps(depVars)` that injects one or more dependencies, along with one or more variables/identifiers to bind with on the module. Its taking only one argument of [depVars type](types-and-derive#depsVars).

For example:

```
  modyle.injectDeps({
    'lodash': '_',
    'models/Person': ['persons', 'personsModel']
  });
```

or

```
  modyle.injectDeps(['lodash', 'models/Person'])
```

that [infers binding idenifiers](masterdefaultsconfig.coffee#inferred-binding-idenifiers).

The deps are are always given in [bundleRelative](Flexible-Path-Conventions#bundlerelative-vs-filerelative-paths) format. In general it makes sure that :

* not two same-named parameters are injected - the 'late arrivals' bindings are simply ignored (with a warning). So if a Module already has a parameter `'_'` and you try to inject `'lodash':'_'`, it wont be injected at all.

* Not injecting a self-dependency. If you are at module `'agreements/isAgree'`, trying to inject dependency `'agreements/isAgree'` will be ignored (without a warning, only a debug message).

@note: uRequire doesn't enforce that the injected dependency is valid, for example whether it exists in the bundle - but you 'll get an error report in the end.

@note `injectDeps()` is used internally to inject [`dependencies.imports`](MasterDefaultsConfig.coffee#bundle.dependencies.imports) (on templates that actually need this injection, i.e all except ['combined'](combined-template)).

@note If you 're injecting a dep in all modules, consider adding to [`dependencies.imports`](MasterDefaultsConfig.coffee#bundle.dependencies.imports), to save size/speed on ['combined' template](combined-template).

#### Other Properties

There is a number of properties that a Module holds, most of them are only useful internally - check `fileResources/Module.coffee` for more information - here's a small bunch of potentially useful members:

##### `path`

The full path of the module within the bundle, without an extension

@example `'data/models/PersonModel'`

##### `kind`

Either `'AMD'` or `'nodejs'`

##### `factoryBody`

For kind being :

 * 'nodejs' : The whole code of the module, extracted from any [IFI](http://stackoverflow.com/questions/939386/immediate-function-invocation-syntax)

 * 'AMD': The body of the factory function, eg for `define(function(){ alert('foo'); }` its `alert('foo');`

`AST_factoryBody` holds the actual nodes, and `factoryBody` is generated (calculated property) each time its read.

##### `preDefineIIFEBody`

The code preceding `define` when it is enclosed in an IFI - see [Merging pre-define IFI statements](combined-template#merging-pre-define-ifi-statements). `AST_preDefineIIFENodes` holds the actual AST nodes.

_____
# Default Resource Converters

The following code [(that is actually part of uRequire's code)](#note:-literate-coffescript), defines the **Default Resource Converters** `'javascript', 'coffee-script', 'livescript' & 'coco'` all as `type:'module'` (via '$' flag). They are the default [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources):

    defaultResourceConverters = [

### The formal **Object way** to define a Resource Converter

This is a dummy .js RC, following the [formal & boring ResourceConverter definition as an `{}`](#Inside-a-Resource-Converter):

        {
          # name - with a '$' flag to denote `type: 'module'`.
          name: '$javascript'

          descr: "Dummy js converter, justs marks `.js` files as `Module`s."

          # type is like `bundle.filez`, matches files RC deals with
          filez: [
            # minimatch string, with exclusions as '!**/*temp.*'
            '**/*.js'

            # RegExps as well, with[.., `'!', /myRegExp/`] for exclusions
            /.*\.(javascript)$/

            # a `function(filename){}` also valid, with '!' for exclusion
          ]

          # javascript needs no compilation - returns source as is
          # could have `undefined` in convert's place
          # we use m.converted (which defaults to m.source), cause
          # you never know what super duper RC conversion run before!
          convert: (modyle)-> modyle.converted

          # convert .js | .javascript to .js
          convFilename: (srcFilename)->
            require('upath').changeExt srcFilename, 'js'

          # not needed, we have '$' flag to denote `type: 'module'`
          type: 'module'
        }

### The alternative (less verbose) **Array way**

Thankfully there are better & quicker ways to define a ResourceConverter. The ["coffee-script"](https/github.com/anodynos/urequire-rc-coffee-script) RC is defined as an `[]` instead of `{}` and is much less verbose.
It is by default loaded as a separate `urequire-rc-coffee-script` node dependency, just referenced here.

        'coffee-script'

### The alternative, even shorter `[]` RC way for ["livescript"](https/github.com/anodynos/urequire-rc-livescript).

Again loaded as `urequire-rc-livescript` node dependency with this reference.

        'livescript'

### The shortest way ever, one-liner, no comments converters.

The following two are for ["iced-coffee-script"](https/github.com/anodynos/urequire-rc-iced-coffee-script) & ["coco"](https/github.com/anodynos/urequire-rc-coco).

        #'iced-coffee-script' # removed from loaded as default cause of a weird npm error - add it manually (`npm install urequire-rc-iced-coffee-script` and then in your `bundle: resources: [ 'iced-coffee-script', ....]` :-)  

This is what the 'coco' RC [actually looks like](https://github.com/anodynos/urequire-rc-coco/blob/master/source/code/urequire-rc-coco.coffee):

`['$coco', [ '**/*.co'], ((r)-> require('coco').compile r.converted, @options), '.js']`.

As an example, if you wanted to pass some coco `options` (that `_.extend` default options), use this format instead of a plain `'coco'` String:

        ['coco', {bare: false}]
    ]

How do we get such flexibility with both [] & {} formats? Check [ResourceConverter.coffee](https://github.com/anodynos/uRequire/blob/master/source/code/config/ResourceConverter.coffee)

# Finito

Just export default and extra RCs and go grab a cup of coffee!

    # used as is by `bundle.resources`
    exports.defaultResourceConverters = defaultResourceConverters

## Add some coffeescript `define` and merge

AMD Modules written in coffee, livescript, iced-coffee-script, coco and others have the advantage of [merging pre-define IIFE-statements in combined template](combined-template#merging-pre-define-ifi-statements).
But for modules originally written in nodejs/common this is not the case, how can we take advantage of it?

Just wrap a `define ->` and `module.exports`, indent and **turn any coffeescript nodejs module into AMD** BEFORE compiling from .coffee to .js!

We need to add this as the very 1st in `defaultResourceConverters`, and have it disabled by default.

    ResourceConverter = require './ResourceConverter' # circular dep, but exports is already set :-)

    defaultResourceConverters.unshift wrapCoffeeDefineCommonJS =
      new ResourceConverter [
        'wrapCoffeeDefineCommonJS'
        [ '**/*.coffee' # not working with .litcoffee
          '**/*.co', '**/*.ls', '**.iced' ]

        (r)->
          lines = r.converted.split '\n'
          r.converted = 'define ->\n'
          for line in lines when line
            r.converted += '  ' + line + '\n'
          r.converted += "  return module.exports"

        # no `convFilename` - extension is still coffee/co/ls/iced or whatever matched
      ]

    wrapCoffeeDefineCommonJS.enabled = false

Now in your config, just have a `resources: [->(@ 'wrapCoffeeDefineCommonJS').enabled = true; null]` and treat your coffeescript nodejs source as AMD modules - just make sure that they are indeed commonjs and not AMD!
