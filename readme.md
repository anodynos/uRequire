#uRequire
Write *modular code* once and seamlesly execute/test on both **browser** & **node.js** via a UMD template, without quirks.

On node it employs both build and on-the-fly path resolution, mapping absolute-to-relative, webRoot, and RequireJs's baseUrl & paths.


#Aims
* **Enable the *simplest possible*, relaxed authoring of modular js code with a unified dependencies structure for modules.**

When no browser or node specifics are present, the same code should run & test on both browser and nodejs.

The common denominator to define modules is [AMD](https://github.com/amdjs) and the test bed is [requireJS](http://requirejs.org);
That's because AMD is the proper browser-optimized modular system out there. But that should not prevent you from the ability to run the same code on nodejs. Think of this project as the counterpart or opposite to [browserify] (https://github.com/substack/node-browserify).


* **Accomodate both `define()` and `require()` to work the same way in both browser & node.**
Specifically, the browser AMD-style `require([..], function(..){})` should work on node, just as it does on the browser: asyncrhonously.
And vise versa, the node-style `var a = require('a')` should also work on browser (at least seemingly) synchronously.


* **Allow modules to have a 'module-bundle root' as a reference point**, where module dependencies are relative to, with the same sementics on both runtimes.
This currently works in browser/AMD/requireJS (using baseUrl), but on node dependencies are "relative to requiring file" which is a source of misconceptions on
modularization it self, in regards to development.

* Check your dependencies are valid at build time
  -globals, webRoots, notExists in bundle, etc

Ultimatelly uRequire wishes to promote:
* A standardized definition of dependencies for cross-platform modular code using AMD.
* Proper code reuse, without one-side locking.
* More natural changing / refactoring of code.
Eg moving a dependency A in a different folders should not affect the dependencies referenced in A.
Only other affected files should be updated for my new position. Editors and IDES can easily detect this and update it.
* Bring browser best practices (that appear to be AMD/requirejs), closer to nodejs.


#Installation & Basic Usage
* uRequire has a command line converter that is called globally:

  `npm install uRequire -g`

You 'll also need a local dependency for your modules-to-become-UMD project.
It uses a makeNodeRequire function that is a proxy to node's require, allowing resolution of paths mappings & the asynchronous version of require.

So assuming you have your AMD modules like this
<pre>

src/
    Application.js
    views/
          PersonView.js
    models/
          PersonModel.js
</pre>

and say `views/PersonView.js` is
```js
    define(['models/PersonModel'], function(PersonModel) {
      //do stuff
      return {the:'module'}
    }
```

and similarly for the others, you 'll execute
```
uRequire UMD src -o build
```
and uRequire will place the generated files into the `build` directory. The generated files will look like this
```js
    (function (root, factory) {
        if (typeof exports === 'object') {
            var nodeRequire = require('uRequire').makeNodeRequire('views', __dirname);
            module.exports = factory(nodeRequire);
        } else if (typeof define === 'function' && define.amd) {
            define(['require'], factory);
        }
    })(this, function (require) {
        return {the:module};
    });
```


#Notes
 When running on node, if you're referencing libs outside the package,
 either via webRootMap, a relative path like ../../somepackage/somelib or some requireJs config settings, make sure you have uRequire installed there as well.
 Every UMD file is aware of its bundle location. This information in various ways, such as resolving paths, looking for requirejs config, resolving webRoot etc

#FAQ:
##Can I mix relative and absolute paths, or will I get into problems ?
The aim of uRequire is to allow you to use either on both environments. Since everything is translated at build time to what actually works so you dont need to care. Actually mixing the two is probably a good practice:
  * When you require a *local* dependency, eg. something closely related to your curent module, you can use the relative notation. For instance if you are writing `utils/string/camelCase` and you need `utils/string/replaceAllChars`, then its logical to just use `./replaceAllChars` and its self explanatory.
  * When you require something more *distant*, you should use the absolute path to show exactly what you mean. For instance, `../../../string/replace` reveals little of what you need, where you coming from and whether it is the right path. And if you ever refactor it'll be a nightmare to change 'em all. Its actually more clear to use `utils/string/replace` in this case.


Roadmap:
 v0.1
    - AMD template rewrite, with ability to change from relative-to-bundle relative and vise versa.
    - Options to checks existence of external libraries, webRootMap etc.






#The problems with AMD

##Web AMD problems
- With relative paths, you end up loading your files many many times: once everytime you reference to one under a different pathname. So if you're calling |depdir2/dep2 from module's root | you would use `.depdir2/dep2` but later you might use it from a nested dir, so you would use `../../depdir2/dep2`. You've just loaded you library twice, under a different id.
  That holds true at least before the optimization build which bundles them all in one.

- RequireJS almond DOES not work with non-amd scripts that expose only the global (like underscore), because there is no shim config for exports.

## Node AMD Problems

## - no `define()` on requirejs

One would expect `define()` to somehow work on requirejs nodejs

```coffee
var requirejs = require("requirejs");
var define = requirejs.define;

define ["models/PersonModel"], (PersonModel)->
```

##amdefine ->
***I can't use require() and/or requirejs***

  The only allowed line of amdefine is

  ```js
  if (typeof define !== 'function') {var define = require('amdefine')(module);
  ```

  so, where does my `require()` come from ? If I call require(), it will certainly come from node.
  But when I run it on the web, I wont have access to node's synchronous require format `module = require('moduleName')`

  How do we solve this ?
  A naive thought would be to enrich my amdefine code.
  Since requirejs on node does give me define(),
  and amdefine does give me require / requirejs,
  I will run them both!

  ```js
  if (typeof define !== 'function') {
  //  var define = require('amdefine')(module);
    var requirejs = require("requirejs");
    requirejs.config({
      baseUrl: __dirname + "/../main/",
      nodeRequire: require
    });
  };
  ```

  Wow, this way I can also set my baseUrl to wherever I want, so I 'll have more flexibility right ?
  Now i can really code once run everywhere, right ? ** WRONG **

  ***You can't test what you have made on the fly.***
  Say you write up a small file and you want to test it as it is, without a big build.
  Even in its simplest case, where you have no dependencies, your file starts with a module definition like this:


  ```js
   define([], function() { return { foo:bar} }
   ```

   The question is "How do I just run this", with just a bit of code at the end of it to see what it does ?
   I want to call my no dependencies function on the spot. This is of course only usefull during development,
   where you dont wanna build, just run.

   A naive thought would be  `myAwesomeModule = require('awesomeModule')` but its problematic.

#Web AMD problems
 ## require('lib') not scanned, if dependency array is not empty (or not exists).
 # (Different on node/amdefine : even if [] is present i.e `define [], (require)->, require is undefined!)
 ## 'dir1/lib1` is different than `./dir1/lib1` (with dir1 on bundle root/baseUrl)
 ## see https://github.com/jrburke/requirejs/issues/467

 amd-utils 'some' case : doesn't like reduntant/unused parameters, when require is 1st param



https://github.com/jrburke/requirejs/issues/450
https://github.com/jrburke/amdefine/issues/4


@jrburke, thank you for your response.

I believe having to tweak mocha or any other framework just to make it work with AMD, completely breaks the reusability and modularity concerns that modules come to solve. Using modules should be as unobstrusive as possible, like using an import in other languages. In current state, this is not the case.

For this reason, after having tried all possible valid solutions (I hope), I have drafted out a simple *source converter* that I believe will be useful and I would like to hear your thoughts.
I know you are against build tools as a mandatory requirement for AMD, but still 'building' tools (grunt, make, ant) are inevitable for serious development. And most of all, I dont really care what the automated tools will do, but only the code I have to write (and later look at). Even still, my converter will be an optional step :-)

The main aim is to write once (with AMD only syntax) and run on both browser & node, using some UMD template, without any other hassle.

The core usage pattern will be:

- Use only the standard AMD syntax `define(['dep1', 'dep2'], function(dep1, dep2) {})`.
  Inside your module, if you want to conditionally load `myhugeOptionalModule` you again use the anyschronous AMD require syntax only `require(['dep1', 'dep2'], function(dep1, dep2) {})`.

- Use 'package' relative notation for dependencies `mydepdir1/mydepdir2/myModule' which is more natural (esp for us x-java devs). Optionally you will still be able to use the 'file-relative' (if it starts with ./ or ../)

- The converter extracts the dependencies & parameters of your code, and rewrites you body (factory method) around a UMD template, injecting `require` as the first param. When running on node, this injected `require` will be aware of the relative path of your file inside your 'package' and will be resolving/loading your dependencies (asynchronously, to match browser behaviour) before calling your factory method.

- And finally, yes, **node's require will be locally hidden from you** - you can only use AMDs require format, which is effectivelly a wrapper for nodes' native require.

This way, your code is guaranteed(!) to run everywhere, but written consistently with the exact same authoring semantics (provided async requires are also used on the node side), and testers like mocha wouldn't even know the difference. Think of it as the oposite of browserify: it takes AMD-browser modules and wraps them around UMD so they can run on node.

Its a trivial thought really, but can help many people quickly use AMD over UMD without even bothering with it. Ultimatelly I hope it wil raise AMD adoption :-)

My first tests seem to work and I should have a first alpha-preview version hopefully by the end this week for you to reflect on, but I'd appreciate you first thoughts on it.

________________________________

**UMD could be a solution**, but it has one great obstacle and a ugly caveat.

- The caveat is that it looks really awful, its way TOO much boilerplate for anyone's real usage. People are cursing it, and I can see why. I see people using it only as an after step in some automated build that is added around your code to modularize amd amdify your *deployment* (like this screencast [http://www.watchmecode.net/amd-builds-with-grunt]), rather than what you use to modularize your code structure during *development*.

Coming from the java territory, I want to be able to write every logically different code chunk on a different file, without so much boilerplate. And trust me, I 've done my boilerplate with java :-)

- The obstacle with is that when running on browser/AMD you can use 'package-relative' dependencies `views/generic/PersonView', but when running on node you can only use file-relative `../../../PersonView` which is awful. What does that last ../../PersonView point at? it blows my mind!

**Using requirejs on node** confuses me : where is `define` ?

In overall, How can I write once, without having any other concern, and have it run seemlessly on both brwoser and node (which is what most people use anyway). It's such a shame that so much work has been done with AMD (& node), but they still can't really work together. See more on this issue [https://github.com/jrburke/requirejs/issues/450#issuecomment-8465160]

So, after realizing the void here, I am in the middle of writing a simple converter, where you write AMD modules and it translates them to UMD that run eveywhere, taking care of the details.. I will update when v0.0.1 is done :-)


  # something usefull - see http://stackoverflow.com/questions/9507606/when-to-use-require-and-when-to-use-define

#amd-utils tutorial
1) Run `uRequire UMD src -o UMD/src`
2) Copy tests/lib and test/spec runner into UMD/tests
2) Run `uRequire UMD tests/spec -o UMD/tests/spec`
  It will complain about missing bundle-looking libraries
  Indeed, if you run it with `jasmine-node tests\spec --matchall` it will fail to find
  `src\array\append` etc because it has no idea where src\ is.

  So add requireJSConfig.json, copying from the require js config used in SpecRunner.html
  (dont forget to convert to JSON - ie enclose keys/values with double quotes)
  {
    "paths" : {
        "src" : "../../src"
    }
  }

  Now if you run it again, almost all tests will run ok, with only two excpetions :
    a) Those requring some DOM related objects like `window` and `document`, which is expected.
    b) A spec for `forEach` titled 'should support arrays with missing items' because uglifyJs that
      is used by uRequire is changing array `[ 5, , 7 ]` to `[ 5, undefined, 7 ]` and there is nothing I can currently do about it!

  Apart from that, your library now runs and tests in UMD