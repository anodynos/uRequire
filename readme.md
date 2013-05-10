# uRequire v0.3.0beta

**Write *modular Javascript code* once, run everywhere** using [UMD](https://github.com/umdjs/umd) based module translation/conversion that targets Web [(AMD/RequireJS)](http://requirejs.org/) & nodejs/commonjs module systems.

___________________________________________________________________________
## Breaking news for v0.3.0 beta

This documentation is from older versions v0.1.x / 0.2.x.

_Skip below, if you're after general information._

Everything mentioned here works the same, but current version 0.3 (currently in beta) brings many great features, NOT yet documented :

### Universal **Combined** Module optimization for Web, AMD & nodejs!

The most important feature, a new `combined` template, that builds (optimizes with `r.js` & `almond`) and outputs a single .js file, thats a 3-fold build: Web/Script, Web/AMD & nodejs.

In all cases, globals/externals dont have to be inlined, but can be used either from `window`, the *AMD config* or *nodejs `require`* respectively.
The `combined` script automagically *detects at runtime where it is excuting* and chooses appropriatelly.

In more detail:

#### Web/Script </script>

Works in browser, as a simple `<script/>`, independently of AMD/RequireJS.
The script can register some global (`window`) variables when it loads, for example `$2` or `_B`, via the `rootExports` declaration.
It accesses all other (non-included) global dependencies through the global space (`window`), like all plain `<script/>` do.
So for example, you load your 'jquery.js', 'lodash.js', 'Backbone.js' and then you load your 'MyApp.js' and you're done!

#### Web/AMD

Works as an AMD dependency, loading all other (non-included) dependencies through AMD's mechanism.
In other words its using `rjs.baseUrl`, `rjs.paths`, `rjs.shim` etc.

#### nodejs

Works in nodejs, as is. Its loading all (non-included) dependencies through nodejs's 'require'.
It has no other dependencies, i.e you dont need to have *uRequire* or *RequireJs* installed locally at all.

Are you still concatenating files ? uRequire your project now!

###  **bundleExports**, a dependencies-injection mechanism:

A sexy new feature, `dependencies.bundleExports` allows you to declare bundle-wide *global* dependencies. These are implicitely available in all your modules, without repeating the `require`s.

For example, if you use ['lodash', 'backbone', 'myLib', ...] in all your bundle modules, just use a `dependencies.bundleExports: ['lodash', 'backbone', 'myLib']` and its saving you from having to require 'em in **every module of your bundle**.

If you want to have precise control over the variables that hold you modules, use this format:

    dependencies.bundleExports: {
        'lodash': '_',
        'backbone': 'Backbone',
        'myLib': ['myLib', 'myLibOtherName']
       }

Most times, uRequire can discover the variable names, if its 'define'd even once in an AMD module!

### **uRequire config** A completely new 'bundle' & 'build' hierarchical configuration scheme.

The 'derive' feature ('config' action in urequireCMD), where a hierarchical/inheritance chain of *uRequire config* files is used to allow a fine-grained definition of the bundle & build information.

It is extremelly versatile:
  - it understands keys both in the 'root' of your config or in 'bundle'/'build' hashes
  - it provides shortcuts, to convert simple declarations to more complex ones.

### Other features
- `.coffee` files are valid source modules (.iced, .coco, .ls & .ts are coming). All modules are compiled and parsed only as javascript; module generation is again just javascript (currently - see #14).
- Improved debugging / warning / informational handling and output.
- Huge code revamp, can easily be used by other libraries (check `urequireCMD.coffee` & [grunt-urequire](https://github.com/aearly/grunt-urequire)).

### Documentation/development is still WIP

For details/glimpse check [github.com/anodynos/uBerscore](https://github.com/anodynos/uBerscore) project :

* Just have a glance at the code structure 'uberscore.coffee', u dont have know what each sub-module does.
* See `examples/uBerscoreExample_XXX.html` and `spec/specRunnerXXX.html` for how each build is used.
* Check `source/code/uRequireConfig.coffee` & `source/code/uRequireConfig_UMDBuild.json` to see how easilt you can define `bundle`s and `build`s.
* In `Gruntfile.coffee` check the `urequire:xxx` tasks to see some documented examples
* For more config documentation (still not-stable & incomplete!) check `source/code/config/uRequireConfigMasterDefaults.coffee`.

___________________________________________________________________________

# Back to v1.x/v2.9 docs

## The hasty coder intro :

### Why ?

The main drive behind uRequire is to enable you to author **boilerplate-free** *modular javascript code* once, and seamlessly execute & test it everywhere (for now **browser** & **nodejs**).

With a simple build step, uRequire converts your modules to UMD (& more) using static code analysis, a code generation template system and build/runtime path resolution along with other runtime goodies.

### How ?

Your source can be written either in the 'strict' AMD format `define([], function(){})` or the nodejs/commonjs `require('dep')`.

But, you can also use a *relaxed* or *hybrid* version, (eg. use asynch `require([], fn)`s everywhere) and extra kinky features.

uRequire converts it to suitable UMD format that can be deployed everywhere.

### Extras ? Kinky ?

 * You don't need to surround you code with any UMD-like boilerplate

 * Universal [path translations](https://github.com/anodynos/uRequire#bundleRelative-vs-fileRelative-paths), eg from `../../../PersonModel` to `data/PersonModel`

 * Never miss a `require('')` declaration on `define([],...)` that [halts your app](https://github.com/anodynos/uRequire#never-miss-a-dependency)

 * You can use **RequireJS [loader plugins](https://github.com/anodynos/uRequire#requirejs-loader-plugins)**

 * Forget hand-coding boring module features like exporting to [`root`/`global`/`window`](https://github.com/anodynos/uRequire#simplified-rootexports), or implementing [`noConflict()`](https://github.com/anodynos/uRequire#no-worries-noconflict) etc.

**`{"uDeclare": "uRequire does all this magic for you."}`**

### Moto

**if you have sensibly `define`d it, u`Require` will find it**

*if you're in hurry to code, jump to [features](https://github.com/anodynos/uRequire#features-at-a-glance) and if you wanna hit 'build' goto [Module authoring](https://github.com/anodynos/uRequire/#module-authoring).*

## The cautious Architect's intro: *Ultimate Aims*

### A Universal Module Converter

Right now uRequire converts only from *AMD and/or nodejs* **to UMD**  and **to pure AMD/nodejs**.

The aim is to provide conversion TO and FROM *ANY* JavaScript module systems. Many are obvious (eg Harmony) but it should also convert (and/or provide transparent runtimes) for plain old html `<script/>` (eg. to help authors of generic .js libs).

uRequire is using a [flexible template](https://github.com/anodynos/uRequire/tree/master/source/code/templates/ModuleGeneratorTemplates.coffee) written in pure Coffeescript, that can do wonders, albeit simple. An average CS coder would need <30 minutes for a 10 liner template like ['nodejs'](https://github.com/anodynos/uRequire/tree/6d04decd63e/source/code/templates/ModuleGeneratorTemplates.coffee#L146-161).

### Boilerplate no more!

uRequire removes the *mud* from **UMD**, which is currently the *only true option* for cross-platform modular javascript development, but its *ugly*.

U will no longer add UMD around your **non-modular code** to AMDdify the *deployment*.
U are empowered to use modules to **better structure your code** during *development*.

Keep it DRY!

### Fix pains, Relax, 'Just do it'

The aim is to cater for (m)any format intricacies and fix (m)any common pains, problems and omissions from module definition formats.

uRequire provides the *simplest possible* authoring of **modular javascript code** with a *relaxed* dependencies structure for modules, using the 'good parts' from AMD and nodejs. It brings browser-side best practices (that appear to be [AMD/requirejs](http://requirejs.org/)) closer to nodejs. And vise versa.

It helps you have natural & flexible structuring and refactoring of javascript code.

### Unlock and 'Do it just'

uRequire empowers code reuse & modularity without one-side locking.

The lost **Java** dream of cross-platform execution (that flopped on browser) is becoming true with JavaScript *(the [10day toy language](http://en.wikipedia.org/wiki/Brendan_Eich)!, that won the browser and now nodejs takes Jobol to the server race. And then you have WinJS, appcelerator/mobile and who knows what in a few years!)*

The aim is that when no browser/DOM or nodejs specifics are present, the same source code runs & tests on both *browser* and *nodejs* (and go on for WinJS, Titanium and whatever:-).

### Functionality injection

uRequire can generate code and inject it on modules. With flexible templates (& parsers), it can also convert *code structure*.

Hence popular *standardized* functionalities and structures (like [`noConflict()`](https://github.com/anodynos/uRequire/tree/6d04decd63e/source/code/templates/ModuleGeneratorTemplates.coffee#L74-92)), no longer have to be *hand-crafted*. The less code u write, the less errors and barriers!

uRequire empowers a form of *declarative feature injection* for modules.

## Features at a glance

* Based on a 'familiar' standardized [*UMD template*](https://github.com/umdjs/umd/blob/master/returnExports.js) with optional global exports based on [returnExportsGlobal.js](https://github.com/umdjs/umd/blob/master/returnExportsGlobal.js). Also it converts to [native nodejs or AMD](https://github.com/anodynos/uRequire#convert-to-pure-amd-or-pure-node) - the latter usefull for r.js optimization & bundling.

* **Accomodates both `define()` and `require()` to work the same way in both browser & node.**

    * Specifically, the browser AMD-style `require([..], function(..){})` works on nodejs, just as it does on the browser: [asynchronously](https://github.com/anodynos/uRequire#asynchronous-require).

    * And vise versa, the node-style `var a = require('a')` also works on browser (at least seemingly) [synchronously](https://github.com/anodynos/uRequire#synchronous-require).

    * Finally, `define` is 'worked' inside UMD to behave as expected on both web & nodejs.


* Automatically fills missing `require('')` dependencies from [], that would otherwise [halt your app @ runtime, since *requirejs scan* is off](https://github.com/anodynos/uRequire#never-miss-a-dependency).

* Resolves paths dependencies between formats, allowing modules to transparently have a *bundle-root* as a reference point (eg `models\PersonModel`) that [works in both Web/AMD and nodejs](https://github.com/anodynos/uRequire#bundleRelative-vs-fileRelative-paths).

* Declaratively generates the boilerplate for [`rootExports`](https://github.com/anodynos/uRequire#simplified-rootExports) (global variables to export, eg '_', '$' etc), from a simple declarative setting, on any module. Additionally [`noConflict()`](https://github.com/anodynos/uRequire#no-worries-noconflict) boilerplate code can be produced on any module, again declarativelly.

* Checks your dependencies are valid at build time. It identifies dependencies within bundle boundaries and whether those exist.
It also identifies and works with 'globals', 'externals', ['webRootMap',  'requireJS baseUrl/paths'](https://github.com/anodynos/uRequire#mappings) etc. In future versions uRequire will check their validity, before deploying.

* Use [loader plugins](https://github.com/anodynos/uRequire#requirejs-loader-plugins) everywhere, web or nodejs.

* Requires no additional dependency on Web AMD/RequireJs. On nodejs you 'll need `npm install urequire` to execute UMD modules, which gives you extra [deployment functionality](https://github.com/anodynos/uRequire#deployment-options).

##Module authoring

With uRequire, your modules can be either written in AMD:

```js
// standard anonymous module format
define(['dep1', 'dep2'], function(dep1, dep2) {
   // do stuff with dep1, dep2
   return {my:'module'}
});

// or a named module
define('moduleName', ['dep1', 'dep2'], function(dep1, dep2) {...});

// or a module without *array* dependencies
define(function() {...})
```

or in the CommonJs/nodejs format:

```js
var dep1 = require('dep1');
var dep2 = require('dep2');
// do stuff with dep1, dep2
module.exports = {my: 'module'}
```

or a *relaxed** combination of both:

```js
// uRequire relaxed notation
define(['dep1', 'dep2'], function(dep1, dep2) {
   var dep3 = require('dep3');
   // do stuff with dep1, dep2, dep3
   return {my:'module'}
});
```
 * *relaxed means you dont need to be strict to either standard, but also it would NOT work as a plain AMD/nodejs module without uRequire conversion.*

uRequire strives to guarantee that your modules are correctly translated and execute on both target environments, even though the easier, less verbose *relaxed* format is used.

The idiosyncrasies and limitations of module formats are waived, so you can focus on what is important: you modular code that can be expresed in the easiest sensible way possible.

For instance you can use both the syntax of sync & asych require, mix absolute/bundleRelative with fileRelative paths, forget about requiring `require` or `module`/`exports` and just be sure that your code will execute on both runtimes in a consistent way.


### *bundleRelative* VS *fileRelative* paths

You can use *bundleRelative* (i.e. absolute 'depdir/dep') or *fileRelative* (i.e relative '../../dep') paths interchangeably.

* On node, dependencies are relative ONLY to requiring file (aka *fileRelative*), which I feel is a source of misconceptions on modularization it self, in regards to development: what happens if you move a file ? what does that dotted path mean ?

* Vanilla AMD/RequireJS on browser works with `fileRelative`, but also allows an absolute *bundleRelative* path like `models\PersonModel`, relative to some 'bundle', i.e. `baseUrl`.

uRequire allows you to use both semantics, no matter what you write in (nodejs/AMD), as it converts them (at build and execution time on node) to work on both runtimes.

There are cases that [both are usefull](https://github.com/anodynos/uRequire#mix-them-up), so mix 'em up!

### Synchronous require

U can use the simple `require('depdir/dep')` anywhere you like (nodejs or AMD), without any worries: there is automation.

#### No more require, module, exports

You dont need to define 'require' as an AMD dependency, or use a param 'module', 'exports' when you use the nodejs `require('')` notation. Its done for you:

* Just write your module using AMD structure `define(['dep1'],fn(dep1){})`, and use `require('dep2')` as you would normally do on nodejs - no need to add 'require' as the first dependency on [].

* or use the plain nodejs notation with `var m = require('m')`, having a `module.exports = myModule;` somewhere.

Your modules will convert and work in UMD (or AMD or nodejs!).

#### Never miss a dependency

In RequireJS/AMD runtime, if you have a `require('myDep')` in your main module (factory) code, there are two cases:

   * You are using the [*simplified define wrapper*](http://requirejs.org/docs/api.html#cjsmodule), i.e you have NO dependencies array and have passed require (& company) as parameter(s). RequireJS actually 'scans' your module code at runtime, prefetching all deps in `require('dep')` calls. This works fine, **if you stick to it** (although it might cost on speed).

   * You do have array dependencies - they are preloaded. If you have even one array dep [(even 'require')](https://github.com/jrburke/requirejs/issues/467)), RequireJS doesn't scan for `require` calls to preload at runtime. So, if 'myDep' is missing from [], [**your module/app will halt**](http://www.requirejs.org/docs/errors.html#notloaded).

uRequire automatically fills missing `require('')` dependencies from [] declarations, naturally after having resolved their paths.

### Asynchronous require

U can use the *asynchronous* (array) version of require `require(['...'], function(){...})`, anywhere you like, web or nodejs.

Keep in mind that the asynchronous require is essentially the only way to *conditionally* load 'myHugeButOptionalModule' on the web/AMD side. For instance,

```js

if (true) {// perhaps some code here,
        // to conditionally call asynch 'require' bellow
  require(['depdir/dep1', 'depdir/dep2'], function(dep1, dep2) {
    // module factory function
    // called asynchronously & after dep1 & dep2 are loaded
    // module returned here
  });
}
// code here is executed immediatelly after calling `require`,
// BEFORE calling the factory function, since its asynchronous.
```
The asynch require always runs asynchronously on nodejs, just like it does on Web RequireJS/AMD.

*Note: versions of RequireJS < 2.1.x were not consistent on the asynchronous call of require(['dep1', 'dep2'], fn): if all your dependencies ['dep1', 'dep2'] had already been loaded/cached before, the call to fn was actually synchronous. uRequire now matches the behaviour of the latest RequireJS (always asynch).*

### Exporting root (global) variables with noConflict() (WEB/AMD)

#### Simplified `rootExports`

You can declaratively export one (or more) global variables from your UMD module on the web side: just include an object literal **on the top** of your (source) module file like this:

```js
({urequire: { rootExports: 'uBerscore' } });
```

Or use an array :

```js
({urequire: { rootExports: ['uBerscore', '_B']}});
```

in case you want many global vars.

These globals be created as keys on 'root' (eg `window` on browsers), with the module as the value (possibly overwriting existing keys).

#### No worries, `noConflict`
If you want to save existing root keys and return to their original value at some point, you can use `noConflict`, with similar behaviour to [jQuery's](api.jquery.com/jQuery.noConflict/).

Again, you do this declaratively:
```js
({
  urequire: {
    rootExports: ['_B', 'uBerscore'],
    noConflict: true
  }
});
```

At some point in your code, you can call `var myB = _B.noConflict();` which will revert *all* rootExports variables to their original values, returing the module which you can store elsewhere.
In future uRequire versions you'll be able to pass an 'exclude' array param & do a `rootExports()` to re-export root vars.

More declarative options will follow :-)

### Mappings

* You can map webRootMap `/` to a directory of your nodejs environment (--webRootMap option). The directory can be relative to bundle (paths starting with a `.`) or an absolute file system path (eg `/dev/jslibs`). Just make sure your Web Server has the right content mapped to `/` and you're set!

* You can use the requirejs config `baseUrl` and `paths` on nodejs (only those for now) - just place a file named `requirejs.config.json` in your bundle root directory, with content like {"paths": {"myLib" : "../../myLib"}}. Very usefull for 'importing' bundles, eg running specs against 'myLib' bundle using mocha, jasmine-node etc. Again, use the same config items on RequireJS/Web for transparent cross platform module usage.

### RequireJS loader plugins

You can use *native* [loader plugins](http://requirejs.org/docs/api.html#plugins) (those that make sense in node?) just like any other module.

For example:

`var myText = require('text!myTextFile.txt')`

or

`define(['json!myjson.json'], function(theJson){...})`

uRequire uses *RequireJS for node* to actually load the plugin and let it do the actual loading work.

You can just put them on your `bundleRoot` and use them right away. For example to use `"text!myText.txt"` you 'll need to copy [`text.js`](https://github.com/requirejs/text/blob/master/text.js) on your bundleRoot, or put it in a folder relative to bundleRoot and note it on `requirejs.config.json` - see `examples/abc`.

Only 2 plugins have been tried so far (text, [json](https://github.com/millermedeiros/requirejs-plugins/blob/master/src/json.js)), but most that dont rely on browser features should work...


### Authoring Notes

* Your `require`s must use a string, eg `require('myModule')`. Requires that evaluate at runtime, eg `require(myVar + 'module')` can't be possibly be evaluated at parse time, and thus are *unsafe*.

* Your module `define(..)` must be a top level in your .js (not nested inside some other code).

* Everything outside `define` is simply ignored.

* Only one module per file is expected - i.e only the first `define` per file is parsed.

* You can use the `.js` extension (but why?), as it is allowed by nodejs. Because of the [different semantics in RequireJS](http://requirejs.org/docs/api.html#jsfiles), its fixed(i.e stripped) for you if needed (i.e it exists on your bundle dir).

* There are some limitations due to the parser/code generator used ([uglifyjs](https://github.com/mishoo/UglifyJS)) : a) Comments are ignored and b) some [unsafe transformations](https://github.com/mishoo/UglifyJS#unsafe-transformations). This will change sometime, when the parser changes to [UglifyJS2](https://github.com/mishoo/UglifyJS2) or [esprima](esprima.org).

### Authoring modules finale

Should you choose to adhere to the 100% [standard syntax of AMD](https://github.com/amdjs) or [nodejs](http://nodejs.org/api/modules.html), so that your pre-build *source* code is also valid/executable too, that's fine.

uRequire will at least be as good as:

a) converting them to the 'other' runnable version, should you require it

and

b) perform sanity and dependency checks on your source before deploying (and get a report {-v --verbose}) while fixing common AMD errors like [missing a dep](https://github.com/anodynos/uRequire#never-miss-a-dependency).

## Deployment options

### Web

 * There is no additional dependency when UMDs are running on Web (AMD/RequireJS) - use them as you would use strict AMD modules. Naturally your UMDs can work seamlessly with other 'native' AMD modules.

 * If you want to optimize your modules and bundle them using r.js or almond etc, you can [convert your modules to AMD](https://github.com/anodynos/uRequire#convert-to-pure-amd-or-pure-node) instead of UMD, and pass them through r.js as you would normally do. uRequire will do this in one step in future versions (>=0.3).

### nodejs

 * On nodejs, as long as 'urequire' package is installed via npm, your UMD generated modules can be used as-is by any UMD or native nodejs module via the bare `require('')` call. Although your source modules were written in AMD and perhaps use asynchronous require calls, plugins etc they work seamlessly on nodejs.

 * Additionally your ex-AMD, now UMDfied modules, can `require('module')` any *node-native module* installed via npm or residing on your file system. Its *MAD*, but RequireJS AMD modules wont let you do that (@version 2.1.1). * **Note: you have to conditionally make sure the node-natives aren't called/executing on browser; or better replace them with some client counterpart lib!** If you want to `require('')` a node-only module, that shouldn't be [added to the deps array](https://github.com/anodynos/uRequire#never-miss-a-dependency), use the `node!moduleName` pseudo-plugin, that signals node-only execution. *

 * You can use *native RequireJS loader plugins* (eg `text!mytext.txt`), through RequireJS it self. Your nodejs-looking modules can actually use RequireJS plugins.

 * Finally you can run *native AMD modules* on node (ones that aren't converted to UMD, i.e start with `define()`). If uRequire fails to load a module,
 it passes it to RequireJS/node it self - this needs more testing, but it does the trick for now.

### Convert to pure AMD or pure node:

You can issue a `urequire AMD ...` or `urequire nodejs` instead of the standard/recommended UMD (Universal Module Definition) format.

Do note:

  * *AMD*-only is safe & 100% equivalent for web execution with its UMD counterpart. Its also what you need to [r.js optimize](http://requirejs.org/docs/optimization.html).

  * *nodejs*-only is not recommended. It converts modules with a *pure* **nodejs** template, without uRequire's special [`require`](https://github.com/anodynos/uRequire/blob/master/source/code/NodeRequirer.coffee), thus loosing a lot of functionality:

      * Runtime translation of paths like `models/PersonModel` to `../../models/PersonModel`, depending on where it was called from.
      * Can't use the asynchronous version of `require(['dep'], function(dep){...})`
      * Can't runn of loader plugins, like `text!...` or `json!...`
      * There's no mapping of `/`, ie webRootMap etc or using the requirejs.config's `{baseUrl:"...."} or {paths:"lib":"../../lib"}`

    You 'll still get build-time translated bundleRelative paths, to their nodejs fileRelative equivalent.

    Converted modules dont have a dependency on `npm install uRequire` to run, but the whole thing is too restrictive.
    Neverthelss, if you're not using any of the above features, uRequire is a fine AMD-to-nodejs converter (but misses comments:-(, for now :-).
    For a similar even simpler conversion (no path translation), see ['nodefy'](https://github.com/millermedeiros/nodefy).


##Installation & Usage

uRequire has a command line converter that needs to be called globally:

  `npm install urequire -g`

You 'll also need a local dependency of `'urequire'` for your modules-to-become-UMD, when those are running on node, so install locally also `npm install urequire` or add to your package.json. This actually gives your UMD modules a proxy to node's native require, allowing proper [paths resolution](https://github.com/anodynos/uRequire#bundleRelative-vs-fileRelative-paths), the [asynchronous](https://github.com/anodynos/uRequire#asynchronous-require) version of require, [loader plugin execution](https://github.com/anodynos/uRequire#requirejs-loader-plugins), [mappings](https://github.com/anodynos/uRequire#mappings) and better debugging information when things go wrong.

Assuming you have your AMD/node modules in a structure like this
<pre>
src/
    Application.js
    views/
          PersonView.js
    models/
          PersonModel.js
    helpers/
          helper.js
</pre>

The src/ directory is said to be your 'bundle root', in urequire terms. It's what you would set `baseUrl` to in requirejs, if your modules were in pure AMD format. All absolute dependencies (those not starting with `./`, `../` or `/`) would be relative to this bundle root, eg 'Application' or 'views/PersonView'. Every UMD file is aware of its location in the bundle and uses it in various ways, such as resolving paths, looking for 'requirejs.config.json', resolving baseUrl/paths & webRootMap etc.

Now say your `views/PersonView.js` is

```js
define(['models/PersonModel'], function(PersonModel) {
  var helper = require('helpers/helper.js');
  //do stuff with PersonModel & helper
  return {the:'PersonViewModule'}
});
```

and similarly for the others. Note that the above is using the 'relaxed' form.

Remember that other modules in the same bundle can be authored as nodejs modules. For example  'models/PersonModel.js' can be :

```js
var helper = require('helpers/helper.js');
var data = require('datastore/data.js');
// do stuff with data & helper
module.exports = {the:'PersonModelModule'}
```

To convert your modules to uRequire UMD you 'll execute:

```
urequire UMD src -o build
```

This will place the translated UMD files into the `build` directory.
The generated files will look similar to this:

```js
  // Generated by urequire v0.0.9
  (function (root, factory) {
      if (typeof exports === 'object') {
          var nodeRequire = require('urequire').makeNodeRequire('views/PersonView.js', __dirname, '..');
          module.exports = factory(nodeRequire, nodeRequire('../models/PersonModel'));
      } else if (typeof define === 'function' && define.amd) {
          define(['require', '../models/PersonModel', '../helpers/helper.js'], factory);
      }
  })(this, function (require, PersonModel) {
      var helper = require('../helpers/helper.js');
      return {the:'PersonViewModule'};
  });
```

Your bundle files are ready to be deployed to Web/RequireJS and to node (by having 'urequire' locally installed via npm).

### CMD options
  -h, --help                     output usage information

  -V, --version                  output the version number

  -o, --outputPath <outputPath>  Output converted files onto this directory

  -f, --forceOverwriteSources    Overwrite *source* files (-o not needed & ignored). Usefull if your source is not *real source*, eg you use coffeescript

  -v, --verbose                  Print module processing information

  -n, --noExport                 Ignore all web `rootExport`s in module definitions

  -r, --webRootMap <webRootMap>  Where to map `/` when running in node. On RequireJS its http-server's root. Can be absolute or relative to bundle. Defaults to bundle.

  -s, --scanAllow                By default, ALL require('') deps appear on []. to prevent RequireJS to scan @ runtime (event if there was none on []). With --s you can allow `require('')` scan @ runtime, for source modules that have no [] deps (eg nodejs source modules)

  -a, --allNodeRequires          Pre-require all deps on node, even if they arent mapped to parameters, just like in AMD deps []. Preserves same loading order, but a possible slower starting up on node. They are cached nevertheless, so you might gain speed later.

  -C, --Continue                 Dont bail out while processing (mainly on module processing errors)


## FAQ

### What exactly is the problem with AMD running on web / node as it is ? Why not use RequireJS / amdefine on node ?

There are various problems with modules in the current era.

Yes, RequireJS [can be be used on node](http://requirejs.org/docs/node.html). Installed as a local package via npm its a large 600kb dependency, but that is not the problem.

* RequireJS on node is strict on dependencies declarations on node, just like on web execution: if you ommit declaring a dependency on the dependency array `define(['dep']...)`, it [will fail when you require('dep')](https://github.com/jrburke/requirejs/issues/467) on the body (on node it actually returns 'undefined'). Also, if you forget to list 'require' as your first dependency, you'll unleash hell: it'll work in some cases and some paths, not in others. This is all expected, due to the 'strictness' of the AMD standard. Hence, even this is not really the problem, just a caveat.

* The real problem stems from the need to load your AMD-defined modules via RequireJs special 'adapter' (loader). Taken from its documentation :

```js
var requirejs = require('requirejs');
requirejs.config({nodeRequire: require});
requirejs(['foo', 'bar'], function(foo, bar) {});
```

This works ok for *your* AMD defined modules. But if you need to use a node-native .js module, residing on your file system, r.js fails with `Error: Evaluating '/path/to/myLib.js' as module "myLib" failed with error: ReferenceError: module is not defined`. See `examples/rjs`

One may ask, *why would I need to load native nodejs modules from AMD/UMD modules that are supposed to be runnable on the web side mainly/also ?*. One simple answer is *cause you wanna share code between client & server, but also be able to inject code on either side at will*. Perhaps this issue is a single stopper for using AMD on node.

uRequire modules overcome this problem: they can require any native node module as it is, without any special treatment, adapter or conversion. Third party code can get 'required' and work as it is. You only need to use the fake-plugin notation of `require('node!./path/to/nativeNodeJsModule')`, to signal that this module should not appear on AMD dependency array & then make sure at runtime that it gets loaded only when you are at nodejs (`isNode` & `isWeb` variables are provided for this purppose). See `examples/nodeNative-requiredByABC_and_rjs` and `examples\abc\a-lib`.

* Similarly, your AMD defined modules can't be used by node-native modules as they are with requireJS. Your AMD modules start with `define`, which is unknown to the node runtime.
So your node-native requiring modules need to be changed and instead load your native AMD-modules through requirejs, which means you need to alter them. This doesn't work if they happen to be third party code, or testers or other kind of loaders. And I think its a heavy burdain by it self, even if its your own code. You should be focusing on you business logic, not how to load modules.

* Path resolution is also problematic, relative & absolute paths are causes of problems and it breaks on testers like mocha or when you want to use multiple 'bundles' in one requiring module. Check [this](https://github.com/jrburke/amdefine/issues/4) and [this](https://github.com/jrburke/requirejs/issues/450) issues.

* Copying from requirejs [docs](http://requirejs.org/docs/node.html#2) *Even though RequireJS is an asynchronous loader in the browser, the RequireJS Node adapter loads modules synchronously in the Node environment to match the default loading behavior in Node*. I think this can lead to problems, where asynch based code that is developed and tested on node runs ok, but fails miserably when it runs on web. Module systems should execute the same way on all sides, to the maximum possible extend.

Edit: This behaviour was fixed in RequireJS 2.1 ['Enforcing async require'](https://github.com/jrburke/requirejs/wiki/Upgrading-to-RequireJS-2.1). uRequire endevours to match RequireJS's functionality, following its newest version's behaviour.

* Using [amdefine](https://github.com/jrburke/amdefine/) also leaves a lot to be desired: a single line makes 'define' available on node, but where does 'require' come from ? It comes from node. Hence no bundleRelative paths and no asynch version of require. And if you use the synch/node `module = require('moduleName')`, and works on the node side, you 'll need to remember to include 'require' and 'moduleName' on the dependencies array also. Finally mixing node-requirejs and amdefine is not an option either - they aren't meant to be used together - see some [early failed attempts](https://github.com/jrburke/requirejs/issues/450)

### What does urequire 'relaxed' notation solve ?

Consider this AMD example:

```js
define(['main/dep1', 'main/helpers/dep2'], function(dep1, dep2) {
   var dep3 = require('moredeps/dep3');

   if (dep3(dep1) === 'wow'){
      require(['./dep4'], function(dep4) {
        // asynchronously do things with dep4
      });
   }

   // do stuff with dep1, dep2, dep3

   return {my:'module'}
});
```

This looks like a valid AMD module, but it would *not* work as AMD/RequireJS module. (it does only if its 'relaxed' form is massaged by uRequire and converted to UMD).

The line `var dep3 = require('moredeps/dep3');` would fail on web/requirejs for two reasons:

a) `require` is not listed as a dependency

and

b) even if you had `require` listed, your app would halt because `moredeps/dep3` is not listed as a dependency, i.e it is a [missing require dep](https://github.com/anodynos/uRequire#never miss a dependency).


Further more, even if you fixed those two errors, if you were to run this in *node*, you would be missing `define`. You could turn to `amdefine`, but that would also fail on `require('moredeps/dep3')` because of the absolute/bunldeRelative path. Remember, with amdefine, require('') comes from node - i.e. no bundleRelative paths, no plugins, no asynchronous calls. For the last reason, the 2nd require would also fail, since this asynchronous format is not supported on node's require. For more or less the same reasons, you would have issues if you used requirejs on node.

With UMD produced by uRequire, you would overcome these issues instantly: your module is ready to run on both node and web as it is.

### Can I mix *fileRelative* and *bundleRelative*, or will I get into problems ?

One core aim of uRequire is to allow you to use either on both environments. At build time everything is translated to what actually works (fileRelative), so you dont need to worry. And at runtime, if you come to evaluate to an absolute path (bundleRelative), it will still work (by default) on web and by (transparent) translation on nodejs.

#### Mix them up
Actually mixing the two path formats, is IMHO probably a good practice:

  * When you require a *local* dependency, eg. something closely related to your current module, you could use the fileRelative notation. For instance if you are writing `utils/string/camelCase` and you need `utils/string/replaceAllChars`, then its logical, obvious and self explanatory to just use `./replaceAllChars`.

  * When you require something more *distant*, you should use the absolute path to show exactly what you mean. For instance, `../../../string/replace` reveals little of where is what you need, where you coming from and whether it is the right path. And if you ever refactor it'll be a nightmare to change 'em all. Its actually more clear to use `utils/string/replace` in these cases.

### Hey, I like it so far, but I think its another format on its own. After all, it violates standards, it's a frankestein, its a tool that if you adopt, u have a dependency on it!

Not really.

* If you stick to the standard AMD or nodeJs, you're fine on that side. And if you avoid using any DOM/node features (like node's `require.resolve()`) you get 'running on the other side' for free.

* If you use AMD 'relaxed' form, but want to go back to AMD strict for web's sake: At any time (with > v0.3) you can convert your 'relaxed' uRequire source to strict AMD and get done with it. You 'll never need uRequire again (but I'm sure you 'll come back!). And your code will still be able to convert to UMD so it runs on node.

* If you use nodeJs with and have used the asynch `require([], function(){})`, and you want to go back to strict node format, you "ll have some more work to do converting to `var a = require('a')` and changing its asynch nature, but it shouldn't be so hard (the other way around is much harder).

### Hey, I 've heard browserify *makes node-style require() work in the browser with a server-side build step*. Is it similar to this? Is it better ?

Similar? Better? not really. And at the same time, YES, absolutely!

U can think of this project as a distant counterpart to [browserify](https://github.com/substack/node-browserify), though it takes a completely different approach and has different results:

 - uRequire is better/different, because it works both sides: web-to-node and node-to-web.
 Also on web side, its using AMD, which seems to be the standard way to define web modules [AMD](https://github.com/amdjs). The [claim is](http://requirejs.org/docs/whyamd.html) that AMD is the proper browser-optimized module system. But that should not prevent you, from running that same code on nodejs, as it is.

 - But NO, its not 'better' than browserify. It doesn't attempt to bring any of node's packages and functionality to the web (like browserify does). Only your modules are the issue here: your code that SHOULD run on both sides, WILL run. U must use non-dom, non-node stuff of course, if you want your code to work both ways.

 #### But hey, can I combine them ?
 See below, the FAQuestions with one answser.

### Have you got any examples ?

All examples are in [uRequireExamples](https://github.com/anodynos/uRequireExamples), the testbed for uRequire & modularity problems/solutions.

#### amd-utils tutorial

Check a more real world one, UMDfying the amd-utils by [millermedeiros](https://github.com/millermedeiros)

0) Grab a copy of [amd-utils](http://millermedeiros.github.com/amd-utils/)

1) Install urequire in it `npm install urequire` (and globally if u haven't already)

2) Run `urequire UMD src -o UMD/src`, which converts the main library files to uRequire UMD.

3) Copy tests/lib and test/SpecRunner.html into UMD/tests

4) Run `urequire UMD tests/spec -o UMD/tests/spec`, which converts the spec files to uRequire UMD.

At this point *uRequire will complain that* 'Bundle-looking dependencies not found in bundle' - this is expected: indeed,
if you run it with `jasmine-node UMD/tests/spec --matchall` it will fail to find `src\array\append` etc because it has no idea where `src\` is.

So just add a `requirejs.config.json` on the specs bundle root (tests/spec), copying from the requirejs config used in SpecRunner.html:

```js
{"paths": {"src" : "../../src"}}
```
(dont forget to convert to real JSON - ie enclose keys/values with double quotes)

Now if you run jasmine again, almost all tests will run ok, with only two exceptions:

  a) Few specs requring some DOM related objects like `window` and `document`, which is well expected.

  b) Two specs in `spec\array\spec-forEach.js` titled 'should support arrays with missing items' fails because uglifyJs that is used by uRequire to parse & regenerate the code is changing the mis_ing-items array `[ 5, ,7 ]` to `[ 5, undefined, 7 ]` and there is nothing I can do about it! Perhaps uglify2 or another parser would solve this...

Apart from those, the UMDfied amd-utils library now runs and tests on both browser and nodejs.

###Hey, I dont want to convert my modules. Is it still usefull ?
Of course. It will run some sanity checks on your module bundles.
More examples & functionality, watch this space!

###FAQuestions with one answer.

####Can I safely mix uRequire UMD modules with other 'native' modules, at each runtime (i.e on node and the browser) ?
####Can I substitute a module at runtime with a different version, at each runtime ? i.e. can I have a different 'data/storage', at each runtime ?
####Can I combine it with Browserify and make more awesome stuff ?
####Will it do `this` or work with `that` in the future ?
####Does it rock ?
 Well, of course. In theory. <= v.0.1 is only a proof of concept.
 I 've tried some configurations, but only a fraction of what's out there of course!
 They should all work, somehow, sometime.
 If they dont, they will.
 See the History / Roadmap below to get a better idea of future directions.
 I am eager to know and realize more usage patterns to incorporate.
 So, go play, try it out and make sure you let me know what issues & successes you're having!

#####BTW, uRequire requires U:
```coffeescript
require ['volunteers', 'skills/solidjs/CoffeeScript', 'awesomeness'], (volunteers, jscs, awe)->
    modules = (require 'knowledgeOf/RequireJS/NodeJs/module/systems').preferable()
    (uTeam.members or= []).push v.welcome() for v in volunteers when (v jscs, modules) is awe;

  uRequire:'v1.0'
```

## Does `u` in uRequire stems from UMD ?
No, from Universal. Require.

## History / Roadmap:
###v0.1.0 - Alpha/preview release
* A preview of what uRequire aims to become. Quite usefull as it is, but still a non-stable/Alpha.

###v0.1.5 - Alpha/preview release
* Working towards refactoring & loaderPlugins - node!, text! & json! are worked out (preliminary)

###v0.1.7
* support for native RequireJS plugins & native RequireJS modules on node, through RequireJS.
* Refactoring continues, documentation starting (NodeRequirer)

###v0.1.8
* Refactoring & documentation continues (on `NodeRequirer`)

###**v0.2.x (Latest/current version)**
* Refactoring, code documentation, more spec tests, plan for incorporating future functionality.

* (0.1.6) - You can use native [RequireJS loader plugins](https://github.com/anodynos/uRequire#requirejs-loader-plugins) (like text! and json!) - (alpha support).

* Mimics the behaviour of RequireJS's `require(['dep1', 'dep2'], function(){})` where if dependencies 'dep1' & 'dep2' are already loaded (i.e cached), the factory function is called synchronously (immediatelly). **UPDATE: this feature is muted, to match RequireJS 2.1.x behaviour that fixed this.**

* (0.2.2) [AMD only & nodejs only module tranlation](https://github.com/anodynos/uRequire#convert-to-pure-amd-or-pure-node), through respective (buildin) templates:
  Just give `urequire AMD ....`  or `urequire nodejs ....` instead..

* (0.2.6) [`rootExports`](https://github.com/anodynos/uRequire#simplified-rootExports) can now be an array & [`noConflict()`](https://github.com/anodynos/uRequire#no-worries-noconflict) is declarativelyoffered.

###v0.3 - 0.5

* AMD template along with *r.js* optimization of your relaxed notation modules. Also it will come with the ability to change from fileRelative to bundleRelative and vise versa. This will allow you for instance to automatically translate modules you already have written using the restrictive fileRelative paths '../../../models/PersonModel', to the more natural bundleRelative 'models/PersonModel'. From then on, you 'll use the build as your new source. You'll then simply uRequire 'em into UMD/AMD when you run/deploy. Caveat : uglify 1.x must be swaped with a better .js parser / one that at least supports comments.

* Sanity checks of existence of external libraries, webRootMap, baseUrl, paths etc.

* Watch option / build only changed files / cache bundle/module info, all aiming to quickest translation.

* Grunt plugin ? (still works fine as it is with shell:command)

###v0.6 - v0.8

* Configuration file `urequire.json` that will contain all the information regarding your bundle: your default uRequire settings (eg your nodejs webRootMap mapping, -scanPrevent), and the most important of all: a `relaxed` config used on both the web side and nodejs that knows facts like which are the bundle modules or that `underscore` is a 'global' (i.e it needs a requireJS/web {paths: {'underscore': '/libs/lodash.js'}} and on node its ususally an `npm install underscore`, but it could also use the same requireJs `paths`.) etc.

* Additionally, check jamjs & yeoman, cause they deal with deps management as well... piggyback?

* Investigate loading modules asynchronously from HTTP on node, just like RequireJS/browser (with caching).

###Other issues / unversioned
* Allow *some* functions of both AMD and Require to be used on the other side, eg nodejs's `require.resolve()`

* Build to an almond-like format where everything in bundled.

* Convert from strict-AMD to relaxed-AMD :-)

##Acknoweledgments.
**Buidling on the shoulders of giants is always better.** 
uRequire would not have been possible without :

  * [RequireJS](https://github.com/jrburke/requirejs), the most popular web-side module system to date, by [JR Burke](https://gist.github.com/jrburke)

  * [UMDjs](https://github.com/umdjs/umd), provide boilerplates that bridge gaps, by [JR Burke](https://gist.github.com/jrburke) and [others](https://github.com/umdjs/umd#umd-universal-module-definition)

  * [UglifyJS](https://github.com/mishoo/UglifyJS), easily parses/re-generates JavaScript, by [Mihai Bazon](https://github.com/mishoo/)

  * [CoffeeScript](http://coffeescript.org/), makes javascript authoring a true joy, by [Jeremy Ashkenas](https://github.com/jashkenas) et [all](http://github.com/jashkenas/coffee-script/contributors)

  * [Grunt](https://github.com/gruntjs), the best declarative javascript build system, by [Ben Alman](https://github.com/cowboy)

  * [Commander](https://github.com/visionmedia/commander.js), easily parses cmd arguments, by [TJ Holowaychuk](https://github.com/visionmedia)

  * [Codo](https://github.com/netzpirat/codo), for documenting Coffeescript code, by [Michael Kessler](https://github.com/netzpirat)

and all others - see package.json dependencies.

### Further information & articles

* [Writing Modular JavaScript With AMD, CommonJS & ES Harmony](http://addyosmani.com/writing-modular-js/) by [Addy Osmani](http://twitter.com/addyosmani)
* [Patterns For Large-Scale JavaScript Application Architecture](http://addyosmani.com/largescalejavascript/) by [Addy Osmani](http://twitter.com/addyosmani)



*PS: Excuse my typo errors, I need to get a solid dictionary for ** WebStorm ** (which otherwise rocks!)*

# License
The MIT License

Copyright (c) 2012 Agelos Pikoulas (agelos.pikoulas@gmail.com)

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
