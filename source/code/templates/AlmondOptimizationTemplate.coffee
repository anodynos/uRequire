upath = require 'upath'

Dependency = require '../fileResources/Dependency'
Template = require './Template'

varSelector = (vars, finale = 'void 0') ->
  ("(typeof #{v} !== 'undefined') ? #{v} : " for v in vars).join(' ') + finale

module.exports = class AlmondOptimizationTemplate extends Template

  scope: 'bundle'

  constructor: (@bundle) ->
    super

    ### locals & imports handling. ###
    @local_nonNode_deps = []
    @local_nonNode_args = []
    @local_nonNode_params = []
    for dep, vars of @bundle.local_nonNode_depsVars
      for aVar in vars
        @local_nonNode_params.push varSelector(vars, "__throwMissing('#{dep}', '#{vars.join(', ')}')")
        @local_nonNode_deps.push dep
        @local_nonNode_args.push aVar

  Object.defineProperties @::,

    build: get:-> @bundle.build

    # require each bundle dependency with its variables, eg
    # `var isAgree, isAgree2; isAgree = isAgree2 = require('agreement/isAgree');`
    # for all imports deps IN the bundle (i.e non-local).
    # with `imports_bundle_depsVars = {'agreement/isAgree': ['isAgree', 'isAgree2'], ...}`
    # we get `var isAgree, isAgree2; isAgree = isAgree2 = require('agreement/isAgree');`
    imports_bundle_depsLoader: get:->
      (for dep, vars of @bundle.imports_bundle_depsVars
        '    var ' +
        ( if vars.length is 1
            vars[0]
          else
            vars.join(', ') + '; ' + vars.join(' = ')
        ) +
        " = require('#{dep}');"
      ).join('\n')

    moduleNamePrint: get: ->
      if @build.template?.moduleName then "'#{@build.template.moduleName}', " else ""

    # load bundleFactory depending on runtime environment
    bundleFactoryRegistar: get: -> """
        if (__isAMD) {
          return define(#{@moduleNamePrint}#{
            if @local_nonNode_deps.length
              "['" + @local_nonNode_deps.join("', '") + "'], "
            else ''
          }bundleFactory);
        } else {
            if (__isNode) {
                return module.exports = bundleFactory(#{
                  if @local_nonNode_deps.length
                    "require('" + @local_nonNode_deps.join("'), require('") + "')"
                  else ''
                  });
            } else {
                return bundleFactory(#{@local_nonNode_params.join(', ')});
            }
        }
    """

    # requirejs optimize stuff
    wrap: get: ->
      start:
#        @allBanners +
        """
        (function (global, window){
          #{
            if _B.isTrue @build.useStrict then "'use strict';\n" else ''
          }#{@sp 'runtimeInfo'}

          var __nodeRequire = (__isNode ? require : function(dep){
                throw new Error("uRequire: combined template '#{@build.target}', trying to load `node` dep `" + dep + "` in non-nodejs runtime (browser).")
              }),
              __throwMissing = function(dep, vars) {
                throw new Error("uRequire: combined template '#{@build.target}', detected missing dependency `" + dep + "` - all it's known binding variables `" + vars + "` were undefined")
              },
              __throwExcluded = function(dep, descr) {
                throw new Error("uRequire: combined template '#{@build.target}', trying to access unbound / excluded `" + descr + "` dependency `" + dep + "` on browser");
              };\n
        """ +

        @sp('bundle.mergedPreDefineIIFECode') +

        @deb(30, "*** START *** bundleFactory, containing all modules (as AMD) & almond's `require`/`define`") +
        "var bundleFactory = function(#{@local_nonNode_args.join ', '}) {\n"

      end:
        @sp(
           [ 'imports_bundle_depsLoader'
             '`template:combined` loads `dependencies.imports` with `dep.isBundle` )'],

           [ 'bundle.commonCode'
             'added after `dependencies.imports` deps are loaded`'],

           [ 'bundle.mergedCode'
             '`mergedCode` code from all modules is merged and added after `bundle.commonCode`']
        ) +
        (
          if @bundle.main
            @deb(30, "require and return `bundle.main` from `bundleFactory()`, kicking off the bundle.") +
            "    return require('#{@bundle.main}');\n"
          else
            @deb(30, "require all `bundle.modules` from `bundleFactory()`, since `bundle.main` is missing.") +
            ("\nrequire('#{upath.trimExt(mod.dstFilename)}');" for k, mod of @bundle.modules).join('')
        ) +  "\n};" +

        @deb(30, "*** END *** bundleFactory: all modules (as AMD), common code & almond's `require`/`define`") +

        @sp('bundleFactoryRegistar') +

        @deb(20, 'IIFE call of bundle enclosure, with @globalSelector i.e `global === window` always available') +
        """
        }).call(this, #{@globalSelector},
                      #{@globalSelector})
        """

    # @return {
    #   lodash: 'getLocal_lodash',
    #   backbone: 'getLocal_backbone'
    # }
    paths: get:->
      _paths = {}
      for localDep in @local_nonNode_deps
        _paths[localDep] = "getLocal_#{_.slugify localDep}"

      for excludedDep of @bundle.local_node_depsVars
        _paths[excludedDep] = "getExcluded_#{_.slugify excludedDep}"

      _paths

    # @return {
    #   getLocal_lodash: "code",
    #   getLocal_backbone: "code"
    #   getExcluded_BadDep: "code"
    # }
    dependencyFiles: get:->
      _dependencyFiles = {}

      l.deb 70, "creating dependencyFiles 'getLocal_XXX' from @local_nonNode_depsVars = \n", @local_nonNode_depsVars
      for dep, vars of @bundle.local_nonNode_depsVars
        l.deb 80, "creating 'getLocal_#{_.slugify dep}' by grabDependencyVarOrRequireIt(dep = '", dep, "', aVars = ", vars, ')'
        _dependencyFiles["getLocal_#{_.slugify dep}"] =
            @grabDependencyVarOrRequireIt dep, vars, 'local'

      l.deb 70, "creating dependencyFiles for @bundle.local_node_depsVars = ", @bundle.local_node_depsVars
      for excludedDep of @bundle.local_node_depsVars
        l.deb 80, "creating 'getExcluded_#{_.slugify excludedDep}' by grabDependencyVarOrRequireIt(dep=", excludedDep, ', aVars = always empty array!)'
        _dependencyFiles["getExcluded_#{_.slugify excludedDep}"] =
            @grabDependencyVarOrRequireIt excludedDep, [], 'node-only & local'

      _dependencyFiles

  grabDependencyVarOrRequireIt: (dep, vars, descr) ->
    depFactory =
      @deb(50, "define factory (mock) for `#{descr}` '#{dep}' called.") +
      "if (__isNode) {" +

      @deb(50, "loading '#{dep}' with node's `require('#{dep}')`") +
      """\n  return __nodeRequire('#{dep}');
      } else {\n""" +

      @deb(50, "loading '#{dep}' through 1st non-undefined binded var among `#{vars.join(', ')}`, that should be available on closure or global (eg window)") +

      (
        if _.isEmpty vars
          "    __throwExcluded('#{dep}', '#{descr}');"
        else
          """    return #{varSelector vars, "__throwMissing('#{dep}', '#{vars.join(', ')}')"}"""
      ) + "\n}"

    "define(" + @__function(depFactory) + ");"
