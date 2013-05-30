########### THIS FILLE IS IMAGINERY & UNSTABLE AND MOST FEATURES ARE NO IMPLEMENTED YET! ##############

# options:
#   *  return config as object of module.exports / nodejs
#   *  if on node, write to a .json or .js file
#   *  return as UMD/AMD/nodejs module otherwise

#fs =  require 'fs'
_= require 'lodash'
#_B = require 'uberscore'

#rJSON = (file)-> JSON.parse fs.readFileSync file, 'utf-8'

module.exports =

uRequireConfig = # Command line options overide these.

  ###

  All bundle related information is nested in the keys bellow

  Note: user configs (especially simple ones) can safelly ommit 'bundle' hash (as well as 'build' below)
  and put keys belonging ot it directly on the 'root' of their object.

  ###
  bundle:

    ###
    Name of the bundle, eg 'MyLibrary'

    @optional

    `name` its self can be derived from:
      - if using grunt, it defaults to the multi-task @target (eg {urequire: 'MyBundlename': {bundle : {}, build:{} }}

      @todo:
      - --outputPath,
        - filename part, if 'combined' is used eg if its 'abcProject/abc.js', then 'abc'
        - folder name, if other template is used eg 'build/abcProject' gives 'abcProject'

    @note: `name` & is the (1st) default for 'main'

    ###
    name: undefined

    ###
    The "main" / "index" module file of your bundle, used only when 'combined' template is used.

    @optional

    * Used as 'name' / 'include' on RequireJS build.js.
      It should be the 'entry' point module of your bundle, where all dependencies are `require`'d.
      r.js recursivelly adds them to the 'combined' optimized file.

    * It is also used to as the initiation `require` on your combined bundle.
      It is the module just kicks off the app and/or requires all your other library modules.

    * Defaults to 'name', 'index', 'main' etc, the first one that is found in uModules.
    ###
    main: undefined

    #
    # If ommited, it is implied by config's position
    #
    # @example './source/code'
    path: undefined


    # All your files in you bundle are specified here.
    #
    # Each file is considered to be either:
    # * BundleFile

    # * Resource - any textual resource that we want to convert to something else: eg .coffee->.js, or .less or .css
    #
    # * Module - A Resource that is also a Module whose Dependencies we monitor and converted through some template.
    # how these are matched, @see bundle: resources
    #
    # @type
    #   filename specifications (or simply filenames), that within contains *all* the files within your bundle.
    #   Expressed in either grunt's expand minimatch format (and its negative cousin), or sRegExp`s
    #
    # @default [/./], ie. all non-module files are copied
    #
    # @example bundle: {filez: ['**/recources/*.*', '!dummy.json', /\.someExtension$/i ]}
    #
    # @derive: when you derive, all your source items (derived objects) are
    #          appended to the ones higher up @todo: doc it
    filez: ['**/*.*']

    # (binary) copy of all non-resource bundle files to outputPath - just a convenience

    # @type filez specs - see filez above
    # filename specifications (or simply filenames), considered as part of your bundle
    # that are copied to outputPath ONLY if not matched as resources/modules.
    #
    # @example bundle: {copy: ['**/images/*.gif', '!dummy.json', /\.(txt|md)$/i ]}
    #
    #
    # @default [], ie. no non-module files are copied - U can use /./ for all
    #
    # @derive when you derive, all your source items are ...@todo: doc it
    copy: []

    #todo : doc it - the most important!
    resources: [

      { # the 'proper' way of declaring a resource (converter)
        name: 'Javascript'

        # minimatch string (ala grunt's 'file' expand) or a RegExp
        filez: [ '**/*.js', /.*\.(javascript)$/i ]

        convert: (source, filename)-> source # javascript needs no compilation - just return source as is

        dstFilename: (filename)->             # convert .js | .javascript to .js
          (require '../paths/upath').changeExt filename, 'js'
      }

      [ # the alternative (& easier) way of declaring a Converter
        'Coffeescript'                    # name at pos 0

        [ '**/*.coffee', /.*\.(coffee\.md|litcoffee)$/i] # filez at pos 1

        (source, srcFilename)->              # convert function at pos 2
          (require 'coffee-script').compile source, bare:true

        (srcFilename)->                      # dstFilename function at pos 3
          ext = srcFilename.replace /.*\.(coffee\.md|litcoffee|coffee)$/, "$1" # retrieve matched extension, eg 'coffee.md'
          srcFilename.replace (new RegExp ext+'$'), 'js'                        # replace it and teturn new filename
      ]

      [ 'LiveScript', [ '**/*.ls']
        (source)-> (require 'LiveScript').compile source, bare:true
        (srcFilename)-> srcFilename.replace /(.*)\.ls$/, '$1.js' ]

    ]


    ###
    Where to map `/` when running in node. On RequireJS its http-server's root.

    Can be absolute or relative to bundle. Defaults to bundle.
    @example "/var/www" or "/../../fakeWebRoot"
    ###
    webRootMap: '.'

    # Anytihing related to dependenecies is listed here.
    dependencies:

      ###
      Each (global) dependency has one or more variables it is exported as, eg `jquery: ["$", "jQuery"]`

      They can be infered from the code of course (AMD only for now), but it good to list them here also.

      They are used to 'fetch' the global var at runtime, eg, when `combined:'almond'` is used.

      In case they are missing from modules (i.e u use the 'nodejs' module format only),
      and aren't here either, 'almond' build will fail.

      Also you can add a different var name that should be globally looked up.
      ###
      depsVars: {}

      # Some known depsVars, have them as backup!
      # todo: provide some 'common ones' that are 'strandard'
      _knownDepsVars:
        chai: 'chai'
        mocha: 'mocha'
        lodash: "_"
        underscore: "_"
        jquery: ["$", "jQuery"]
        backbone: "Backbone"
        knockout: ["ko", 'Knockout']

      exports:

        ###
        { dependency: varName(s) *}
            or
        ['dep1', 'dep2'] (with discovered or ../depsVars names)

        Each dep will be available in the *whole bundle* under varName(s) - they are global to your bundle.

        @example {
          'underscore': '_'
          'jquery': ["$", "jQuery"]
          'models/PersonModel': ['persons', 'personsModel']
        }
        ###
        bundle: {}

        ###
        Each dep listed will be available GLOBALY under varName(s) - @note: works in browser only - attaching to `window`.

        @example {
          'models/PersonModel': ['persons', 'personsModel']
        }

            is like having a `{rootExports: ['persons', 'personsModel']} in 'models/PersonModel' module.
        @todo: NOT IMPLEMENTED - use module `{rootExports: [...]} format.
        ###
        root:{}


      ###
        Dont include those dependencies on the AMD dependency array.
        Similar to 'node!dependency', but allows you to author node-compatible scripts, without uRequire conversion.
        Additionally, global deps are added to 'combined' build properly, so they can be required when running as Web/Script or nodejs
        # @todo: (8 6 3) Ammend/test for non-globals & doc it better
      ###
      noWeb: []

      ###
        Replace all right hand side dependencies (String value or []<String> values), to the left side (key)
        Eg `lodash: ['underscore']` replaces all "underscore" deps to "lodash" in the build files.
      ###
      #@todo: Not implemented
      replaceTo:
        lodash: ['underscore']




  ###

    Build : Defines the conversion, such as *where* and *what* to output

  ###

  build:

    ###
    Output converted files onto this

    * directory
    * filename (if combining)
    * function @todo: NOT IMPLEMENTED

    #todo: if ommited, requirejs.buildjs.baseUrl is used ?
    @example 'build/code'
    ###
    outputPath: undefined

    ###
    Output on the same directory as path.

    Useful if your sources are not `real sources` eg. you use coffeescript :-).
    WARNING: -f ignores --outputPath
    ###
    forceOverwriteSources: false

    ###
      String in ['UMD', 'AMD', 'nodejs', 'combined'] @todo: or an object with those as keys + more stuff!
    ###
    template: name: 'UMD'
      # one among available templates: ['UMD', 'AMD', 'nodejs', 'combined']

#      @todo:4 NOT IMPLEMENTED
#       # combined options: use a 'Universal' build, based on almond that works as standalone <script>, as AMD dependency and on node!
#       # @todo:3 implement other methods ? 'simple AMD build"
#      'combined':
#
#          # @default 'almond' - only one for now
#          method: 'almond'
#
#           Code to be injected before the factory = {....} definition - eg variables available throughout your module
#          inject: "var VERSION = '0.0.8'; //injected by grunt:concat"
#
#          ###
#          Array of dependencies (globals?) that will be inlined (instead of creating a getGlobal_xxx).
#          The default is that all bundle non-ignored
#
#          * 'true' means all (global) libs are inlined.
#          * String and []<String> are deps that will be inlined
#
#          @example depsInline: ['backbone', 'lodash'] # inline these deps
#          @example depsInline: ['backbone', 'lodash'] # inline these deps
#
#          @default undefined/false : 'All globals are replaced with a "getGlobal_#{globalName}"'
#
#          @issues: where do we find the source, eg 'lodash.js' ? We need bower integration!
#          @todo:4 NOT IMPLEMENTED
#          ###
#          depsInline: false
#
#
#          depsTo

    # Watch for changes in bundle files and reprocess/re output those changed files
    # @todo: NOT IMPLEMENTED - but it works fine with `grunt-urequire >=0.4.3` & `grunt-contrib-watch`
    watch: false

    ###
      Ignore all rootExports {& noConflict()} defined in all modules (eg `{rootExports: ['persons', 'personsModel']}` )
      (But not those of `dependencies: exports: root`, when implemented:)
    ###
    noRootExports: false

    ###
    *Web/AMD side only option* :

    By default, ALL require('') deps appear on []. to prevent RequireJS to scan @ runtime.

    With --s you can allow `require('')` scan @ runtime, for source modules that have no [] deps (i.e. nodejs source modules).
    NOTE: modules with rootExports / noConflict() always have `scanAllow: false`
    ###
    scanAllow: false

    ###
    Pre-require all deps on node, even if they arent mapped to parameters, just like in AMD deps [].
    Preserves same loading order, but a possible slower starting up. They are cached nevertheless, so you might gain speed later.
    ###
    allNodeRequires: false

    verbose: false

    debugLevel: 0

    # Dont bail out while processing, mainly on module processing errors.
    # Usefull along with -watch
    #
    # @example ignore a coffeescript compile error, just do all the other modules.
    #          Or on a 'combined' conversion when a 'global' has no 'var' association anywhere, just hold on, ignore this global and continue.
    # @todo: NOT IMPLEMENTED
    continue: false

    # @options
    #   false: no optimization (r.js build.js optimize: 'none')
    #   true: uses sane defaults to minify (passed to r.js)
    #   Object
    #   With
    #
    # @todo: PARTIALLY IMPLEMENTED - Only working for combined
    # @todo: allow all options r.js style (https://github.com/jrburke/r.js/blob/master/build/example.build.js #L138)
    optimize: false

  ###
    Other draft/ideas
    - modules to exclude their need from either AMD/UMD or combine and allow them to be either
      - accessed through global object, eg 'window'
      - loaded through RequireJs/AMD if it available
      - Loaded through nodejs require()
      - other ?
    With some smart code tranformation they can be turned into promises :-)
  ###


  ###
  Runtime settings - these are used only when executing on nodejs.
  They are written out as a "uRequire.config.js" module used at runtime on the nodejs side.
  @todo: NOT IMPLEMENTED
  ###
  #  runtime:
  #
  #    # Change the webRootMap compiled with UMD modules, and use this on instead.
  #    webRootMap: "/../../.."
  #
  #    requirejs:
  #      alwaysAsyncRequire:true # true (default) : RJS node behavior of >= 2.1.x.
  #                              # false: inconsistent RJS 2.0.x behavior (when all modules are cached, loading is synchronous)
  #      config :
  #        baseUrl: "some/other/path"
  #        paths: rJSON('requirejs.config.json').paths # or `require "json!requirejs.config.json"`
  #
  #
  #_B.deepExtend uRequireConfig, # continue extending
  #  runtime:
  #    requirejsConfig:
  #      paths:
  #        someLib: "../some/lib/path"
  # @todo: NOT IMPLEMENTED
  requirejs:
      paths:
        src: "../../src"
        text: "requirejs_plugins/text"
        json: "requirejs_plugins/json"
      # @todo: NOT IMPLEMENTED.
      baseUrl: "../code" # used at runtime

    # A subset of * RequireJS build.js ? *
    # (https://github.com/jrburke/r.js/blob/master/build/example.build.js)
    # @todo: NOT IMPLEMENTED
    "build.js":

      ###
      piggy back on this? see `appDir` in https://github.com/jrburke/r.js/blob/master/build/example.build.js
      @todo: NOT IMPLEMENTED -
      ####
      appDir: "some/path/"

      # Only when combined ?
      #
      # When build.js has 'globals' in `paths`,
      #    eg `{ jquery: '/libs/jQuery.js' }`
      #  it means that these are INLINED.
      #
      #  Otherwise, when a 'global' is missing from these paths, almond wouldn't compile, so uRequire generates a dummy reference
      # that loads the globalDependency from `window` on web or from a simple `require`.
      paths:
        lodash: "../../libs/lodash.min"

      #  uglify: {beautify: true, no_mangle: true} ,
#
#      ### BELOW HERE NOT USED - comments ###
#      baseUrl: "use uRequire.path instead" ?
#      appDir:  "use uRequire.appDir instead"