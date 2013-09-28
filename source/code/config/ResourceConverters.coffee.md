**Resource Converters** is a powerful, generic and extendible **in-memory conversions workflow** or **in-memory assets pipeline**, that is expressive and flexible to cater for all common conversions needs (eg coffeescript, Livescript, coffeecup, less, jade etc).

*note: This file is written in [Literate Coffeescript](http://ashkenas.com/literate-coffeescript): it serves both as *markdown documentation* AND the *actual code*, just like [MasterDefaultsConfig](MasterDefaultsConfig.coffee#Literate-Coffeescript). This file primary location is https://github.com/anodynos/uRequire/blob/master/source/code/config/ResourceConverters.coffee.md & copied over to the urequire.wiki - DONT edit it separatelly in the wiki.*

## What is a ResourceConverter ?

A **ResourceConverter (RC)** is the *buidling block* of uRequire's *conversions workflow* system. An RC is a simplistic declaration and callback wrapping of a compiler/transpiler or any other converter/conversion. Each RC instance performs a conversion from one resource format (eg *coffeescript*, *teacup*) to another **converted** format (eg *javascript*, *html*), for all [bundle.filez](MasterDefaultsConfig.coffee#bundle.filez) that also match its own [`ResourceConverter.filez`](#Inside-a-Resource-Converter).

## **ResourceConverter workflow** principles

### **Simple authoring**...

...as a callback API that enables any kind of conversion, even with *one-liners*. This is an actual ResourceConverter :
   
   `[ '$coco', [ '**/*.co'], function(r){return require('coco').compile(r.source)}, '.js']`
   
  Authoring an RC is very simple and has a [formal spec](#Inside-a-Resource-Converter) and [space saving shortcuts](#the-alternative-even-shorter-way). 

### **Blazing fast**...

...with focus to an **in-memory conversions workflow**, with an **only-when-needed** asset processing pipeline, where each file is processed/converted/saved/copied *only when it really needs to* (very useful when used with [build.watch](MasterDefaultsConfig.coffee#build.watch) or grunt's watch).

### **DRY (Dont Repeat Yourself)**...

...via the *seamlessly integrated* [uRequire's configuration](MasterDefaultsConfig.coffee) settings shared among all your conversion pipelines . such as [bundle.filez](MasterDefaultsConfig.coffee#bundle.filez), [bundle.path](MasterDefaultsConfig.coffee#bundle.path), [build.dstPath](MasterDefaultsConfig.coffee#build.dstPath) etc, unobtrusively loading & saving with the leanest possible configuration. Check [an example](MasterDefaultsConfig.coffee#examples).

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

  function(){ rc = this("RCname4").clone(); rc.filez.push '!**/DRAFT*.*'; return rc} 
]

```

Also see [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) and the real [Default Resource Converters](#Default-Resource-Converters).

## Inside a Resource Converter

Ultimately, a **Resource Converter** instance has these fields:

 * `name` : a simple name eg. `'coffee-script'`. A `name` can have various flags at the start of its initial name - see below - that are applied & stripped each time name is set. A `name` should be unique to each RC; otherwise it updates the registered RC by that name (registry is simply used to lookup RCs).

 * `descr` : any optional details to keep the name tidy.

 * `filez` : the same format as [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) spec ([] of minimatch, RegExp & fns). It matches the files this RC deals with (always within the boundaries of `bundle.filez` files).

 * `convert()` :  the actual conversion callback `function(resource){return 'convertedText'}` that converts some resource's data (eg `source`, `converted` etc) and returns it. The only argument passed is a `resource` (the representation of a file under processing, which might also be a Module). 

   **NOTE: The context (value of `this`) is set to `this` ResourceConverter (uRequire >=0.6)**.
  
   The return value of `convert()` is stored as `resource.converted` and its possibly converted again by a subsequent converter (that has also matched the file), leading to an in memory *conversion pipeline*.
 
 Finally, after all conversions are done (for current build), **if `resource.converted` is a non-empty String**, its saved automatically at `resource.dstFilepath` (which uses [`build.dstPath`](MasterDefaultsConfig.coffee#build.dstPath)) & `convFilename` below.

 * `convFilename` :

  * a `function(dstFilename, srcFilename){return "someConvertedDstFilename.someext")}` that converts the current `dstFilename` (or the `srcFilename`) to its new *destination* `dstFilename`, eg `"file.coffee"` to `"file.js"`.

  * a `String` which can be either: a) starting with "." (eg ".js"), where its considered an extension replacement. By default it replaces the extension of `dstFilename`, but with the "~" flag it performs the extension replacement on `srcFilename` (eg `"~.coffee.md"`). b) a plain String, returned as is (*note: duplicate `dstFilename` currently causes a build error*).

 * [`type`](#resource-types:-the-type-field) & flags [`isTerminal`](#isTerminal), [`isBeforeTemplate`](#isBeforeTemplate),[`isAfterTemplate`](#isAfterTemplate) & [`isMatchSrcFilename`](#isMatchSrcFilename) that can be easily defined via `name` flags - explained right below.

### Resource types: the `type` field

The `type` is user set among ['bundle', 'file', 'text', 'module'] -the default is undefined- or it can be set by a *name flag* for simplicity:

|[ name flag (striped on set)]|[ type (user set) ]| [ clazz (system set) ]|
| :---:|  :---:   | :---:          |
| '&'  | 'bundle' | BundleFile    |
| '@'  | 'file'   | FileResource  |
| '#'  | 'text'   | TextResource  |
| '$'  | 'module  | Module        |

#### Attaching some clazz

Each Resource Converter in [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) is *attached* to each matching resource (i.e file in [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) ) and its `type` (`clazz` internally) ** *marks* the resource's class (to be instantiated)** either as `BundleFile`, `FileResource`, `TextResource` or `Module`.

**IMPORTANT**: Resource Converters order inside [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources) does matter, since **only the last matching RC (with a `type`) determines (marks) the actual class** of the created resource.

At each build/conversion cycle, each changed `resource` is passed to the `convert(resource)` of its matched RCs, in the order defined in `resources`.

The RC's `convert(resource)` call converts the `source` or `converted` of the resource and returns the result, or performs any other conversion on the file (eg spawing external tools, load as a module and use, copy it etc). The result of `convert()` is stored at `resource.converted`, available to the next RC in line.


### Flags & Name Flags 
___
#### isTerminal - "|"

A converter can be `isTerminal:false` (the default) or `isTerminal:true`.

uRequire uses each matching converter in turn during each build, converting from one format to the next, using the `converted` and `dstFilename` as the input to the next converter. All that until the first `isTerminal:true` converter is encountered, where the conversion process (for this resource instance) stops.

You can denote an RC as `isTerminal:true` in the {} format or with *name flag* `'|'`.
___
#### isBeforeTemplate - "+"

A converter with `isBeforeTemplate:true` (refers only to "Module" instances) will run just BEFORE the module is converted through [`build.template`](MasterDefaultsConfig.coffee#bundle.filez) (eg. 'UMD'). By default `isBeforeTemplate: false`. Use the `'+'` name flag to denote `isBeforeTemplate :true`.

The `convert(module)` function of `isBeforeTemplate` RCs will receive a Module instance ([Module is a subclass of BundleFile/Resource](#module-extends-textresource)) with : 

* parsed javascript in [Mozzila Parser AST](https://developer.mozilla.org/en/SpiderMonkey/Parser_API) format. 

* extracted/adjusted dependencies data, allowing an [advanced manipulation of module's code](#Manipulating-Modules).

* Methods & members to [manipulate the module instance](#Manipulating-Modules)

*Note: for `isBeforeTemplate` RCs, the **return value of `convert(module)` is ignored** - the template uses only AST code and dependencies to produce its @converted string at the next step (the template rendering).* You can affect the produced code (template rendering) only through [manipulating the Module](#Manipulating-Modules).
___
#### isAfterTemplate - "!"

A converter with `isAfterTemplate:true` (refers only to "Module" instances) will run right AFTER the module is converted through [`build.template`](MasterDefaultsConfig.coffee#bundle.filez). By default `isAfterTemplate:false`. Use the `'!'` name flag to denote `isAfterTemplate:true`.

Following the norm, the return value of `convert(module)` is assigned to `module.converted` and (assuming its the last RC) it is the value to be saved as `module.dstFilename` (assuming its a non-empty String). This is the place to add banners etc outside of the UMD/AMD/nodejs template.
___
#### isMatchSrcFilename - "~"

By default (`isMatchSrcFilename:false`) filename matching of `ResourceConverter.filez` uses the instance `dstFilename`, which is set by the last `convFilename()` that run on the instance (initially its set to srcFilename). Use "~" name flag or (`isMatchSrcFilename:true`) if you want to match `filez` against the original source filename (eg. `'**/myfile.coffee'` instead of `'**/myfile.js'`). The sane default allows the creation of RCs that are agnostic of how the input resource came about, whether they are actual matched '.js' files on disk or became a '.js' as part of the in-memory conversion pipeline.
___
#### Flag updating notes

Note: when you change `name`, `type` and `convFilename` of an RC, the properties are correctly updated (flags are set etc). 

The *name searching can also carry flags*, which are applied on the found RC, for example `"#coco"` will both find 'coco' ResourceConverter and also apply the `'#'` flag to it (`type:"TextResource"), before stripping it and leaving 'coco' as the name of the RC.
___


## Resource classes

Each file in [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) can be instantiated as one of 4 classes (each extending the previous one):  

**BundleFile** <- **FileResource** <- **TextResource** <- **Module**
_____
### BundleFile 

Represents a generic file inside the bundle. Its also the base class of all resources.

All [`bundle.filez`](MasterDefaultsConfig.coffee#bundle.filez) that 

* are NOT matched by any RC (that has some [`type`/`clazz`](resource-types:-the-type-field)), 

* last matched by an RC with an explicit `type:'bundle'` (or name-flagged with `'&'`) 

are instantiated as a `BundleFile`. 

BundleFiles instances are NOT converted at all - they are never passed to `convert()`. Also their contents are unknown. They can just be easily binary copied if they match [`bundle.copy`](MasterDefaultsConfig.coffee#bundle.copy).

#### Watching BF changes 

When watching, a BundleFile instance is considered as changed, only when fs.stats `size` or `mtime` have changed since the last refresh (i.e a partial/full build noting this file).

#### Properties 

BundleFile class serves as a base for all resource types  - its the parent (and grand* parent) class of the others. Each BF instance (and consequently each resource/module instance passed to `convert()`) has the following properties :

##### Filename properties

###### source properties

* `srcFilename` : the source filename, within the bundle, Eg `'models/initialValues.json'` or `'models/Person.coffee'`

* `srcFilepath` : calculated to include [`bundle.path`](MasterDefaultsConfig.coffee#bundle.path), eg `'source/code/models/initialValues.json'`

* `srcRealpath` : the full OS path, eg `'mnt/myproject/source/code/models/initialValues.json` - useful for `require`ing modules without worrying about relative paths.

###### destination properties

* `dstFilename` : as it is returned by the last executed `convFilename`. Its initial value is `srcFilename`. Eg `'models/initialValues.json'` or `'models/Person.js'`.

* `dstFilepath` : calculated to include [`build.dstPath`](MasterDefaultsConfig.coffee#build.dstPath), eg `'build/code/models/Person.js'`

* `dstRealpath` : the full OS destination path, eg `'mnt/myproject/build/code/models/Person.js`

@note `dstXXX` : **When two ore more files end up with the same `dstFilename`**, build halts. *@todo: This should change in the future: when the same `dstFilename` is encountered in two or more resources/modules, it could mean Pre- or Post- conversion concatenation. Pre- means all sources are concatenated & then passed once to `convert`, or Post- where each resource is `convert`ed alone & but their outputs are concatenated onto that same `dstFilename`*.

##### other info properties

* `fileStats` : auxiliary, it stores ['mtime', 'size'] from nodejs's `fs.statSync`, 
needed internally to decide whether the file has changed at all (at watch events that note it).

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

    Note: As of uRequire 0.6, generating SourceMaps while converting Modules with Template (UMD / AMD / nodejs / combined) [**is not implemented**](https://github.com/anodynos/uRequire/issues/24). Its only useful for compiling coffee to .js with an [RC like this](https://github.com/anodynos/uRequire/issues/24).

##### Utility functions

* `copy()` : each BundleFile (or subclasses) instance is equiped with a `copy(srcFilename, dstFilename)` function, that binary copies a file (synchronously) from its source (`bundle.path` + `srcFilename`) to its destination (`build.dstPath` + `dstFilename`). 
 
  It can be used without any or both arguments, where the 1st defaults to `resource.srcFilename` and 2nd to `resource.dstFilename`. Both filenames are appended respectively to `bundle.path` & `build.dstPath`.

  Example:

  With `copy()` you can have a converter that simply copies each file in `RC.filez`, eg:

  `['@copyVendorJs', ['vendorJs/**/*.js'], (r)-> r.copy()]`

  or copies them renamed, from `bundle.path` to `build.dstPath` eg

  `['@copyRenamedVendorJs', ['vendorJs/**/*.js'], (r)-> r.copy(null, 'renamed_'+e.dstFilename)]`

  Note: to avoid the appending to `bundle.path` & `build.dstPath`, use the static `resource.constructor.copy()` that has no default arguments or appending. 

  `copy()` makes sure that **no redundant copies are made**: when the destination file exists, it checks nodejs's `fs.stat` `'mtime'`, `'size'` and copies over only if either is changed, and skips if they are the same. It returns `true` if a copy was made, `false' if it was skipped.

* `requireUncached('name')` : a utility wrapper to nodejs `require('name')`, that makes sure the cached module (and its dependencies) is cleared before loading it.
 
  Its useful if you want to load a fileResource (that changed on disk) as a nodejs module (nodejs modules are cached and don't reload when file on disk changes).
  The instance method is a wrapper to the BundleFile.requireUncached() static method, added as instance method for convenience **with `resource.srcRealpath` as the default value** of the `name` argument.

  Example: see 'teacup' at [Extra Resource Converters](#Extra-Resource-Converters)

There are also some other methods that are used *internally only*, like `refresh()` & `reset()` - don't use them!

_____
### FileResource extends BundleFile

ResourceConverters that mark files as `FileResource` have a name flag '@'  or `type: 'file'`

A `FileResource` represents an external file, whose `source` contents we know nothing of: we dont read it upon refresh() or base our 'hasChanged' decision on its source.

The `convert()` is called for each matched file, passing a `FileResource` (or a subclass) instance. `FileResource` instances are useful when their corresponding file `source` contents are not useful, or we simply want to save time from double-reading them. For instance we might want to :

 * `fs.read` their contents our selves 
 
 * require them as modules (perhaps with `requireUncached()`) and execute their code to get some result.
 
 * spawn external programs to convert them, copy 'em, etc

In all cases the call is synchronous.

Example: consider 'teacup' in [Extra Resource Converters](#Extra-Resource-Converters): each time the underlying FileResource changes, it loads it as a nodejs module (which returns a teacup function/template) and them renders it to HTML via the 'teacup' module.

If `convert()` returns a String, it is stored as `converted` on the instance and it is saved at `dstFilename` at each build cycle.

#### Watching FileResource changes

When watching suggests the underlying file has changed, a `FileResource` instance is considered as changed, only when `fs.stats`'s `size` & `mtime` have changed, functionality inherited by `BundleFile`. The contents are NOT checked on each refresh(). 

#### FileResource Methods

Paradoxically, a *FileResource* instance has instance methods to `read()` and `save()`:

* `read()` : a `function(filename, options)` that reads and returns contents of the source file. It takes two **optional arguments**:

 * `filename`, which is appended to `bundle.path`. It defaults to `resource.srcFilename`.

 * `options` hash, passed as is to [`fs.readFileSync`](http://nodejs.org/api/fs.html#fs_fs_readfilesync_filename_options), with `utf8` as the default `encoding`.

 You can use `read()` on demand from within `convert()`, for example:  
 ```
    convert: function(fileResource){ return 'Banner' + fileResource.read()}
 ```

 Note: Use the static `resource.constructor.read()` method to skip default `filename` & `bundle.path` appending.

* `save()`: a `function(filename, content, options)` that saves the contents to the destination file. It takes **three optional arguments**: 
* 
 * `filename`, appended to `build.dstPath` and defaults to `resource.dstFilename`

 * `content`, the (String) contents to be saved, defaults to `resource.converted`

 *  `options` hash which is passed to [`fs.writeFileSync`](http://nodejs.org/api/fs.html#fs_fs_writefilesync_filename_data_options) with 'utf8' as default encoding.
 
 Use the static `resource.constructor.save()` that has no `dstPath` appending and default values (only 'utf8' is default)
_____
### TextResource extends FileResource

A subclass of [FileResource](#FileResource-extends-BundleFile), it represents any *textual/utf-8* **Resource**, (eg a `.coffee` file). The only difference is that it calls `read()` each time it refreshes and stores it as `resource.source` (and the initial value of `resource.converted`) and then it takes `resource.source` into account for watching.

#### Watching TR changes

A `TextResource` instance is considered as changed, if parent TextResource/BundleFile says so (`fs.stats`'s `size` & `mtime`), and if they do, it checks if `read()`-ing source (eg the .coffee contents) has changed. 

This is to **prevent a lengthy processing/converting of files** that the editor has saved/changed/touched, but no real content change has occurred.
_____
### Module extends TextResource 

A **Module** is **javascript code** with node/commonjs `require()` or AMD style `define()`/`require()` dependencies.

Each Module instance is converted just like a **TextResource**, but its javascript source and dependencies come into play: 

* Its javascript source is parsed to [Mozilla Parser AST] (https://developer.mozilla.org/en/SpiderMonkey/Parser_API) via the excellent [esprima parser](http://esprima.org/).

* Its **module/dependencies info is extracted & adjusted** at each refresh (with real javascript source changes). Ultimately its dependencies are analysed, adjusted and finally the module gets converted through the chosen [`build.template`](MasterDefaultsConfig.coffee#build.template).

#### Watching Module changes

A `Module` instance is considered as changed (hence its module info adjusting), if parent says so (`fs.stats` & @source), but also if the resulting *Javascript source* has changed. This is for example to prevent processing a module whose coffeescript source has changed, but its javascript compiled code remained the same (eg changing coffeescript whitespaces).

## Manipulating Modules

The special [`isBeforeTemplate` flag of ResourceConverters](#isbeforetemplate) allows advanced manipulation of Modules: when this flag is true on an RC, **the ResourceConverter runs (only) just before the template is applied**, but after having AST parsed the javascript code and extracted/adjusted the module's dependencies information. 

Hence, the `convert()` RC method is passed a Module instance with **fully extracted & adjusted dependencies information, with a parsed AST tree and with facilities to manipulate it at a very high level**, far more flexible than simple textual manipulation/conversion.

*Note: for [`isBeforeTemplate` RCs](#isbeforetemplate), the **return value of `convert()` is ignored** - the template uses only AST and dependencies to produce its @converted string at the next step (template rendering). Use the [Module Members](#Module-Members) to affect the resulted `module.converted`.*

### Module Members 

The following member properties/methods manipulate a Module instance:

#### Inject any string before & after body
`beforeBody` : Any String that is concatenated just before the original 'body' on the template rendering, for example:
```
[ '+inject:VERSION', ['uberscore.js'], 
  function(modyle){modyle.beforeBody = "var VERSION='" + version + "';"}
]
```            

Module 'uberscore.js' will get this string injected before its body, **but inside the module**.

`afterBody` : A String concatenated after the original body, just like `beforeBody`.

### Manipulate/replace AST code

`replaceCode(matchCode, replCode)`: A function that replaces (or removes) a code statement/expression that matches a code 'skeleton'. It takes two arguments:

 * `matchCode` : (mandatory) the statement/expression to match in the AST body - it can be either: 

  * a **String**, which MUST BE a **single parseable Javascript statement/expression** (it gets converted to AST, getting the first body node). For example:
 ```
    'if (l.deb()){}'
 ``` 
 will match all code like :
 ```
    if (l.deb(someParam, anotherParam)){
        statement1;
        statement2;
        ...
    } // no else or it wont match
 ```

  * or an **AST 'skeleton'** object (in [Mozzila Parser AST](https://developer.mozilla.org/en/SpiderMonkey/Parser_API)) like:
 ```coffeescript
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

For example :
```
resources: [
  ...
  [
    '+remove:debug/deb', [/./]                              
    function(modyle){ modyle.replaceCode('if (l.deb()){}');}                      
  ]
  ...  
]
```
will remove all code that matches the `'if (l.deb()){}'` skeleton.

#### Inject / replace dependencies

* `replaceDeps(oldDep, newDep)`: a method that replaces dependencies in the resolved dependencies arrays and the body AST (i.e `require('../some/dep')` of the module. Its taking two arguments:

 * `oldDep`: the dependency to find and replace, in [bundleRelative format](#bundlerelative-vs-filerelative-paths), eg `'models/Person'` or `'underscore'`

 * `newDep`: the dependency to replace with, again in [bundleRelative](#bundlerelative-vs-filerelative-paths) format, eg `'mockModels/PersonMock'` or `'lodash'`
    If newDep is ommited (i.e undefined), the **dependency is removed** from the module, along with its corresponding parameter (if any). Note its not removed from the actual module's body, i.e if it exists as a `require('dep')`).

 In any case, the dependency is matched considering the module's location within the bundle.

 example: `m.replaceDep('models/Person', 'mockModels/PersonMock')`

* `injectDeps(depVars)`: a method that injects one (or more) dependencies, along with one or more variables to bind with them on the module. Its taking only one argument, with the type of [`bundle.dependencies.depsVars`](MasterDefaultsConfig.coffee#bundle.dependencies.depsVars).

For example 
```
  module.injectDeps({ 'lodash':'_', 'models/Person':['persons', 'personsModel']})
```  

The deps are (the keys of the object) are always given in [bundleRelative](#bundlerelative-vs-filerelative-paths) format.

 `injectDeps` is used internally to inject [`dependencies.exports.bundle`](MasterDefaultsConfig.coffee#bundle.dependencies.exports.bundle) - on templates other that `'combined'` that need it. 

  In general it makes sure that : 

 * not two same-named parameters are injected - the 'late arrivals' bindings are simply ignored (with a warning). So if a Module already has a a parameter `'_'` and you try to inject `'lodash':'_'`, it wont be injected at all.

 * Not injecting a self-dependency. If you are at module 'agreements/isAgree', trying to inject dependency 'agreements/isAgree' will be ignored (without a warning, only a debug message).

 * For deps without a variable binding, eg `mod.injectDep({'models/Person':[]}):`, the variable bindings are inferred from the bundle (other modules that `myBindinedDepVar = require('dep')` or `define(['dep'], function(myBindinedDepVar){})` or [`bundle.dependencies.depsVars`](MasterDefaultsConfig.coffee#bundle.dependencies.depsVars) etc

 Note: uREquire doesn't enforce that the injected dependency is valid, for example whether it exists in the bundle.

# Default Resource Converters

The following code [(that is actually part of uRequire's code)](#Literate-Coffescript), defines the **Default Resource Converters** `'javascript', 'coffee-script', 'LiveScript' & 'coco'` all as `type:'module'` (via '$' flag). They are the default [`bundle.resources`](MasterDefaultsConfig.coffee#bundle.resources):

    defaultResourceConverters = [

### The formal **Object way** to define a Resource Converter

This is a dummy .js RC, following the [formal RC definition](#Inside-a-Resource-Converter):

        {
          name: '$javascript'             # '$' flag denotes `type: 'module'`.

          descr: "Dummy js converter, does nothing much but marking `.js` files as `Module`s."

          filez: [                        # type is `bundle.filez`, matches files RC is attached to
            '**/*.js'                     # minimatch string, with exclusions as '!**/*temp.*'
                                          # RegExps work as well, with[.., `'!', /myRegExp/`] for exclusions
            /.*\.(javascript)$/
          ]

          convert: (r)-> r.source         # javascript needs no compilation - just return source as is

          convFilename: (srcFilename)->   # convert .js | .javascript to .js
            (require '../paths/upath').changeExt srcFilename, 'js'

          type: 'module'                  # not needed, we have '$' flag to denote `type: 'module'`

          # these are defaults, can be omitted
          isAfterTemplate: false
          isTerminal: false
          isMatchSrcFilename: false
        }

### The alternative (less verbose) **Array way**

This RC is using an [] instead of {}. Key names of RC are assumed from their posision in the array:

        [
          '$coffee-script'                                           # `name` & flags as a String at pos 0

                                                                     # `descr` at pos 1
          "Coffeescript compiler, using the locally installed 'coffee-script' npm package. Uses `bare:true`."

          [ '**/*.coffee', /.*\.(coffee\.md|litcoffee)$/i]           # `filez` [] at pos 2

          (r)->                                                      # `convert` Function at pos 3
             coffee = require 'coffee-script'                        # 'coffee-script' must be in 'node_modules'
             coffee.compile r.source                                 # return converted source

          (srcFn)->                                                  # `convFilename` Function at pos 4
            coffeeExtensions = /.*\.(coffee\.md|litcoffee|coffee)$/  # RexExp for all coffeescript extensions
            ext = srcFn.replace coffeeExtensions , "$1"              # retrieve matched extension
            srcFn.replace (new RegExp ext+'$'), 'js'                 # replace it and return new filename
        ]

### The alternative, even shorter `[]` way

        [
          '$LiveScript'                                    # `name` at pos 0
          [ '**/*.ls']                                     # if pos 1 is Array, its `filez` (& undefined `descr`)
          (r)->(require 'LiveScript').compile r.source     # `convert` Function at pos 2
          '.js'                                            # if `convFilename` is String starting with '.',
        ]                                                  # it denotes an extension replacement of `dstFilename`
                                                           # if `~` flag is used, eg `~.js`, ext replacement is applied on `srcFilename`

### The shortest way ever, a one-liner converter!

        [ '$iced-coffee-script', [ '**/*.iced'], ((r)-> require('iced-coffee-script').compile r.source), '.js']

        [ '$coco', [ '**/*.co'], ((r)-> require('coco').compile r.source), '.js']

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
         """
          Renders teacup as nodejs modules (exporting the template function or a `renderable`), to HTML.
          FileResource means the file's source is not read/refreshed.
         """
         ['**/*.teacup']
         do ->
            require.extensions['.teacup'] = 
                require.extensions['.coffee']              # register extension once, as a node/coffee module
            (r)->                                          # our `convert()` function
              template = r.requireUncached r.srcRealpath   # Clear nodejs caching with `requireUncached` helper 
                                                           # and get the `realpath` of module's location.
              (require 'teacup').render template           # require `teacup` on demand from project's 
                                                           # `node_modules` and return rendered string
                                                            
         '.html'                                           # starting with '.' is an extension replacement
      ]

# Finito 

Just export default and extra RCs and go grab a cup of coffee!

    module.exports = {
      defaultResourceConverters       # used as is by `bundle.resources`
      extraResourceConverters         # registered on `ResourceConverter` registry, instantiated on demand.
    }
