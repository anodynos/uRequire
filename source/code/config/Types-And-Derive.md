
# Types

A description of valid reoccurring type(s) and their behavior.

For somewhat complex types, there is a flexibility of values you can use as there are shortcuts, [*for example*](#shortcut-depsvars-types).

## `filespecs`

Filename specifications (or simply filenames), expressed in either:

  * `String` in *gruntjs*'s expand minimatch format (eg `'**/*.coffee'`) and its exclusion cousin (eg `'!**/DRAFT*.*'`)

  * `RegExp`s that match filenames (eg `/./`) again with a

  ```
  [..., '!', /regexp/, ...]
  ```

  exclusion pattern.

  * A `function(filename){}` callback, returning true if filename is to be matched. Consistently it can have a negation/exclusion flag before it:
  ```
  [..., '!', function(f){ return f === 'excludeMe.js' }, ...]
  ```.

  @note use a `true` (i.e matched) as the result preceded by '!' for exclusion, **rather the common trap than of a false result for your *excluded matches* (cause all your non-excluded with match with true, which is probably not what you want!)**.

  * @todo: NOT IMPLEMENTED: An `Array<String|RegExp|Function|Array>, recursive, i.e
   ```
   [ ..., ['AllowMe*.*', '!', function(f){ return f === 'excludeMe.js' }, [.., []], ...], ...]
   ```

@example

```coffee
bundle: {
  filez: [
    '**/recources/*.*'
    '!dummy.json'
    /.*\.someExtension$/i
    '!', /.*\.excludeExtension$/i
    (filename)-> filename is 'includedFile.ext'
  ]
}
```
## `depsVars`

Defines one or more **dependencies** (i.e **Modules** or other **Resource**s), that each is bound to one or more identifiers (i.e variable or property names).

Its used in many places (like injecting deps in [`bundle.dependencies.exports.bundle`](#bundle.dependencies.exports.bundle)) and [is often useful](#Binding-deps-and-vars-is-required).

### Formal `depsVars` type

The formal type, (i.e. where each depVars value ends up as, no matter how its declared as), is an Object like this:

 ```
{
  'dep1': ['dep1VarName1', 'dep1VarName2'],
  ...
  'underscore': ['_'],
  'Backbone': ['backbone'],
  ....
  'depN': ['depNVarName1', ...]
}
 ```

### Shortcut `depsVars` types

The `depsVars` type has *shortcuts*:

 * Array: eg `['arrayDep1', 'arrayDep2', ..., 'arrayDepn']`, with one or more deps.

 * String: eg `'soloDep'`, of just one dep.

 * or even deps with one identifier `{ 'lodash': '_', xxx: [] }`

*Shortcut types* are converted to the [*formal type*](#formal-depsVars) when deriving, using the [dependenciesBindings](types-and-derive#dependenciesbindings) derive - the above will end up as

  * `{arrayDep1:[], arrayDep2:[], ..arrayDepn:[]}`

  * `{soloDep: []}`

  * `{ 'lodash': ['_'], xxx: [] }`

### Binding deps and vars is required

* *when injecting dependencies*, eg exporting declarativelly through [`bundle.dependencies.exports.bundle`](#bundle.dependencies.exports.bundle) eg 'lodash', bind '_' as the var to access the module in the code.

* **when converting** through ['combined' template](combined-template). Local dependencies (like `'underscore'` or `'jquery'`) are not part of the `combined.js` file.
  At run time, when running on the module-less **Web** side as a `combined.js` via a simple `<script/>`, the uRequire generated code *will only know how to grab* the dependency using the binding `$` from the *global* object (i.e `window`).

### Inferred binding idenifiers

If a dependency (key) ends up with no identifier (var name), for example `{ myDep:[], ...}`, then the identifiers are automagically inferred from:

   * the code it self, i.e when you have `define ['lodash'], (_)->` or `_ = require 'lodash'` somewhere in your code, it binds `'lodash'` dependency with `_` identifier.

   * or using any other relevant part of the config like [`bundle.dependencies.depsVars`](#bundle.dependencies.depsVars), [`bundle.dependencies._knownDepsVars`](#bundle.dependencies._knownDepsVars) etc.

## `booleanOrFilespecs`

This type controls if a key applies to *all, none or some filenames/module paths*. Its either:

  * boolean (true/false), so all or none files/modules get the setting.

  * A [filespecs](#filespecs). Important @note: if the config setting (eg `globalWindow`, `useStrict` etc) is dealing with modules (usually), a module [bundleRelative](Flexible-Path-Conventions#bundlerelative-vs-filerelative-paths) *path* is expected **without the filename extension**, i.e `['models/PersonModel', ...]` without `'.js'`. If dealing with general file, you have to match filename **and** extension.

Unless otherwise specified, `booleanOrFilespecs` uses derive [`arraysConcatOrOverwrite`](#arraysConcatOrOverwrite).


_____



# Deriving Behaviors

A config can **inherit** the values of a parent config, in other words it can be **derived** from it. Its similar notion of a children or subclass *overrides* a parent class in classical OO (but better).

Ultimately all configs are derived (inherit) from `MasterDefaultsConfig` (this file) which holds all default *parent* values.

## Deeper Behavior

Derivation is more flexible that simple OO inheritance or `_.extend` :

  * It inherits deeply all keys, i.e `{a: {b1:11, b2:12}}` --derive--> `{a: {b1:1, b3:3}}` gives `{a: {b1:11, b2:12, b3:3}}`, something like or `__.deepExtend`

  * At each key of the deep derivation, there might be a **different behavior** for how to *derive* (or *blend*) with the parent's values - eg [see arrayizeConcat in @derive](types-and-derive#arrayizeConcat).

## `arrayizeConcat`

Both *parent* (source) and *child* (destination) values are turned into an Array first (they are [_B.arrayize](https://github.com/anodynos/uBerscore/blob/master/source/code/collections/array/arrayize.co)-d).

Then the items on child configs are pushed *after* the ones they inherit (parents, higher up in hieracrchy).

For example consider key `bundle.filez` (that has the **arrayizeConcat derive behavior**).

* *parent* config `bundle:filez: ['**/*', '!DRAFT/*.*']`

* *child* config `bundle:filez: ['!vendor/*.*]`

* *derived* config: `bundle: filez: ['**/*', '!DRAFT/*.*', '!vendor/*.*]`.

Use your imagination for the possiblities.

### type

The type for both child and parent values, are either `Array<Anything>` or `Anything` but Array (which is [_B.arrayize](https://github.com/anodynos/uBerscore/blob/master/source/code/collections/array/arrayize.co)-d first).

### Reset Parent

To reset the inherited parent array (always in your new child *destination* array), use `[null]` as the 1st item of your child array. For example

* parent config `bundle:filez: ['**/*', '!DRAFT/*.*']`

* child config `bundle:filez: [[null], 'vendorOnly/*.*]`

* blended config: `bundle: filez: ['vendorOnly/*.*]`.

@todo: use a function callback on child, that receives parent value (& a clone:-) and returns the resulted blended array.

## `arrayizeUniqueConcat`

Just like [*arrayizeConcat*](types-and-derive#arrayizeConcat), but only === unique items are pushed to the result array.

## `arraysConcatOrOverwrite`

If **both** *child* and *parent* values are already an Array, then the items on child (derived) configs are pushed *after* the ones they inherit (like [`arrayizeConcat`](arrayizeConcat)).

Otherwise, the child value (even if its an array) overwrites the value it inherits.

For example consider key `build.globalWindow` (that has the **arraysConcatOrOverwrite derive behavior**).

* parent config `build: globalWindow: ['**/*']`

* child config `build: globalWindow: true`

* blended config: `build: globalWindow: true`

or similarly

* parent config `build: globalWindow: true`

* child config `build: globalWindow:  ['**/*']`

* blended config: `build: globalWindow: ['**/*']`

@note [reset parent](#reset-parent) works like arrayizeConcat's, so you can produce a new Array, even when deriving from an Array.


## `dependenciesBindings`

This derivation refers to [`depsVars` type](types-and-derive#depsVars).

Each dependency name (the key) of child configs is added to the resulted object, if not already there.

Its identifiers / variable names are then [arrayizeUniqueConcat](types-and-derive#arrayizeUniqueConcat)-ed onto the array.

For example with a parent value:
```
{
  myDep1: ['myDep1Var1', 'myDep1Var2']
}
```

and a child value:

```js
{
  myDep1: ['myDep1Var1', 'myMissingDep1Var3']

  # identifier is a String, not an Array
  myDep2: 'myDep2Var'
}
```

the resulted derived object will be

```js
{
  # only missing 'myMissingDep1Var3' identifier is appended to array
  myDep1: ['myDep1Var1', 'myDep1Var2', 'myMissingDep1Var3']

  # identifier is arrayized
  myDep2: ['myDep2Var']
}
```