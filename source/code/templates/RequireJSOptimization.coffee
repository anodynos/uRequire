module.exports =
  baseUrl: "."
  paths:

    #//      lodash: "../../libs/lodash.min"
    lodash: "getGlobal_lodash"

  name: "almond"

  wrap:
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
          return require('uBerscore');
      };

      if (__isAMD) {
          define(['lodash'], factory);
      } else {
          if (__isNode) {
              module.exports = factory();
          } else {
              factory();
          }
      }
    """

    # We dont have AMD:
    # require('lodash')
    # * run the almond factory,

    # * rely on globals xxx been established with getGlobal_xxx

  #      to return internally available vars.
  # * exportsGlobals anyway ?

  #  out: "../uBerscore-min.js",  optimize:'uglify', // min profile

  optimize: "none"

  #  uglify: {beautify: true, no_mangle: true} ,