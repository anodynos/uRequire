These tags are used in the description of config or ResourceConverters starting with @:

### @optional

All keys are optional, unless otherwise specified with **@mandatory**.

@optional tag specifies why this key is not only optional but perhaps useless in some cases.

### @mandatory

Few keys are @mandatory, and here's why.

### @stability: (1-5)
A [nodejs-like stability](http://nodejs.org/api/documentation.html#documentation_stability_index) of the setting. If not stated, its assumed to be a "3 - Stable".

### @default

Rarely used, cause default is evident in the code that follows the key description, unless otherwise specified.

### @todo:

This file is [documentation & code](#note:-literate-coffescript). `@todo`s should be part of any code and a great chance to highlight future directions!

Also watch out for **NOT IMPLEMENTED** features - uRequire is still v0.x!

### @alias

Usually DEPRECATED (but still supported) keys.

### @note

Any other note that requires attention

### @see

Similar / interesting stuff.

## Deriving loosely typed values: **@derive** & **@type** tags

### @derive

Describes the **derive behavior**, i.e how values are derived (i.e inherited) to a *child config*, from other *parent configs*.

@see the [*standard* derive behaviors here](Types-and-derive#Derive-behaviors)

### @type

Describes the expected type of the value.

@see the [standard types here](Types-and-derive#Types)