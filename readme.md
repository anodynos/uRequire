# uRequire v0.6.15

[![Build Status](https://travis-ci.org/anodynos/uRequire.png)](https://travis-ci.org/anodynos/uRequire)
[![Up to date Status](https://david-dm.org/anodynos/urequire.png)](https://david-dm.org/anodynos/urequire.png)

## The JavaScript Universal Module & Resource Converter

Convert AMD & commonjs modules to commonjs, AMD, UMD or single `.js` and run/test on nodejs, Web/AMD or Web/Script.

All documentation is moved to the [wiki](https://github.com/anodynos/uRequire/wiki) and http://urequire.org

# Support uRequire

* `@goto('http://github.com/anodynos/urequire').then -> @star()` with your love :-)

* [![Flattr donate button](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=anodynos&url=http%3A%2F%2Furequire.org "Donate to uRequire using Flattr")
[![PayPayl donate button](https://www.paypalobjects.com/en_AU/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=XZGDQKS96XGP8&lc=GR&item_name=uRequire%2eorg&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donate_SM%2egif%3aNonHosted "Donate to uRequire using Paypal")

# Some Introduction

## Why use *modules* like **AMD** or **Common/JS** ?

Write **modular, maintainable & reusable code**:

  * Clearly stated dependencies & imports.

  * Employ **standards** and **trusted tools**.

  * Have a **dynamic code loading** mechanism.

  * The damnation of **one huge .js file** or **concatenation** must end!

##### Are U still concatenating .js files ?

## But javascript developers hate modules!

[Many](http://tomdale.net/2012/01/amd-is-not-the-answer) [woes](http://blog.nexua.org/requirejs-hell-amd-really-is-not-the-answer) on Module formats & *incombatibilities*:

 * [Verbose syntax](https://medium.com/what-i-learned-building/5a31feb15e2), boilerplate ceremony & intricacies (especially AMD)

 * **execution environment** (AMD *only* for Web, CommonJs *only* for nodejs)

 * **capabilities, [dependency/path resolutions](http://urequire.org/flexible-path-conventions), [plugins](http://urequire.org/requirejs-loader-plugins), [semantics](http://urequire.org/synchronous-require)** etc are a mess

 * [UMD](https://github.com/umdjs/umd/) is a **semi-standard boilerplate**, far from usable.

 ##### U need a bridge to enjoy the richness of modules.

`require('more').than(this);`

## Why use uRequire ?

* Convert from **any** format to **any** other:
  * from **AMD** and **CommonJS**

  * to [AMD](http://urequire.org/amd-template), [CommonJS](http://urequire.org/nodejs-template), [UMD](http://urequire.org/amd-template), [Combined for nodejs-Web/AMD-Web/Script](http://urequire.org/combined-template)

  * ~~ES6/Harmony~~ *when standard/parsers mature*

* Forget [the woes](http://urequire.org/synchronous-require#never-miss-a-dependency) or Module formats incompatiblities

* Eliminate boilerplate & *write modular Javascript code once, run everywhere* : [**Web/Script**, **Web/AMD**, **nodejs**](http://urequire.org/deployment)

* A [Universal Module Format](http://urequire.org/universal-module-format) with the **power, goodies & standards** from all.

* Convert to a single `combined.js`, that [runs everywhere & is super optimized](http://urequire.org/combined-template)

##### If U `require`d it or `define`d it, **uRequire will find it**.

Simplest [Module Authoring](http://urequire.org/features#module-authoring)

```js
define(['dep1','dep2'], function(dep1,dep2) {
  // do stuff with dep1, dep2
  return {my:'module'}
});

// or
var dep1 = require('dep1'),
    dep2 = require('dep2');
// do stuff with dep1, dep2
module.exports = {my: 'module'}

// or both, in a relaxed, non-weird way
define(['dep1','dep2'], function(dep1,dep2) {
  var dep3JSON = require('json!dep3AsJSON');
  // do stuff with dep1, dep2, dep3JSON
  return {my:'module'}
});
```

## A [Modules & Dependencies aware](http://urequire.org/masterdefaultsconfig.coffee#bundle.dependencies) builder.

[Exporting modules](http://urequire.org/exporting-modules) to `window`/`global` variables (like `window._`, `window.$` etc), demystified and with no boilerplate.

Want [`noConflict()`](http://urequire.org/generated-noconflict-functionality), baked in? Its a simple declaration away.

```js
// file `uberscore.js` - export it to root (`window`) as `_B`
({ urequire: { rootExports: '_B', noConflict: true }});
module.exports = {...}
```
The [same in a config](http://urequire.org/masterdefaultsconfig.coffee#bundle.dependencies.exports.root) is

```
dependencies: { exports: { root: { 'uberscore': '_B' }}}`
```

How about [exporting to your bundle](http://urequire.org/masterdefaultsconfig.coffee#bundle.dependencies.exports.bundle) only?

```
// export/inject `_` in (all) bundle's modules
dependencies: { exports: { bundle: { 'lodash': '_' }}}
```

Want to replace **deps with mocks** or **alternative versions** ?

[Inject](http://urequire.org/masterdefaultsconfig.coffee#bundle.dependencies.exports.bundle), [replace](http://urequire.org/MasterDefaultsConfig.coffee#bundle.dependencies.replace) or even [delete](http://urequire.org/resourceconverters.coffee#inject-replace-dependencies) dependencies with a simple declaration or a callback:

```
// underscore is dead, long live _
dependencies: { replace: { lodash: 'underscore'}}

// with code
function(modyle){ modyle.replaceDeps('models/PersonModel', 'mock/models/PersonModelMock'); }
```


## A versatile [in-memory Resource Conversion](http://urequire.org/resourceconverters.coffee#resourceconverter-workflow-principles)

[Manipulate Module code](http://urequire.org/resourceconverters.coffee#manipulating-modules) while building:

* **inject, replace or delete** [code fragments or AST nodes](http://urequire.org/resourceconverters.coffee#manipulate-replace-ast-code) or dependencies with one liners.

```js
// delete matching code of code skeleton
function(m){ m.replaceCode('if (debug){}') }

// traverse matching nodes, replace or delete em
function(m){ m.replaceCode('console.log()', function(nodeAST){return nodeOrStringOrUndefined}) }
```

Perform **any code manipulation** - eg remove debug code, inject initializations etc

* [Merge repeating statements](http://urequire.org/resourceconverters.coffee#bundlemergedcode): keep DRY, save space & speed when [`combined`](http://urequire.org/combined-template) in a single `.js`

```coffee
# unify / merge repeating statements
bundle: commonCode: 'var expect = chai.expect;'
```

* Initialize [custom module code](http://urequire.org/resourceconverters.coffee#beforeBody), for common tasks:

```
function(m) { m.beforeBody = 'var l = new _B.Logger("Logger" + m.dstFilename);' }
```

A [ResourceConverter](http://urequire.org/resourceconverters.coffee#what-is-a-resourceconverter) for our `.coco` files (included along with coffeescript, LiveScript, iced-coffee-script)

```coffee
[ '$coco', [ '**/*.co'], ((r)-> require('coco').compile r.converted), '.js']
```

## A spartan Module builder & config

This `'uberscore'` config (coffeescript) will:

  * [read files from `source`](http://urequire.org/masterdefaultsconfig.coffee#bundle.path), [write to `build`](http://urequire.org/(masterdefaultsconfig.coffee#build.dstPath)

  * [filter some `filez`](http://urequire.org/masterdefaultsconfig.coffee#bundle.filez)

  * convert each module in `path` to [UMD (default)](http://urequire.org/UMD-template)

  * [copy](http://urequire.org/masterdefaultsconfig.coffee#bundle.copy) all other files there

  * [Allow `runtimeInfo`](http://urequire.org/masterdefaultsconfig.coffee#build.runtimeInfo) (eg `__isNode`, `__isAMD`) selectively

  * [inject](http://urequire.org/masterdefaultsconfig.coffee#bundle.dependencies.exports.bundle) `lodash` dep in each module as `_`

  * [export a global](http://urequire.org/masterdefaultsconfig.coffee#bundle.dependencies.exports.root) `window._B` with a `noConflict()`

  * [inject](http://urequire.org/resourceconverters.coffee#inject-any-string-before-after-body) `'var VERSION =...'` before body of `uberscore.js`

  * [minify](http://urequire.org/masterdefaultsconfig.coffee#build.optimize) each module with UglifyJs2's defaults

  * [add a banner](http://urequire.org/masterdefaultsconfig.coffee#build.template) (after UMD template & minification)

  * [clean](http://urequire.org/masterdefaultsconfig.coffee#build.clean) directory at `dstPath` (before writing anything)

  * [watch for changes](http://urequire.org/masterdefaultsconfig.coffee#build.watch), convert only [what's really changed](http://urequire.org/resourceconverters.coffee#watching-module-changes)


```coffee
# Config as a `Gruntfile.coffee` task
# Can be a .coffee, .js, .json, .yml & more
uberscore:
  path: 'source'
  dstPath: 'build'
  filez: ['**/*', (f)-> f isnt 'badfile']
  copy: [/./]
  runtimeInfo: ['!**/*', 'Logger.js']
  dependencies: exports:
    bundle: 'lodash':  '_'
    root: 'uberscore': '_B'
  resources: [
    ['+inject:VERSION', ['uberscore.js'],
     (module)-> module.beforeBody =
                  "var VERSION = '0.0.15';"]
  ]
  template: banner: "// uBerscore v0.0.15"
  optimize: 'uglify2'
  clean: true
  watch: true
```

## Parent configs ? [Lets derive!](http://urequire.org/types-and-derive#deriving-behaviors)

The `'distribute'` config will:

  * derive (i.e [deep inherit & modify](http://urequire.org/types-and-derive#deeper-behavior)) the above

  * filter some [more filez](http://urequire.org/types-and-derive#arrayizeconcat)

  * change template to ['combined'](http://urequire.org/combined-template)

  * output to a different filename

  * pass [more options to uglify2 / r.js](http://urequire.org/masterdefaultsconfig.coffee#build.optimize)

[See more examples](https://github.com/anodynos/uBerscore/blob/master/Gruntfile.coffee)

Lets derive some children

```coffee
distribute:
  derive: ['uberscore']
  filez: ['!', /useRegExpsAsFileSpecs/]
  template: 'combined'
  dstPath: 'build/uberscore-combined.js'
  optimize: uglify2: {more: uglify2: options}
```

Continue reading at http://urequire.org

# License

The MIT License

Copyright (c) 2013 Agelos Pikoulas (agelos.pikoulas@gmail.com)

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
