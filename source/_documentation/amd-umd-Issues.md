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


