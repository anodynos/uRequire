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


