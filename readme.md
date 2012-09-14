https://github.com/jrburke/requirejs/issues/450
https://github.com/jrburke/amdefine/issues/4

Requirements & aims
    - Allow the simplest authoring of code in one trully unified structure, that when no other dependencies occur
will be able to run on both browser and
    - Allow package namespacing to have a 'module root' as a fererence point,
    where module dependencies are relative to. This is required to have the exact sementics on all runtimes.
    Currently node dependencies are dealt with "relative to me" which is a source of misconceptions on modularization it self.

    This will enable the
      - easiest and more natural definition of dependencies
      - changing / refactoring of code. Eg moving a dependency A in a different folders
        should not affect the dependencies referenced in A. Only other affected files should be updated for my new position.
        Editors and IDES can easily detect this and update it.
    - Bring the best practices, that appear to be close to requirejs, on both the browser and nodejs.


#Web problems
- With relative paths, you end up loading your files many many times: once everytime you reference to one under a different pathname. So if you're calling |depdir2/dep2 from module's root | you would use `.depdir2/dep2` but later you might use it from a nested dir, so you would use `../../depdir2/dep2`. You've just loaded you library twice, under a different id.
  That holds true at least before the optimization build which bundles them all in one.

- RequireJS almond DOES not work with non-amd scripts that expose only the global (like underscore), because there is no shim config for exports.




#Node Problems
- no define() on requirejs



## requirejs
***`define()` doent work like this on nodejs***

```js
var requirejs = require("requirejs");
var define = requirejs.define;


define ["uGetScore"], (_G)->
```

tested with ver 2.0.6

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


