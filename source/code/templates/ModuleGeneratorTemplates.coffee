_ = (_B = require 'uberscore')._
_.mixin (require 'underscore.string').exports()
l = new _B.Logger 'uRequire/ModuleGeneratorTemplates'

isTrueOrFileMatch = require '../config/isTrueOrFileMatch'

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

    namePrint: get:-> if @module.name then "'#{@module.name}', " else ""

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

    # On combined allow either
    # * per Module if filespec is used
    # * for whole template only if true was used
    useStrictModule: get:->
      if @module.isUseStrict and not
         (@isCombined and _B.isTrue(@build.useString))
            "'use strict';"
      else
        ''

    runtimeInfo: get: ->
      if @module.isRuntimeInfo or (@isRootExports and @exportRootCheck)
        Template::runtimeInfo
      else
        ''

    isRootExports: get: ->
      (not (  @module.isRootExports_ignore or
              _.isEmpty(@module.flags.rootExports) or
              _.isEmpty(@build.rootExports.runtimes)
      )) and not (
        (@build.template.name in ['UMD', 'UMDplain']) and
        (not @build.noLoaderUMD) and
        ('AMD' not in @build.rootExports.runtimes) and
        ('node' not in @build.rootExports.runtimes)
      )

    exportRootCheck: get: ->
      checks = []
      checks.push '!__isAMD' if 'AMD' not in @build.rootExports.runtimes
      checks.push '!__isNode' if 'node' not in @build.rootExports.runtimes
      checks.push '!(__isWeb && !__isAMD)' if 'script' not in @build.rootExports.runtimes

      checks.join ' && '

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

      (if expCheck = @exportRootCheck then "if (#{expCheck}) {"  else '' ) +

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

      (if expCheck then "}"  else '' ) +

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
          @__functionIIFE fullBody, 'window', @globalSelector, 'global', @globalSelector
        else
          @__functionIIFE fullBody
     )# + ';'
  ###
  A Simple `define(['dep'], function(dep){...body...}})`,
  without any common stuff that are not needed for 'combined' template.

  `combined` template in AlmondOptimizationTemplate, merges/adds them only once.
  ###
  _AMD_plain_define: ->
    'define('+ @namePrint + @defineArrayDepsPrint +
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
    nodeDeps = @module.nodeDeps

    @_genFullBody( # load AMD deps 1st, before kicking off common dynamic code

      # deps with a variable (parameter in AMD)
      ( if _.any(nodeDeps,
          (dep, depIdx)=> (not dep.isSystem) and (@module?.parameters or [])[depIdx]) # has a dep with param
          "\nvar "
        else
          ''
      ) +

      (for param, pi in @module.parameters when not (dep = nodeDeps[pi]).isSystem
         (if prCnt++ is 0 then '' else '    ') +
         param + " = require(" + dep.name(quote:true) + ")"
      ).join(',\n') + (if prCnt is 0 then '' else ';') +

      # deps without a variable (parameter in AMD) - simple require
      (for dep in nodeDeps[@module.parameters.length..]
         "\nrequire(" + dep.name(quote:true) + ");"
      ).join('') +


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

    define = """
      define(#{@namePrint}#{@defineArrayDepsPrint}#{
        if not @isRootExports
          'factory'
        else
          @__function(
            "return rootExport(window, factory(#{@parametersPrint}));",
            @parametersPrint
          )
      })
      """

    @_genFullBody(
      @__functionIIFE(
        (if @isRootExports
          "var rootExport = #{@__function @_rootExportsNoConflict(), 'root, __umodule__'};\n"
        else '') +

        """
          if (typeof exports === 'object') {#{
            if isNodeRequirer
              "\n    var nr = new (require('urequire').NodeRequirer) ('#{@module.path}', module, require, __dirname, '#{@module.webRootMap}', #{@build.template.debugLevel});"
            else ''}
              module.exports = #{ if @isRootExports then 'rootExport(global, ' else ''
               }factory(#{nr}require#{@injectExportsModuleParamsPrint}#{
                  (for nDep in @module.nodeDeps
                    if nDep.isSystem
                      ', ' + nDep.name()
                    else
                      ", #{nr}require(#{nDep.name(quote:true)})"
                  ).join ''})#{if @isRootExports then ')' else ''};
          } else
          """ +
          (
            if @module.isNoLoaderUMD or @module.isWarnNoLoaderUMD
              " if (typeof define === 'function' && define.amd) { #{define} }"
            else
              " #{define}"
          ) +

          if @module.isNoLoaderUMD
            " else {\n" +
            (
              if not _.isEmpty badDeps = _.filter(@module.defineArrayDeps,
                (dep)-> dep.type in ['bundle', 'external', 'notFoundInBundle', 'nodeLocal']) # ok types [ 'untrusted', 'system', 'local' ]
                'throw new Error("UMD with bundle or external deps runs only with an AMD or CommonJS loader.\\n' +
                "Can`t load these deps: " + _.map(badDeps, (d)-> "'#{d.name()}' (#{d.type})" ).join("', '") + "\");"
              else
                (
                  if not _.isEmpty @module.defineArrayDeps
                    """
                      var modNameVars = {#{
                        _.map( @module.defineArrayDeps, (dep)=>
                              "'" + dep.name() + "': " +
                                JSON.stringify @bundle.all_depsVars[dep.name(relative: 'bundle')]
                             ).join(',')
                        }},
                        require = function(modyle) {
                          if (modNameVars[modyle])
                            for (var _i = 0; _i < modNameVars[modyle].length; _i++)
                              if (window.hasOwnProperty(modNameVars[modyle][_i]))
                                return window[modNameVars[modyle][_i]];

                          var msg = "uRequire: Running UMD module as plain <script>, failed to `require('" + modyle + "')`:";
                          if (modNameVars[modyle] && modNameVars[modyle].length)
                            msg = msg + "it`s not exported on `window` as any of these vars: " + JSON.stringify(modNameVars[modyle]);
                          else
                            msg = msg + "WITHOUT an AMD or CommonJS loader & " +
                              "no identifier (i.e varName or param name) associated with dependency '"+modyle+"' in the bundle of '#{@module.path}'.";

                          throw new Error(msg);
                        },
                    """
                  else
                    """
                      var require = function(modyle){
                        throw new Error("uRequire: Loading UMD module as <script>, failed to `require('" + modyle + "')`: reason unexpected !");
                      },
                    """
                ) + " exports = {}, module = {exports: exports};\n" +

                if not @isRootExports
                  "factory(#{@parametersPrint});"
                else
                  "rootExport(window, factory(#{@parametersPrint}));"

            ) + "\n}";
          else
            if @module.isWarnNoLoaderUMD
              " else throw new Error('uRequire: Loading UMD module as <script>, without `build.noLoaderUMD`');"
             else ''
        ,
        # parameter + value to our IIFE
        'factory'
        ,
        @__function( @sp('factoryBodyAMD'), @parametersPrint )
      )
    )

module.exports = ModuleGeneratorTemplates
