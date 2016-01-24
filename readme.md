# uRequire v0.7.0-beta.25

## Beta release note

_Docs / wiki / http://uRequire.org mainly are **Work In Progress** (in transition from v0.6.x) - but everything should work except you'll need `npm install urequire-cli -g` & `npm install urequire` locally (if you are using the CLI urequire instead of the the recommended [grunt-urequire](https://github.com/aearly/grunt-urequire)). Check **uRequire's [master config / docs](https://github.com/anodynos/uRequire/blob/master/source/code/config/MasterDefaultsConfig.coffee.md)** for up to date usage._

[![Build Status](https://travis-ci.org/anodynos/uRequire.svg?branch=master)](https://travis-ci.org/anodynos/uRequire)
[![Up to date Status](https://david-dm.org/anodynos/urequire.png)](https://david-dm.org/anodynos/urequire)

## The JavaScript Universal Module & Resource Converter (and automagical builder, test runner and more)...

All documentation is moved to the [wiki](https://github.com/anodynos/uRequire/wiki) and http://urequire.org

## What's uRequire ?

For a quick taste of how much uRequire rocks, with minimal grunting or gulping, check [urequire-example-helloworld](https://github.com/anodynos/urequire-example-helloworld). With just ~30 lines of DRY & declarative uRequire config, this example shows off the automagical :

* transparent compilation from **coffee-script**, **coco**, **LiveScript** etc to **javascript**. They are all javascript, right ?

* conversion from **AMD** or **CommonJs** (or a combination of both) to **UMD** or **combined** (`<script>`, `AMD` & `nodejs` compatible) javascript.

* importing of dependencies (i.e `dependencies: imports: lodash: ['_']`) *and* keys out of them (`resources: ['import-keys', {'chai': 'expect'} ] ]`) to all modules in the bundle (held by some variable name). The latter uses the `urequire-rc-import-keys` ResourceConverter *plugin*.

* injection of a `var VERSION = 'x.x.x';` in *main module's body*, where `'x.x.x'` comes from `package.json` (using the `urequire-rc-inject-version` ResourceConverter *plugin*).

* gereration of a standard *banner*, with info from `package.json`.

* declarative exporting of main module on `window.myModule` (with `noConflict()` baked in).

* minification with **uglify2's** passing some rudimentary options.

* discovery of dependencies's paths using the info already in **bower** or nodejs's **npm**.

* generated tests that run on nodejs & **phantomjs** (browser) via **mocha** (& **chai**), both as **Web/AMD** & **Web/Script**. It even generates the required HTML, with all module's paths, **requirejs**'s configs & shims or `<script ...>` tags etc.

* watch facility with rapid rebuilds, since it compiles *only files that have really changed* and also runs the tests only if a) there were changes and b) with no compilation errors.

* clean of destination files / folders before each build.

* deriving (i.e like *inheritance* in OO) of configs.

* passing r.js options

* a cross *module systems development*, *cross runtimes deployment* & automagical continuous testing.

* and *last but not least*: The *elimination* of (the need for) **grunt plugins**. There's isnt any hint of `grunt-xxx` for `watch`, `coffee-script`, `browserify`, `uglify`, `mocha`, `concat`, `phantomjs`, `banner`, `clean` etc). This is great news cause cause **grunt plugins have many disadvantages** :

     * repeating the same source & dest paths & files all over again (when you should keep it DRY)

     * you have to learn the intricacies & syntax of each plugin

     * making sure they run in the right order & hope they produce the right result

     * producing many intermediate temp files

     * building everything with each change etc

     * writing stuff for things that should be automagical ;-)

Who's gulping ?

# Support uRequire

* `@goto('http://github.com/anodynos/urequire').then -> @star()` with your love :-)

* [![Flattr donate button](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=anodynos&url=http%3A%2F%2Furequire.org "Donate to uRequire using Flattr")
[![PayPayl donate button](https://www.paypalobjects.com/en_AU/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=XZGDQKS96XGP8&lc=GR&item_name=uRequire%2eorg&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donate_SM%2egif%3aNonHosted "Donate to uRequire using Paypal")

* **Get me hired** me in a cool nodejs-loving team in **London, UK** (as of March 2015 ;-)

# License

The MIT License

Copyright (c) 2013-2015 Agelos Pikoulas (agelos.pikoulas@gmail.com)

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
