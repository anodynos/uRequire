module.exports =

class AlmondOptimizationTemplates
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p
  constructor:->@_constructor.apply @, arguments

  _constructor: (@o)->

  @property wrap: get:->
      start: """
        var __isAMD = (typeof define === 'function' && define.amd),
            __isNode = (typeof exports === 'object'),
            __global = null,
            __nodeRequire = function(){};
        if (__isNode) {
            __nodeRequire = require;
            __global = global;
        } else {
            __global = window;
        };
        factory = function() {
      """

      end: """\n
            return require('#{@o.main}');
        };

        if (__isAMD) {
            define([#{("'#{globalDep}'" for globalDep, globalVars of @o.globalDepsVars).join(', ')}], factory);
        } else {
            if (__isNode) {
                module.exports = factory();
            } else {
                factory();
            }
        }
      """

  # @return { lodash: 'getGlobal_lodash', backbone: 'getGlobal_backbone' }
  @property paths: get:->
    _paths = {}
    for globalDep, globalVars of @o.globalDepsVars
      _paths[globalDep] = "getGlobal_#{globalDep}"

    _paths

  # @return {
  #   getGlobal_lodash: "code",
  #   getGlobal_backbone: "code"
  # }
  @property dependencyFiles:
    enumerable: true
    get:->
      _dependencyFiles = {}
      for globalDep, globalVars of @o.globalDepsVars
        _dependencyFiles["getGlobal_#{globalDep}"] = """
          define(function() {
            if (typeof #{globalVars[0]} === "undefined") {
              return __nodeRequire('#{globalDep}');
            } else {
              return #{globalVars[0]};
            }
          });
        """
      _dependencyFiles

console.log a = new AlmondOptimizationTemplates {
  globals:
    lodash: ['_', 'lodash']
    backbone: ['Backbone']
  main: "uBerscore"
  }

console.log a.dependencyFiles