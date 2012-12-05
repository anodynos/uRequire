module.exports =
  baseUrl: "."
  paths:

    #//      lodash: "../../libs/lodash.min"
    lodash: "getGlobal_lodash"

  name: "almond"

  wrap:
    start: """
      var isAMD = (typeof define === 'function' && define.amd),
          isNode = (typeof exports === 'object'),
          __global = null,
          nodeRequire = function(){};

      if (isNode) {
          nodeRequire = require;
          __global = global;
      } else {
          __global = window;
      };

      factory = function() {
    """

    end: """\n
          return require('uBerscore');
      };

      if (isAMD) {
          define(['lodash'], factory);
      } else {
          if (isNode) {
              module.exports = factory();
          } else {
              factory();
          }
      }
    """

    # We dont have AMD:
    #require('lodash')
    # * run the almond factory,

    # * rely on globals xxx been established with getGlobal_xxx

  #      to return internally available vars.
  # * exportsGlobals anyway ?

  #  out: "../uBerscore-min.js",  optimize:'uglify', // min profile

  optimize: "none"

  #  uglify: {beautify: true, no_mangle: true} ,