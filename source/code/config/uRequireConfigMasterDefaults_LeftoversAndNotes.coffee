
#      build.template

      #       # combined options: use a 'Universal' build, based on almond that works as standalone <script>, as AMD dependency and on node!
      #       # @todo:3 implement other methods ? 'simple AMD build"
      #      'combined':
      #
      #          # build even if no modules changes (just resources)
      #          noModulesBuild: false:
      #
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



#  ###
#    Other draft/ideas
#    - modules to exclude their need from either AMD/UMD or combine and allow them to be either
#      - accessed through global object, eg 'window'
#      - loaded through RequireJs/AMD if it available
#      - Loaded through nodejs require()
#      - other ?
#    With some smart code tranformation they can be turned into promises :-)
#  ###


#  ###
#  Runtime settings - these are used only when executing on nodejs.
#  They are written out as a "uRequire.config.js" module used at runtime on the nodejs side.
#  @todo: NOT IMPLEMENTED
#  ###
#  #  runtime:
#  #
#  #    # Change the webRootMap compiled with UMD modules, and use this on instead.
#  #    webRootMap: "/../../.."
#  #
#  #    requirejs:
#  #      alwaysAsyncRequire:true # true (default) : RJS node behavior of >= 2.1.x.
#  #                              # false: inconsistent RJS 2.0.x behavior (when all modules are cached, loading is synchronous)
#  #      config :
#  #        baseUrl: "some/other/path"
#  #        paths: rJSON('requirejs.config.json').paths # or `require "json!requirejs.config.json"`
#  #
#  #
#  #_B.deepExtend uRequireConfig, # continue extending
#  #  runtime:
#  #    requirejsConfig:
#  #      paths:
#  #        someLib: "../some/lib/path"
#  # @todo: NOT IMPLEMENTED
#  requirejs:
#      paths:
#        src: "../../src"
#        text: "requirejs_plugins/text"
#        json: "requirejs_plugins/json"
#      # @todo: NOT IMPLEMENTED.
#      baseUrl: "../code" # used at runtime
#
#    # A subset of * RequireJS build.js ? *
#    # (https://github.com/jrburke/r.js/blob/master/build/example.build.js)
#    # @todo: NOT IMPLEMENTED
#    "build.js":
#
#      ###
#      piggy back on this? see `appDir` in https://github.com/jrburke/r.js/blob/master/build/example.build.js
#      @todo: NOT IMPLEMENTED -
#      ####
#      appDir: "some/path/"
#
#      # Only when combined ?
#      #
#      # When build.js has 'globals' in `paths`,
#      #    eg `{ jquery: '/libs/jQuery.js' }`
#      #  it means that these are INLINED.
#      #
#      #  Otherwise, when a 'global' is missing from these paths, almond wouldn't compile, so uRequire generates a dummy reference
#      # that loads the globalDependency from `window` on web or from a simple `require`.
#      paths:
#        lodash: "../../libs/lodash.min"
#
#      #  uglify: {beautify: true, no_mangle: true} ,
##
##      ### BELOW HERE NOT USED - comments ###
##      baseUrl: "use uRequire.path instead" ?
##      appDir:  "use uRequire.appDir instead"

l.log '\n', uRequireConfigMasterDefaults
l.log '\n', require './uRequireConfigMasterDefaults'
l.log _.isEqual uRequireConfigMasterDefaults, require('./uRequireConfigMasterDefaults')