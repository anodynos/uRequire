module.exports =

class AlmondOptimizationTemplates

  constructor:->@_constructor.apply @, arguments

  _constructor: (o = testData )->
    @paths = {} #{ lodash: 'getGlobal_lodash', backbone: 'getGlobal_backbone' }
    for globalDep, globalVars of o.globalDepsVars
      @paths[globalDep] = "getGlobal_#{globalDep}"

    @wrap =
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
            return require('#{o.main}');
        };

        if (__isAMD) {
            define([#{("'#{globalDep}'" for globalDep, globalVars of o.globalDepsVars).join(', ')}], factory);
        } else {
            if (__isNode) {
                module.exports = factory();
            } else {
                factory();
            }
        }
      """

    # { getGlobal_lodash: "code",  getGlobal_backbone: "code" }
    @dependencyFiles = {}
    for globalDep, globalVars of o.globalDepsVars
      @dependencyFiles["getGlobal_#{globalDep}"] = """
        define(function() {
          if (typeof #{globalVars[0]} === "undefined") {
            return __nodeRequire('#{globalDep}');
          } else {
            return #{globalVars[0]};
          }
        });
      """

#console.log new AlmondOptimizationTemplates {
#  globals:
#    lodash: ['_', 'lodash']
#    backbone: ['Backbone']
#  main: "uBerscore"
#  }