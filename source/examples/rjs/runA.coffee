requirejs = require('requirejs');

requirejs.config
  nodeRequire: require

requirejs ['a-lib'], (a)->
  console.log(a);

