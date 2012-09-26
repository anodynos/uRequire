console.log '\nAMDModuleManipulator-spec loading'

chai = require("chai")
AMDModuleManipulator = require ("../code/moduleManipulation/AMDModuleManipulator")

assert = chai.assert
expect = chai.expect

describe "AMDModuleManipulator", ->

  it "should identify any non-AMD/UMD module as CommonJs", ->
    js = """
      function dosomething(someVar) {
        abc(['underscore', 'depdir1/dep1'], function(_, dep1) {
           dep1=new dep1();
           var j = require('something');
           return dep1.doit();
        });
    }
    """
    mi = (new AMDModuleManipulator js).extractModuleInfo()
    expect(mi).to.deep.equal
      moduleType: 'CommonJS'
      requireDependencies: [ 'something' ]

  it "should identify a UMD module", ->
    js = """
      (function (root, factory) {
          "use strict";
          if (typeof exports === 'object') {
              var nodeRequire = require('uRequire').makeNodeRequire('.', __dirname, '.');
              module.exports = factory(nodeRequire);
          } else if (typeof define === 'function' && define.amd) {
              define(factory);
          }
      })(this, function (require) {
        doSomething();
      });
    """
    mi = (new AMDModuleManipulator js).extractModuleInfo()
    expect(mi).to.deep.equal
      moduleType: 'UMD'

  it "should extract basic AMD info", ->
    js = """
      define(['underscore', 'depdir1/dep1'], function(_, dep1) {
        dep1=new dep1();
        return dep1.doit();
      });
    """
    mi = (new AMDModuleManipulator js, extractFactory:true).extractModuleInfo()
    expect(mi).to.deep.equal
      arrayDependencies: [ 'underscore', 'depdir1/dep1' ]
      moduleType: 'AMD'
      amdCall: 'define'
      parameters: [ '_', 'dep1' ]
      factoryBody: 'dep1=new dep1;return dep1.doit()'


  it "should extract AMD dependency-less module", ->
    js = """
      define(function(){
        return {foo:bar};
      });
    """
    mi = (new AMDModuleManipulator js, extractFactory:true).extractModuleInfo()
    expect(mi).to.deep.equal
      moduleType: 'AMD'
      amdCall: 'define'
      factoryBody: 'return{foo:bar}'


  it "should extract AMD dependency-less with 'require' as factory param", ->
    js = """
          define(function(require){
            return {foo:bar};
          });
        """
    mi = (new AMDModuleManipulator js, extractFactory:true).extractModuleInfo()
    expect(mi).to.deep.equal
      moduleType: 'AMD'
      amdCall: 'define'
      parameters: ['require']
      factoryBody: 'return{foo:bar}'

  it "should ignore amdefine & extract uRequire.rootExport and moduleName as well", ->
    js = """
      if (typeof define !== 'function') { var define = require('amdefine')(module) };

      ({
        uRequire: {
          rootExport: 'myLib'
        }
      });

      define('myModule', ['underscore', 'depdir1/dep1'], function(_, dep1) {
        dep1=new dep1();
        return dep1.doit();
      });
      """
    mi = (new AMDModuleManipulator js, extractFactory:true).extractModuleInfo()
    expect(mi).to.deep.equal
      rootExport: 'myLib'
      moduleName: 'myModule'
      arrayDependencies: [ 'underscore', 'depdir1/dep1' ]
      moduleType: 'AMD'
      amdCall: 'define'
      parameters: [ '_', 'dep1' ]
      factoryBody: 'dep1=new dep1;return dep1.doit()'

  js = """
        if (typeof define !== 'function') { var define = require('amdefine')(module); };
        ({
          uRequire: {
            rootExport: 'myLib'
          }
        });

        define('myModule', ['require', 'underscore', 'depdir1/dep1'], function(require, _, dep1) {
          _ = require('underscore');
          var i = 1;
          var r = require('someRequire');
          if (require === 'require') {
           for (i=1; i < 100; i++) {
              require('myOtherRequire');
           }
           require('myOtherRequire');
          }
          console.log("\n main-requiring starting....");
          var crap = require("crap" + i); // untrustedRequireDependencies

          require(['asyncDep1', 'asyncDep2'], function(asyncDep1, asyncDep2) {
            if (require('underscore')) {
                require(['asyncDepOk', 'async' + crap2], function(asyncDepOk, asyncCrap2) {
                  return asyncDepOk + asyncCrap2;
                });
            }
            return asyncDep1 + asyncDep2;
          });

          return {require: require('finalRequire')};
        });
      """

  it "should extract require('..' ) dependencies along with everything else", ->
    mi = (new AMDModuleManipulator js, extractFactory:true).extractModuleInfo()
    expect(mi).to.deep.equal
      rootExport: 'myLib'
      moduleName: 'myModule'
      moduleType: 'AMD'
      amdCall: 'define'
      arrayDependencies: [ 'require', 'underscore', 'depdir1/dep1' ]
      parameters: [ 'require', '_', 'dep1' ]
      factoryBody: '_=require("underscore");var i=1;var r=require("someRequire");if(require==="require"){for(i=1;i<100;i++){require("myOtherRequire")}require("myOtherRequire")}console.log("\\n main-requiring starting....");var crap=require("crap"+i);require(["asyncDep1","asyncDep2"],function(asyncDep1,asyncDep2){if(require("underscore")){require(["asyncDepOk","async"+crap2],function(asyncDepOk,asyncCrap2){return asyncDepOk+asyncCrap2})}return asyncDep1+asyncDep2});return{require:require("finalRequire")}'
      requireDependencies: [ 'someRequire', 'myOtherRequire', 'finalRequire' ]
      untrustedRequireDependencies: [ '"crap"+i' ]
      asyncDependencies: [ 'asyncDep1', 'asyncDep2', 'asyncDepOk' ]
      untrustedAsyncDependencies: [ '"async"+crap2' ]