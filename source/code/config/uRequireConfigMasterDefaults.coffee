########### THIS FILLE IS IMAGINERY & UNSTABLE AND MOST FEATURES ARE NO IMPLEMENTED YET! ##############

# options:
#   *  return config as object of module.exports / nodejs
#   *  if on node, write to a .json or .js file
#   *  return as UMD/AMD/nodejs module otherwise

#_fs =  require 'fs'
_= require 'lodash'
#_B = require 'uberscore'

#rJSON = (file)-> JSON.parse _fs.readFileSync file, 'utf-8'

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

    `bundleName` its self can be derived from:
      - if using grunt, it defaults to the multi-task @target (eg {urequire: 'MyBundlename': {bundle : {}, build:{} }}

      @todo:
      - --outputPath,
        - filename part, if 'combined' is used eg if its 'abcProject/abc.js', then 'abc'
        - folder name, if other template is used eg 'build/abcProject' gives 'abcProject'

    @note: `bundleName` & is the (1st) default for 'main'

    ###
    bundleName: undefined

    ###
    The "main" / "index" module file of your bundle, used only when 'combined' template is used.

    @optional

    * Used as 'name' / 'include' on RequireJS build.js.
      It should be the 'entry' point module of your bundle, where all dependencies are `require`'d.
      r.js recursivelly adds them to the 'combined' optimized file.

    * It is also used to as the initiation `require` on your combined bundle.
      It is the module just kicks off the app and/or requires all your other library modules.

    * Defaults to 'bundleName', 'index', 'main' etc, the first one that is found in uModules.
    ###
    main: undefined

    #
    # If ommited, it is implied by config's position
    #
    # @example './source/code'
    bundlePath: undefined


    # Filespecs, of files that are not matched as resources/modules, to be copied to outputPath.
    #
    # @type filespecs - see filespecs
    #
    # @default [/./], ie. all non-module files are copied
    #
    # @example ['**/recources/*.*', '!dummy.json', /\.someExtension$/i ]
    copyNonResources: [/./]

    filespecs: ['**/*.*']

    resources: [

      { # the 'proper' way of declaring a resource (converter)
        name: 'Javascript'

        filespecs: [
            '**/*.js'              # minimatch string
            /.*\.(javascript)$/i   # or a custom RegExp
        ]

        convert: (source, filename)-> source # javascript needs no compilation - just return source as is

        convertFn: (filename)->             # convert .js | .javascript to .js
          (require '../paths/upath').changeExt filename, 'js'
      }

      [ # the alternative (& easier) way of declaring a Converter
        'Coffeescript'                    # name at pos 0

        [                                 # filespecs at pos 1
          '**/*.coffee'
          /.*\.(coffee\.md|litcoffee)$/i
        ]

        (source, filename)->              # convert function at pos 2
          (require 'coffee-script').compile source, bare:true

        (filename)->                      # convertFn function at pos 3
          ext = filename.replace /.*\.(coffee\.md|litcoffee|coffee)$/i, "$1" # retrieve matched extension, eg 'coffee.md'
          filename.replace (new RegExp ext+'$'), 'js'                        # replace it and teturn new filename
      ]

    ]


    ###
    Where to map `/` when running in node. On RequireJS its http-server's root.

    Can be absolute or relative to bundle. Defaults to bundle.
    @example "/var/www" or "/../../fakeWebRoot"
    ###
    webRootMap: '.'

    dependencies:

      ###
      Each (global) dependency has one or more variables it is exported as, eg `jquery: ["$", "jQuery"]`

      They can be infered from the code of course (AMD only for now), but it good to list them here also.

      They are used to 'fetch' the global var at runtime, eg, when `combined:'almond'` is used.

      In case they are missing from modules (i.e u use the 'nodejs' module format only),
      and aren't here either, 'almond' build will fail.

      Also you can add a different var name that should be globally looked up.
      ###
      variableNames: {}

      # Some known variableNames, have them as backup!
      # todo: provide some 'common ones' that are 'strandard'
      _knownVariableNames:
        chai: 'chai'
        mocha: 'mocha'
        lodash: "_"
        underscore: "_"
        jquery: ["$", "jQuery"]
        backbone: "Backbone"
        knockout: ["ko", 'Knockout']

      ###
      { dependency: varName(s) *}
          or
      ['dep1', 'dep2'] (with discovered or ../variableNames names

      Each dep will be available in the *whole bundle* under varName(s)

      @example {
        'underscore': '_'
        'jquery': ["$", "jQuery"]
        'models/PersonModel': ['persons', 'personsModel']
      }
      @todo: rename to exports.bundle | bundleGlobals | something else?
      ###
      bundleExports: {}

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
    Output on the same directory as bundlePath.

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
    # @todo: NOT IMPLEMENTED.
    # @todo: it should not write combined file if errors occur
    watch: false

    ###
    ignore exports
    # @todo: NOT IMPLEMENTED.
    ###
    noRootExports: false

    # @todo: NOT IMPLEMENTED.
    noBundleExports: false

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

      optimize: "none"

      #  uglify: {beautify: true, no_mangle: true} ,
#
#      ### BELOW HERE NOT USED - comments ###
#      baseUrl: "use uRequire.bundlePath instead" ?
#      appDir:  "use uRequire.appDir instead"