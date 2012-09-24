console.log '\nAMDModuleManipulator-spec loading'

chai = require("chai")
AMDModuleManipulator = require ("../code/moduleManipulation/AMDModuleManipulator")

assert = chai.assert
expect = chai.expect

describe "AMDModuleManipulator", ->

  it "should return empty {} for a non-module .js", ->
    js = """
      function require(someVar) {
        abc(['underscore', 'depdir1/dep1'], function(_, dep1) {
           dep1=new dep1();
           var j = require('something');
           return dep1.doit();
        });
    }
    """
    mi = (new AMDModuleManipulator js).extractModuleInfo()

    expect(mi).to.deep.equal {}

  it "should extract basic module info", ->
    js = """
      define(['underscore', 'depdir1/dep1'], function(_, dep1) {
        dep1=new dep1();
        return dep1.doit();
      });
    """
    mi = (new AMDModuleManipulator js).extractModuleInfo()
    expect(mi).to.deep.equal
      dependencies: [ 'underscore', 'depdir1/dep1' ]
      type: 'define'
      parameters: [ '_', 'dep1' ]
      factoryBody: '{dep1=new dep1;return dep1.doit()}'


  it "should extract dependency-less module", ->
    js = """
      define(function(){
        return {foo:bar};
      });
    """
    mi = (new AMDModuleManipulator js).extractModuleInfo()
    expect(mi).to.deep.equal
      type: 'define'
      dependencies:[]
      parameters: []
      factoryBody: '{return{foo:bar}}'


  it "should extract dependency-less with 'require' as factory param", ->
    js = """
          define(function(require){
            return {foo:bar};
          });
        """
    mi = (new AMDModuleManipulator js).extractModuleInfo()
    expect(mi).to.deep.equal
      type: 'define'
      dependencies:[]
      parameters: ['require']
      factoryBody: '{return{foo:bar}}'

  it "should ignore amdefine/require, extract uRequire.rootExport and moduleName as well", ->
    js = """
      if (typeof define !== 'function') { var define = require('amdefine')(module) };

      ({
        uRequire: {
          rootExport: 'vourtses'
        }
      });

      define('myModule', ['underscore', 'depdir1/dep1'], function(_, dep1) {
        dep1=new dep1();
        return dep1.doit();
      });
      """
    mi = (new AMDModuleManipulator js).extractModuleInfo()
    expect(mi).to.deep.equal
      rootExport: 'vourtses'
      moduleName: 'myModule'
      dependencies: [ 'underscore', 'depdir1/dep1' ]
      type: 'define'
      parameters: [ '_', 'dep1' ]
      factoryBody: '{dep1=new dep1;return dep1.doit()}'

  it "should extract require('..' ) dependencies along with everything else", ->
    js = """
      if (typeof define !== 'function') { var define = require('amdefine')(module); };
      ({
        uRequire: {
          rootExport: 'vourtses'
        }
      });

      define('moduleName', ['require', 'underscore', 'depdir1/dep1'], function(require, _, dep1) {
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
    mi = (new AMDModuleManipulator js).extractModuleInfo()
    expect(mi).to.deep.equal
      rootExport: 'vourtses'
      moduleName: 'moduleName'
      type: 'define'
      dependencies: [ 'require', 'underscore', 'depdir1/dep1' ]
      parameters: [ 'require', '_', 'dep1' ]
      factoryBody: '{_=require("underscore");var i=1;var r=require("someRequire");if(require==="require"){for(i=1;i<100;i++){require("myOtherRequire")}require("myOtherRequire")}console.log("\\n main-requiring starting....");var crap=require("crap"+i);require(["asyncDep1","asyncDep2"],function(asyncDep1,asyncDep2){if(require("underscore")){require(["asyncDepOk","async"+crap2],function(asyncDepOk,asyncCrap2){return asyncDepOk+asyncCrap2})}return asyncDep1+asyncDep2});return{require:require("finalRequire")}}'
      requireDependencies: [ 'someRequire', 'myOtherRequire', 'finalRequire' ]
      untrustedRequireDependencies: [ '"crap"+i' ]
      asyncDependencies: [ 'asyncDep1', 'asyncDep2', 'asyncDepOk' ]
      untrustedAsyncDependencies: [ '"async"+crap2' ]