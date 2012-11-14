#uRequire v0.2.0

**Write simple *modular code* once, run everywhere** using [UMD](https://github.com/umdjs/umd) based module translation that (currently) targets web [(AMD/requireJS)]
(http://requirejs.org/) & nodejs/commonjs module systems.

The drive behind urequire is **if you have sensibly defined it, it should certainly find it**.

uRequire allows you to write boilerplace free *modular code* once and seamlesly execute & test it on both **browser** & **nodejs**. With a simple build step,
uRequire converts your modules to UMD using static code analysis, a UMD template and build/runtime path resolution.

Your source can be written either in the 'strict' AMD format `define([], function(){})` or the nodejs/commonjs `require('dep')`, or a more *relaxed* or even hybrid version! urequire converts it to suitable format that works everywhere.

You don't need to surround you code with any UMD-like boilerplate or worry about path translation, cause urequire does it for you.

##Ultimate Aims
 * Remove the *mud* from **UMD**, which is currently the *only true option* for cross-platform modular js development. No longer you need to add UMD around your non-modular code to AMDdify the *deployment*. You should be able to use modules to structure your code during *development*.

 * Provide the *simplest possible*, relaxed authoring of modular js code with a unified dependencies structure for modules. When no browser/DOM or node specifics are present, the same source code should run & test on both browser and nodejs.

 * Promote and/or become a standardized 'relaxed' definition of dependencies for cross-platform modular code using the 'good parts' from AMD and nodejs.

 * Empower code reuse, without one-side locking. Provide for a more natural structring and refactoring of code.

 * Bring browser-side best practices (that appear to be AMD/requirejs), closer to nodejs. And vise versa.

### In the long future
 * Will convert to and from any JavaScript module system (that makes sense :-)

## Features
 * Fixes some of the most common pains, problems and omittions from your AMD modules.

 * Uses a 'familiar' standardized [UMD template](https://github.com/umdjs/umd/blob/master/returnExports.js) with a global export being [optional](https://github.com/umdjs/umd/blob/master/returnExportsGlobal.js) using a declarative [`rootExport`](https://github.com/anodynos/urequire#things-you-can-do-with-the-relaxed-urequire-notation).

 * **Accomodates both `define()` and `require()` to work the same way in both browser & node.**
 Specifically, the browser AMD-style `require([..], function(..){})` works on node, just as it does on the browser: asynchronously. And vise versa, the node-style `var a = require('a')` also works on browser (at least seemingly) synchronously.

 * **Allows modules to have a 'bundle-root' as a reference point**, where module dependencies are required with an absolute path (eg `models\PersonModel`, aka bundleRelative), with the same semantics on both runtimes. This works in browser with plain AMD/requireJS using `baseUrl`. But on node, dependencies are relative to requiring file (aka fileRelative) which I feel is a source of misconceptions on modularization it self, in regards to development. There are cases that both are usefull though, see the FAQ.

 * Run **native node modules** on node(!), from within your AMD modules^. Its MAD, but RequireJS AMD modules wont let you do that (@version 2.1.1).  ^(just make sure the natives aren't executing on browser :-) or better, they are replaced with some other client lib!

 * Run *native RequireJS loader plugins*, through RequireJS it self.

 * Run *native AMD modules* on node, ones that has not been converted to UMD - alpha support, through requireJS it self.

 * Checks your dependencies are valid at build time. It identifies dependencies within bundle boundaries and whether those exist. It also identifies and works with globals, webRootMap, externals, requireJS baseUrl/paths etc (and in future versions will check these exist before deploying).

 * Requires no additional dependency when running on web. Requires only a small ~15k runtime when running on node. As long as 'urequire' package is installed via npm, your urequire generated modules can be used as-is by any native node module via the bare require('') call, although they were written in AMD and perhaps use asynchronous require calls. Similarly your UMD modules can `require('module')` any node-native module installed via npm or residing on your file system (the 'node!module' pseudo plugin nca be used to signal node-only inclusion).

##Module authoring
With urequire, your modules can be either written in AMD:

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

define(['dep1', 'dep2'], function(dep1, dep2) {
   var dep3 = require('dep3');
   // do stuff with dep1, dep2, dep3
   return {my:'module'}
});
```
 **relaxed means you dont need to be strict to either standard, but also it would NOT work as a plain AMD/node module without urequire conversion.*

urequire strives to guarantee that your modules are correctly translated and execute on both target environments, even though the easier, less verbose *relaxed* format is used.

The idiosyncrasies and limitations of module formats are waived, so you can focus on what is important: you modular code that can be expresed in the easiest sensible way possible.

For instance you can use both the syntax of sync & asych require, mix absolute/bundleRelative with fileRelative paths, forget about requiring `require` or `module`/`exports` and just be sure that your code will execute on both runtimes in a consistent way.

###Things you can do with the relaxed urequire notation

* Use bundleRelative ('depdir/dep') or fileRelative ('../../dep') paths interchangably.

* Use the simple `require('depdir/dep')` anywhere you like, without any worries. They are added to your AMD dependencies array if needed at build time, so they do work on both node and web.

* Use the asynchronous *array* version of `require(['depdir/dep'], function(dep){...})`, anywhere you like, web or node. Note that this asynchronous require is the only way to conditionally load 'myHugeButOptionalModule' on the web side. On node it always runs asynchronously just like it does in RequireJS/AMD. *(Note thought that RequireJS is not consistent in its asynchronous call of require(['dep1', 'dep2'], fn): if all your dependencies ['dep1', 'dep2'] have already been loaded/cached before, the call to fn is actually synchronous. urequire aims to match this exact behaviour in subsequent versions)*.

* You dont need to require 'require' on AMD, or use a param 'module', 'exports' when you use the nodejs notation. Its done for you.

* You can declarativelly export a global variable from your UMD module on the web side: just include an object literal on the top of your source module file like this `({urequire: {rootExport: 'myRootVariable'}});`. More declarative options will follow :-)

* You can map webRoot `/` to a directory of your nodejs environment (--webRootMap option). The directory can be relative to bundle (paths starting with a `.`) or an absolute file system path (eg `f:/jslibs`)

* You can use the requirejs config `baseUrl` and `paths` on node (only those)- just place a file named `requirejs.config.json` in your bundle root directory, with content like {"paths": {"myLib" : "../../myLib"}}. Very usefull for 'importing' bundles, eg running specs against 'myLib' bundle using mocha, jasmine-node etc.

* (0.1.3) - You can use the `.js` extension, as it is allowed by nodejs. Because of the [different semantics in RequireJS](http://requirejs.org/docs/api.html#jsfiles), its fixed(i.e stripped) for you if needed (i.e it exists on your bundle dir).

* (0.1.6) - You can use native RequireJS plugins (like text! and json!) - (alpha support - see FAQ)

* NEW (0.1.7) - You can require a native AMD module, one that has not been converted to UMD. VERY unstable, still has issues with  relative paths and not tested enough.

* More will follow :-)

Should you choose to adhere to the 100% [standard syntax of AMD](https://github.com/amdjs) or [nodejs](http://nodejs.org/api/modules.html), so that your pre-build *source* code is also valid/executable too, that's fine. urequire will at least be as good as a) converting them to the 'other' runnable version and b) perform sanity and dependency checks on your source before deploying.

##Installation & Usage
urequire has a command line converter that needs to be called globally:

  `npm install urequire -g`

You 'll also need a local dependency of `urequire` for your modules-to-become-UMD, when those are running on node, so install locally also `npm install urequire`. This actually gives your UMD modules a proxy to node's native require, allowing proper paths resolution & the asynchronous version of require.

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

The src/ directory is said to be your 'bundle root', in urequire terms. It's what you would set `baseUrl` to in requirejs, if your modules were in pure AMD format. All absolute dependencies (those not starting with `./`, `../` or `/`) would be relative to this bundle root, eg 'Application' or 'views/PersonView'. Every UMD file is aware of its location in the bundle and uses it in various ways, such as resolving paths, looking for 'requirejs.config.json', resolving baseUrl/paths & webRoot etc.

Now say your `views/PersonView.js` is

```js
define(['models/PersonModel'], function(PersonModel) {
  var helper = require('helpers/helper.js');
  //do stuff with PersonModel & helper
  return {the:'PersonViewModule'}
});
```

and similarly for the others. Note that the above is using the 'relaxed' form - see the FAQ for more details.

Remember that other modules in the same bundle can be written as nodejs modules. For example  'models/PersonModel.js' can be :

```js
var helper = require('helpers/helper.js');
var data = require('datastore/data.js');
// do stuff with data & helper
module.exports = {the:'PersonModelModule'}
```

To convert your modules to urequire UMD you 'll execute:

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

  -s, --scanPrevent              All require('') deps appear on [], even if they wouldn't need to, preventing RequireJS scan @ runtime.

  -a, --allNodeRequires          Pre-require all deps on node, even if they arent mapped to parameters, just like in AMD deps []. Preserves same loading order, but a possible slower starting up on node.

### Notes
* Your requires must use a string, eg `require('myModule')`. Requires that evaluate at runtime, eg `require(myVar + 'module')` can't be possibly be evaluated at parse time, and thus are *unsafe*.
* Your module `define(..)` must be a top level in your .js (not nested inside some other code).
* Everything outside `define` is simply ignored.
* Only one module per file is expected - i.e only the first `define` per file is parsed.
* There are some limitations due to the parser/code generator used ([uglifyjs](https://github.com/mishoo/UglifyJS)) : a) Comments are ignored and b) some [unsafe transformations](https://github.com/mishoo/UglifyJS#unsafe-transformations)

##FAQ
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

[Edit: This behaviour was fixed in RequireJS 2.1 'Enforcing async require' ](https://github.com/jrburke/requirejs/wiki/Upgrading-to-RequireJS-2.1)
uRequire will endevour to match RequireJS's functionality, following newest versions.

* Using [amdefine](https://github.com/jrburke/amdefine/) also leaves a lot to be desired: a single line makes 'define' available on node, but where does 'require' come from ? It comes from node. Hence no bundleRelative paths and no asynch version of require. And if you use the synch/node `module = require('moduleName')`, and works on the node side, you 'll need to remember to include 'require' and 'moduleName' on the dependencies array also. Finally mixing node-requirejs and amdefine is not an option either - they aren't meant to be used together - see some [early failed attempts](https://github.com/jrburke/requirejs/issues/450)

###What does urequire 'relaxed' notation solve ?

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

This looks like a valid AMD module, but it would *not* work as AMD/RequireJS module. (it does only if its 'relaxed' form is massaged by urequire and converted to UMD).

The line `var dep3 = require('moredeps/dep3');` would fail on web/requirejs for two reasons:
a) `require` is not listed as a dependency and
b) even if you had `require` listed, your app would halt because  `moredeps/dep3` is not listed as a dependency. And since you have even one other dependency on the deps array, requireJS doesn't scan your `require` calls for dependencies to preload at runtime (see this [issue](https://github.com/jrburke/requirejs/issues/467)).

Further more, even if you fixed those two errors, if you were to run this in *node*, you would be missing `define`. You could turn to `amdefine`, but that would also fail on `require('moredeps/dep3')` because of the absolute/bunldeRelative path. Remember, with amdefine, require('') comes from node.
For this same reason, the 2nd require would also fail, since this asyncrhonous format is not supported on node. For more or less the same reasons, you would have issues if you used requirejs on node.

With UMD produced by urequire, you would overcome these issues instantly: your module is ready to run on both node and web as it is.

###Can I mix fileRelative and bundleRelative/absolute paths, or will I get into problems ?
One core aim of urequire is to allow you to use either on both environments. At build time everything is translated to what actually works (fileRelative), so you dont need to worry. And at runtime, if you come to evaluate to an absolute path, that will still work by default on web and by (transparent) translation on node.

Actually mixing the two path formats, is IMHO probably a good practice:

  * When you require a *local* dependency, eg. something closely related to your current module, you could use the fileRelative notation. For instance if you are writing `utils/string/camelCase` and you need `utils/string/replaceAllChars`, then its logical to just use `./replaceAllChars`. Its obvious and self explanatory.

  * When you require something more *distant*, you should use the absolute path to show exactly what you mean. For instance, `../../../string/replace` reveals little of where is what you need, where you coming from and whether it is the right path. And if you ever refactor it'll be a nightmare to change 'em all. Its actually more clear to use `utils/string/replace` in this case.

###Hey, I like it so far, but I think its another format on its own. After all, it violates standards, it's a frankestein, its a tool that if you adopt,
u have a dependency on it!

Not really.

* If you stick to the standard AMD or nodeJs, you're fine on that side. And if you avoid using any DOM/node features (like node's `require.resolve()`) you get 'running on the other side' for free.

* If you use AMD 'relaxed' form, but want to go back to AMD strict for web's sake: At any time (with > v0.3) you can convert your 'relaxed' uRequire source to strict AMD and get done with it. You 'll never need uRequire again (but I'm sure you 'll come back!). And your code will still be able to convert to UMD so it runs on node.

* If you use nodeJs with and have used the asynch `require([], function(){})`, and you want to go back to strict node format, you "ll have some more work to do converting to `var a = require('a')` and changing its asynch nature, but it should'nt be so hard (the other way around is much harder).

###Hey, I 've heard browserify *makes node-style require() work in the browser with a server-side build step*. Is it similar to this? Is it better ?

Similar? Better? not really. And at the same time, YES, absolutelly!

U can think of this project as a distant counterpart to [browserify](https://github.com/substack/node-browserify), though it takes a completelly different approach and has completelly different results:

 - uRequire is better/different, because it works both sides: web-to-node and node-to-web.
 Also on web side, its using AMD, which seems to be the standard way to define web modules [AMD](https://github.com/amdjs). The [claim is](http://requirejs.org/docs/whyamd.html) that AMD is the proper browser-optimized module system. But that should not prevent you, from running that same code on nodejs, as it is.

 - But NO, its not 'better' than browserify. It doesn't attempt to bring any of node's packages and functionality to the web (like browserify does). Only your modules are the issue here: your code that SHOULD run on both sides, WILL run. U must use non-dom, non-node stuff of course, if you want your code to work both ways.

 #### But hey, can I combine them ?
 See below, the FAQuestions with one answser.

###Have you got any examples ?
* Look at some dummy examples, in either `source/` (coffeescript) or `build/` javascript.

You can compile all coffeescript 'source/' to javascript in 'build/' with `grunt shell:coffeeAll` if you prefer to ({lookAt:'javascript'});

They are dummy, very dummy, just to illustrate the various options: `abc/` is simple, `deps/` is a bit more involved. They have some dummy specs and HTML usage examples.

You can compile, uRequire, test and run examples with `grunt shell:examples`

See all build options and shortcuts in gruntfile.coffee. If you don't use grunt, you should! Its the best js build tool out there!

####amd-utils tutorial
Check a more real world one, UMDfying the amd-utils by [millermedeiros](https://github.com/millermedeiros)

0) Grab a copy of [amd-utils](http://millermedeiros.github.com/amd-utils/)

1) Install urequire in it `npm install urequire` (and globally if u haven't already)

2) Run `urequire UMD src -o UMD/src`, which converts the main library files to uRequire UMD.

3) Copy tests/lib and test/SpecRunner.html into UMD/tests

4) Run `urequire UMD tests/spec -o UMD/tests/spec`, which converts the spec files to uRequire UMD.

At this point *uRequire will complain that* 'Bundle-looking dependencies not found in bundle' - this is expected: indeed, if you run it with `jasmine-node UMD\tests\spec --matchall` it will fail to find `src\array\append` etc because it has no idea where `src\` is.

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

###Do RequireJS [loader plugins](http://requirejs.org/docs/api.html#plugins) work with uRequire ?
Yes! It's currently being done and its considered a priority.

As of v0.1.6 you can use *native* requirejs modules (that make sense in node?) just like any other module.
uRequire uses RequireJS for node to actually load the plugin and let it do the actual loading work.

You can just put them on your `bundleRoot` and use them right away:
eg. to use `"text!myText.txt"` you 'll need to copy [`text.js`](https://github.com/requirejs/text/blob/master/text.js) on your bundleRoot, or put it in a folder relative to bundleRoot and note it on `requirejs.config.json` - see `examples/abc`.

So far I 've only tried a few plugins (text, json), but most should work...

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

###v0.1.8 - *CURRENT*
* Refactoring & documentation continues (on `NodeRequirer`)

###v0.2
* Refactoring, code documentation, more spec tests, plan for incorporating future functionality.

* Use requireJS built in or 3rd-party plugins (eg. for `text!myTextFile.txt), either through mimicking (easier) or loading the 3rd party plugin it self (challenging & error prone)

* Mimics the behaviour of RequireJS's `require(['dep1', 'dep2'], function(){})` where if dependencies 'dep1' & 'dep2' are already loaded (i.e cached), the factory function is called synchronously (immediatelly).

###v0.3 - 0.5
* AMD template rewrite, so you can r.js optimize you relaxed notation modules. Also it will come with the ability to change from fileRelative to bundleRelative and vise versa. This will allow you for instance to automatically translate modules you already have written using the restrictive fileRelative paths '../../../models/PersonModel', to the more natural bundleRelative 'models/PersonModel'. From then on, you 'll use the build as your new source. You'll then simply uRequire 'em into UMD/AMD when you run/deploy. Caveat : uglify 1.x must be swaped with a better .js parser / one that at least supports comments.

* Sanity checks of existence of external libraries, webRootMap, baseUrl, paths etc.

* Watch option / build only changed files / cache bundle/module info, all aiming to quickest translation.

* Grunt plugin ? (still works fine as it is with shell:command)

###v0.6 - v0.8
* Configuration file `urequire.json` that will contain all the information regarding your bundle: your default uRequire settings (eg your nodejs webRoot mapping, -scanPrevent),
and the most important of all: a `relaxed` config used on both the web side and nodejs that knows facts like which are the bundle modules or that `underscore` is a 'global' (i.e it needs a requireJS/web {paths: {'underscore': '/libs/lodash.js'}} and on node its ususally an `npm install underscore`, but it could also use the same requireJs `paths`.) etc. More info to follow, watch this space.

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

*PS: Excuse my typo errors, I need to get a solid dictionary for WebStorm (which otherwise rocks!)*

#License
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