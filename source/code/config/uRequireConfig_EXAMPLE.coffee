########### THIS FILLE IS IMAGINERY & UNSTABLE AND MOST FEATURES ARE NO IMPLEMENTED YET! ##############

# options:
#   *  return config as object of module.exports / nodejs
#   *  if on node, write to a .json or .js file
#   *  return as UMD/AMD/nodejs module otherwise

_fs =  require 'fs'
_= require 'lodash'
_B = require 'uberscore'

rJSON = (file)-> JSON.parse _fs.readFileSync file, 'utf-8'


module.exports =

uRequireConfig = # Command line options overide these.

  ###
   see `appDir` in https://github.com/jrburke/r.js/blob/master/build/example.build.js
   @todo: NOT IMPLEMENTED
  ####
  appDir: "some/path/"

  # A number of bundles
  bundles:
    ### Bundle information ###

    uBerscore: # becomes: bundleName

      #
      # If ommited, it is implied by config's position
      #
      # @example './source/code'
      bundlePath: undefined

      # Output converted files onto this
      # * directory
      # * filename
      # * function @todo: NOT IMPLEMENTED
      # If ommited, buildjs.baseUrl is used ?
      # @example 'build/code'
      outputPath: undefined

      # Output on the same directory as bundlePath.
      #
      # Useful if your sources are not `real sources` eg. you use coffeescript :-).
      #
      # WARNING: -f ignores --outputPath
      forceOverwriteSources: false

      # everything that matches these is not proccessed
      exclude: [ "requirejs_plugins/**/*", /^draft/ ]

      # The main / index file of your bundle.
      #
      # * Used as 'name' / 'include' on RequireJS build.js, where all dependencies (recursivelly) are added to the combined file.
      #
      # * Also used to as the initiation `require` on your combined bundle. It usually is the bundle that has some rootExports
      #
      #  @todo : defaults are 'main', 'index' etc
      main: "uBerscore"

      # Where to map `/` when running in node. On RequireJS its http-server's root.
      # Can be absolute or relative to bundle. Defaults to bundle.
      # @example "/var/www" or "/../../fakeWebRoot"
      webRootMap: '.'

      # *Web/AMD side option* : by default, ALL require('') deps appear on []. to prevent RequireJS to scan @ runtime.
      # With --s you can allow `require('')` scan @ runtime, for source modules that have no [] deps (eg nodejs source modules).
      # note: modules with rootExports / noConflict() always have scanAllow: false
      scanAllow: false

      # Pre-require all deps on node, even if they arent mapped to parameters, just like in AMD deps [].
      # Preserves same loading order, but a possible slower starting up. They are cached nevertheless, so you might gain speed later.
      allNodeRequires: false

      dependencies:

        ###
        Each (global) dependency has one or more variables it is exported as, eg `jquery: ["$", "jQuery"]`
        They can be infered from the code of course (AMD only for now), but it doo to list them here.

        They are used to 'fetch' the global var at runtime, eg, when `combine:'almond'` is used.

        In case they are missing from modules (or use only the 'nodejs' module format), if they aren't here ether, 'almond' build will fail.
        Also you can add a different var name that should be globally looked up as.
        ###
        variableNames: # todo : provide some 'common ones' ?
          lodash: "_"
          underscore: "_"
          jquery: ["$", "jQuery"]
          backbone: "Backbone"

        exports:
          # { dependency: varName(s) *}
          # or
          # ['dep1', 'dep2'] (with discovered or ../variableNames names
          #
          # Each dep will be available in the *whole bundle* under varName(s)
          # todo: NOT IMPLEMENTED
          bundle:
            'underscore': '_'
            'jquery': ["$", "jQuery"]
            'models/PersonModel': ['persons', 'personsModel']

          # Export to root/window: works only on Browser (uRequire <=0.3)
          root:
            # descr: 'export these names as global keys, with vthe lue being this uModule.'
            # type: ['String', '[]'], default: 'undefined'
            vars: ['uBerscore', '_B']

            # descr: 'Generate noConflict() for uModule'
            # types: ['boolean', 'function'], default: false
            # @todo: 'function' not implemented, not even specified!
            noConflict: true


    ### Build / conversion behaviour  ###
    build:
      templates: # @todo: templateS!
        combine:
          # 'almond': 'Use the Universal build, based on almond. It works as standalone <script>, as AMD dependency and on node!
          # @todo: implement other methods ? 'simple AMD build"
          #
          # @default 'almond' - only one for now
          #
          method: 'almond'

          ###
          Array of globals that will be inlined (instead of creating a getGlobal_xxx).

          * 'true' means all (global) libs are inlined.
          * String and []<String> are deps that will be inlined

          @example depsInline: ['backbone', 'lodash']
          @@default undefined/false : 'All globals are replaced with a "getGlobal_#{globalName}"'

          @todo: NOT IMPLEMENTED
          ###
          depsInline: false
        AMD:''

      # Watch for changes in bundle files and reprocess/re output those changed files
      # @todo: NOT IMPLEMENTED.
      # @todo: it should no write combined file if errors occur
      watch: false

      verbose: false

      # Dont bail out while processing, mainly on module processing errors.
      # Usefull along with -watch
      #
      # @example ignore a coffeescript compile error, just do all the other modules.
      #          Or on a 'combine' conversion when a 'global' has no 'var' association anywhere,
      #          just hold on, ignore this global and continue.
      # @todo: NOT IMPLEMENTED
      continue: false

      # Pass these options on uglify js
      # @todo: NOT IMPLEMENTED
      uglify: false

  # Runtime settings - these are used only when executing on nodejs.
  #
  # They are written out as a "uRequire.config.js" module
  # used at runtime on the nodejs side.
  runtime:

    # Change the webRootMap compiled with UMD modules, and use this on instead.
    webRootMap: "/../../.."

    requirejs:
      alwaysAsyncRequire:true # true (default) : RJS node behaviour of >= 2.1.x.
                              # false: inconsistent RJS 2.0.x behaviour (when all modules are cached, loading is synchronous)
      config :
        baseUrl: "some/other/path"
        paths: rJSON('./requirejs.config.json').paths # or `require "json!requirejs.config.json"`


_B.deepExtend uRequireConfig, # continue extending
  runtime:
    requirejsConfig:
      paths:
        someLib: "../some/lib/path"

  RequireJs:
    runtime:
      paths:
        src: "../../src"
        text: ["requirejs_plugins/text", "/libs/requirejs_plugins/json"]
      baseUrl: "../code" # used at runtime

    # A subset of * RequireJS build.js *
    # (https://github.com/jrburke/r.js/blob/master/build/example.build.js)
    buildJs:
      # Only when Combine ?
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

      ### BELOW HERE NOT USED - comments ###
      baseUrl: "use uRequire.bundlePath instead"
      appDir:  "use uRequire.appDir instead"



l = console.log

l JSON.stringify uRequireConfig, null, ' '