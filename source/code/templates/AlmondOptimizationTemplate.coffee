_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/AlmondOptimizationTemplate'

Dependency = require '../fileResources/Dependency'
Template = require './Template'

varSelector = (vars, finale = 'void 0')->
  ("(typeof #{v} !== 'undefined') ? #{v} : " for v in vars).join(' ') + finale
      #if vars.length then finale else ''

module.exports = class AlmondOptimizationTemplate extends Template

  scope: 'bundle'

  constructor: (@bundle)->
    super
    ### locals & exports.bundle handling. ###

    @localDeps = []
    @localParams = []
    @localArgs = []

    # decide type of each dependency in exports.bundle
    @localDepsVars = {}
    for dep, vars of @bundle.exportsBundle_depsVars
      if (new Dependency dep, {path: '__rootOfBundle__', bundle:@bundle}).isLocal
        @localDepsVars[dep] = vars

    for dep, vars of @bundle.localNonNode_depsVars
      if not @localDepsVars[dep]
        @localDepsVars[dep] = vars

    for dep, vars of @localDepsVars
      for aVar in vars
        @localDeps.push dep
        @localArgs.push aVar
        @localParams.push varSelector vars

    @exportsBundle_bundle_depsVars = #i.e, bundle deps like 'agreement/isAgree'
      _.pick @bundle.exportsBundle_depsVars, (vars, dep)=>
        (new Dependency dep, {path: '__rootOfBundle__', @bundle}).isBundle

    @local_nonExportsBundle_depsVars =
      _.pick @bundle.localNonNode_depsVars, (vars, dep)=>
         not @bundle.exportsBundle_depsVars[dep]

  Object.defineProperties @::,

    build: get:-> @bundle.build

    # require each bundle dependency with its variables, eg
    # `var isAgree, isAgree2; isAgree = isAgree2 = require('agreement/isAgree');`
    # for all exports.bundle deps IN the bundle (i.e non-local).
    # with `exportsBundle_bundle_depsVars = {'agreement/isAgree': ['isAgree', 'isAgree2'], ...}`
    # we get `var isAgree, isAgree2; isAgree = isAgree2 = require('agreement/isAgree');`
    dependenciesExportsBundle_bundle_depsLoader: get:->
      (for dep, vars of @exportsBundle_bundle_depsVars
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
            if @localDeps.length
              "['" + @localDeps.join("', '") + "'], "
            else ''
          }bundleFactory);
        } else {
            if (__isNode) {
                return module.exports = bundleFactory(#{
                  if @localDeps.length
                    "require('" + @localDeps.join("'), require('") + "')"
                  else ''
                  });
            } else {
                return bundleFactory(#{@localParams.join(', ')});
            }
        }
    """

    # requirejs optimize stuff
    wrap: get: ->
      start:
#        @allBanners +
        """
        (function (global, window){
          #{if _B.isTrue @build.useStrict then "'use strict';\n" else ''
          }#{@sp 'runtimeInfo'}
          var __nodeRequire = (__isNode ? require :
              function(dep){
                throw new Error("uRequire detected missing dependency: '" + dep + "' - in a non-nodejs runtime. All it's binding variables were 'undefined'.")
              });\n
        """ +

        @sp('bundle.mergedPreDefineIIFECode') +

        @deb(30, "*** START *** bundleFactory, containing all modules (as AMD) & almond's `require`/`define`") +
        "var bundleFactory = function(#{@localArgs.join ', '}) {"

      end:
        @sp(
           [ 'dependenciesExportsBundle_bundle_depsLoader'
             '`template:combined` loads `dependencies.exports.bundle` with `dep.isBundle` )'],

           [ 'bundle.commonCode'
             'added after `dependencies.exports.bundle` deps are loaded`'],

           [ 'bundle.mergedCode'
             '`mergedCode` code from all modules is merged and added after `bundle.commonCode`']
        ) +

        @deb(30, "require and return `bundle.main` from `bundleFactory()`, kicking off the bundle.") +
        "    return require('#{@bundle.main}');\n  };" +
        @deb(30, "*** END *** bundleFactory: all modules (as AMD), common code & almond's `require`/`define`") +

        @sp('bundleFactoryRegistar') +

        @deb(20, 'IIFE call of bundle enclosure, with `global === window` always available') +
        """
        }).call(this, (typeof exports === 'object' ? global : window),
                      (typeof exports === 'object' ? global : window))
        """

    # @return {
    #   lodash: 'getLocal_lodash',
    #   backbone: 'getLocal_backbone'
    # }
    paths: get:->
      _paths = {}
      for localDep in @localDeps
        _paths[localDep] = "getLocal_#{_.slugify localDep}"

      for excludedDep of @bundle.nodeOnly_depsVars
        _paths[excludedDep] = "getExcluded_#{_.slugify excludedDep}"

      _paths

    # @return {
    #   getLocal_lodash: "code",
    #   getLocal_backbone: "code"
    #   getExcluded_BadDep_with_paths: "code"
    # }
    dependencyFiles: get:->
      _dependencyFiles = {}

      l.deb 70, "creating dependencyFiles 'getLocal_XXX' from @localDepsVars = \n", @localDepsVars
      for dep, vars of @localDepsVars
        l.deb 80, "creating 'getLocal_#{_.slugify dep}' by grabDependencyVarOrRequireIt(dep = '", dep, "', aVars = ", vars, ')'
        _dependencyFiles["getLocal_#{_.slugify dep}"] =
            @grabDependencyVarOrRequireIt dep, vars, 'local'

      l.deb 70, "creating dependencyFiles for @bundle.nodeOnly_depsVars = ", @bundle.nodeOnly_depsVars
      for excludedDep of @bundle.nodeOnly_depsVars
        l.deb 80, "creating 'getExcluded_#{_.slugify excludedDep}' by grabDependencyVarOrRequireIt(dep=", excludedDep, ', aVars = always empty array!)'
        _dependencyFiles["getExcluded_#{_.slugify excludedDep}"] =
            @grabDependencyVarOrRequireIt excludedDep, [], 'node-only'

      _dependencyFiles

  grabDependencyVarOrRequireIt: (dep, vars, descr)->
    depFactory =
      @deb(50, "define factory (mock) for `#{descr}` '#{dep}' called.") +
      "if (__isNode) {" +

      @deb(50, "loading '#{dep}' with node's `require('#{dep}')`") +
      """\n  return __nodeRequire('#{dep}');
      } else {\n""" +

      @deb(50, "loading '#{dep}' through 1st non-undefined binded var among `#{vars.join(', ')}`, that should be available on closure or global (eg window)") +

      (
        if _.isEmpty vars
          "  throw new Error(\"uRequire: trying to access unbound / excluded \'#{descr}\' dependency \'#{dep}\') on browser\");"
        else
          "  return #{varSelector vars, "__nodeRequire('#{dep}')"}"
      ) + "\n}"

    "define(" + @__function(depFactory) + ");"