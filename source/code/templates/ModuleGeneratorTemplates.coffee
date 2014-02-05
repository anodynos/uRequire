_ = (_B = require 'uberscore')._
_.mixin (require 'underscore.string').exports()
l = new _B.Logger 'uRequire/ModuleGeneratorTemplates'

isTrueOrFileInSpecs = require '../config/isTrueOrFileInSpecs'

Template = require './Template'

#  Templates for
#
# * UMD module based on https://github.com/umdjs/umd/blob/master/returnExportsGlobal.js
#
# * AMD module `define([...], function(...){return theModule})
#
# * nodejs module `module.exports = theModule`
#
#  @param @module {Module} with
#   {
#     bundle: the bundle object, containing all config & modules
#
#     path: where the module is, within bundle
#
#     name: the name, if it exists.
#
#     kind: type of the original module : 'nodejs' or 'AMD'
#
#     defineArrayDeps: Array of deps, as needed in AMD, in filerelative format (eg '../PersonView' for 'views/PersonView') + all `require('dep')`
#
#     nodeDeps: Array for file-relative dependencies, as required by node (eg '../PersonView')
#
#     parameters: Array of parameter names, as declared on the original AMD, minus those exceeding arrayDeps
#
#     flags:
#
#       rootExports: Array with names 'root' variable(s) to export on the browser side (or false/undefined)
#
#       noConflict: if true, inject a noConflict() method on this module, that reclaims all rootExports to their original value and returns this module.
#
#     factoryBody: The code that returns the module (the body of the function that's the last param of `define()`) or the whole body of the commonjs `require()` module.
#
#     preDefineIIFEBody: The code with an IIFE, before the `define()` call (i.e coffeescripts __extends etc)
#
#     webRootMap: path of where to map '/' when running on node, relative to bundleRoot (starting with '.'), absolute OS path otherwise.
#  }

class ModuleGeneratorTemplates extends Template

  scope: 'module'

  constructor: (@module)-> super

  Object.defineProperties @::,
    bundle: get: -> @module.bundle
    build: get: -> @bundle.build

    isCombined: get:-> @build.template.name is 'combined'

    moduleNamePrint: get:-> if @module.name then "'#{@module.name}', " else ""

    isInjectExportsModule: get:->
      (@module.kind is 'nodejs') or
      (
        @module.isInjectExportsModule and
        #not @isCombined and # why not needed in combined ?
        not (  # skip if already there
              (@module.defineArrayDeps?[0]?.isEqual? 'exports') and
              (@module.parameters?[0] is 'exports') and
              (@module.defineArrayDeps?[1]?.isEqual? 'module') and
              (@module.parameters?[1] is 'module')
            )
      )

    injectExportsModuleParamsPrint: get:->
      if @isInjectExportsModule then ', exports, module' else ''

    # parameters of the factory method, eg 'require, _, personModel' ###
    parametersPrint: get:-> """
      require#{@injectExportsModuleParamsPrint}#{
        (", #{par}" for par in @module.parameters).join ''}
    """

    defineArrayDepsPrint: get:->
      ( if _.isEmpty @module.defineArrayDeps
          "" #keep empty [] not existent, enabling requirejs scan
        else
          if @isInjectExportsModule
            "['require', 'exports', 'module'"
          else
            "['require'"
      ) +
      (
        for dep in @module.defineArrayDeps
           ", #{dep.name(quote:true)}" # quote: single quotes if literal, no quotes otherwise (if untrusted)
      ).join('') +

      ( if _.isEmpty @module.defineArrayDeps then '' else '], ' )

    runtimeInfo: get: ->
      if @module.isRuntimeInfo then Template::runtimeInfo else ''


    # On combined allow either
    # * per Module if filespec is used
    # * for whole template only if true was used
    useStrictModule: get:->
      if @module.isUseStrict and not
         (@isCombined and _B.isTrue(@build.useString))
            "'use strict';"
      else
        ''

    isRootExports: get: ->
      not (@module.isNoRootExports or _.isEmpty @module.flags.rootExports)

  ### private ###
  _rootExportsNoConflict: (rootName='root', returnModule=true)->
      @deb(10, "*** START *** rootExports & noConflict() : exporting module '#{@module.path}' to root='#{rootName}' & attaching `noConflict()`.") +

      ( if @module.flags.noConflict
          ( for expVar, i in @module.flags.rootExports
              "#{if i is 0 then 'var ' else '    '}__old__#{_.underscored expVar}#{i} = #{rootName}['#{expVar}']"
          ).join(',\n') + ';\n'
        else
          ''
      ) +

      (for expVar in @module.flags.rootExports
         "#{rootName}['#{expVar}'] = __umodule__"
      ).join(';\n') + ';\n' +

      ( if @module.flags.noConflict
          "\n__umodule__.noConflict = " +
          @__function(
            (for expVar, i in @module.flags.rootExports
               "#{rootName}['#{expVar}'] = __old__#{_.underscored expVar}#{i}"
            ).join(';\n') + ';' +
            "\nreturn __umodule__;"
          ) + ';'
        else
          ''
      ) + '\n' +

      (if returnModule then "return __umodule__;"  else '') +

      @deb(10, "*** END *** rootExports & noConflict()")

  Object.defineProperties @::,
    factoryBodyAMD: get:-> @factoryBodyAll 'AMD'

    factoryBodyNodejs: get:-> @factoryBodyAll 'nodejs'

    _moduleExports_ModuleFactoryBody: get: ->
      "module.exports = #{@__functionIIFE @module.factoryBody};"

  factoryBodyAll: (toKind = do-> throw new Error "factoryBodyAll requires `toKind` in ['AMD', 'nodejs']" )->
    @sp(
       'useStrictModule',
       ('bundle.commonCode' if not @isCombined),
       ('module.mergedCode' if not @isCombined),
       'module.beforeBody',
       (
         if (toKind is 'nodejs') and (@module.kind is 'AMD')
           [ '_moduleExports_ModuleFactoryBody',
             "body of original '#{@module.kind}' module, assigned to module.exports"]
         else
           [ 'module.factoryBody',
             "body of original '#{@module.kind}' module"]
       ),
       'module.afterBody'
    ) +

    ( if (toKind is 'AMD') and (@module.kind is 'nodejs')
        @deb(20, 'returning nodejs `exports.module` as AMD factory result.') +
        "\nreturn module.exports;"
      else ''
    )

  _genFullBody: (fullBody)->
    fullBody = @sp(
      'runtimeInfo'
      [ 'module.preDefineIIFEBody',
        'statements/declarations before define(), enclosed in an IIFE (function(){})().']
    ) + fullBody

    #return
    @uRequireBanner +
    ( if @module.isBare
        fullBody
      else
        if @module.isGlobalWindow
          root = "(typeof exports === 'object' ? global : window)"
          @__functionIIFE fullBody, 'window', root, 'global', root
        else
          @__functionIIFE fullBody
     )# + ';'
  ###
  A Simple `define(['dep'], function(dep){...body...}})`,
  without any common stuff that are not needed for 'combined' template.

  `combined` template in AlmondOptimizationTemplate, merges/adds them only once.
  ###
  _AMD_plain_define: ->
    'define('+ @moduleNamePrint + @defineArrayDepsPrint +
      @__function( #our factory function (body)
          if not @isRootExports
            @sp('factoryBodyAMD')
          else
            "var __umodule__ = " +
              @__functionIIFE(
                @sp('factoryBodyAMD'),
                @parametersPrint,
                @parametersPrint
              ) + ";\n" +
            @_rootExportsNoConflict 'window'
        ,
          @parametersPrint # our factory function (declaration params)
      ) +
    ')'

  ###
    `combined` templates is actually defined in AlmondOptimizationTemplate.coffee,
    rendered through Bundle.coffee.
    When 'combined' is used, each `Module` in `Bundle` is converted as a `_AMD_plain_define`
  ###
  combined: -> @_AMD_plain_define()

  ### AMD template
      Runs only on WEB/AMD/RequireJs (and hopefully in node through uRequire'd *driven* RequireJS).
  ###
  AMD: -> @_genFullBody @_AMD_plain_define()

  nodejs: ->
    prCnt = 0
    @_genFullBody( # load deps 1st, before kicking off common dynamic code

      ( if _.any(@module.nodeDeps,
          (dep, depIdx)-> (not dep.isSystem) and (@module?.parameters or [])[depIdx]) # has a dep with param
          "\nvar "
        else
          ''
      ) +

      (for param, pi in @module.parameters when not (dep = @module.nodeDeps[pi]).isSystem
         (if prCnt++ is 0 then '' else '    ') +
         param + " = require(" + dep.name(quote:true) + ")"
      ).join(',\n') + ';' +

      @sp('factoryBodyNodejs') +

      if @isRootExports
        "var __umodule__ = module.exports;\n" +
        @_rootExportsNoConflict('global', false)
      else ''
    )

  ###
    UMD template - runs AS-IS on both Web/AMD and nodejs (having 'npm install urequire').
    * Uses `NodeRequirer` to perform `require`s.
  ###
  UMDplain: -> @UMD false

  # todo: revise this
  UMD: (isNodeRequirer=true)->
    nr = if isNodeRequirer then "nr." else ""

    @_genFullBody(
      @__functionIIFE(
        (if @isRootExports
          "var rootExport = #{@__function @_rootExportsNoConflict(), 'root, __umodule__'};"
        else '') +

        """
          if (typeof exports === 'object') {#{
            if isNodeRequirer
              "\n    var nr = new (require('urequire').NodeRequirer) ('#{@module.path}', module, __dirname, '#{@module.webRootMap}');"
            else ''}
              module.exports = #{ if @isRootExports then 'rootExport(global, ' else ''
                   }factory(#{nr}require#{@injectExportsModuleParamsPrint}#{
                      (for nDep in @module.nodeDeps
                        if nDep.isSystem
                          ', ' + nDep.name()
                        else
                          ", #{nr}require(#{nDep.name(quote:true)})"
                      ).join ''})#{if @isRootExports then ')' else ''};
          } else if (typeof define === 'function' && define.amd) {
              define(#{@moduleNamePrint}#{@defineArrayDepsPrint}#{
                if not @isRootExports
                  'factory'
                else
                  @__function(
                    "return rootExport(window, factory(#{@parametersPrint}));",
                    @parametersPrint
                  )
                });
            }
        """
        ,
        # parameter + value to our IIFE
        'factory'
        ,
        @__function( @sp('factoryBodyAMD'), @parametersPrint )
      )
    )

module.exports = ModuleGeneratorTemplates
