console.log '\nextractModuleInfo-spec loading'

chai = require("chai")
extractModuleInfo = require ("../code/extractModuleInfo")

assert = chai.assert
expect = chai.expect

describe "extractModuleInfo", ->

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
    expect(extractModuleInfo js, {extractRequires:false}).to.deep.equal {}

  it "should extract basic module info", ->
    js = """
      define(['underscore', 'depdir1/dep1'], function(_, dep1) {
        dep1=new dep1();
        return dep1.doit();
      });
    """

    expect(extractModuleInfo js, {extractRequires:false}).to.deep.equal
      dependencies: [ 'underscore', 'depdir1/dep1' ]
      type: 'define'
      parameters: [ '_', 'dep1' ]
      factoryBody: 'dep1=new dep1;return dep1.doit()'

  it "should extract dependency-less module", ->
    js = """
      define(function(){
        return {foo:bar};
      });
    """

    expect(extractModuleInfo js, {extractRequires:false}).to.deep.equal
      dependencies: []
      type: 'define'
      parameters: []
      factoryBody: 'return{foo:bar}'

  it "should extract dependency-less with 'require' as factory param", ->
    js = """
          define(function(require){
            return {foo:bar};
          });
        """

    expect(extractModuleInfo js, {extractRequires:false}).to.deep.equal
      dependencies: []
      type: 'define'
      parameters: ['require']
      factoryBody: 'return{foo:bar}'

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

    expect(extractModuleInfo js).to.deep.equal
      rootExport: 'vourtses'
      moduleName: 'myModule'
      dependencies: [ 'underscore', 'depdir1/dep1' ]
      type: 'define'
      parameters: [ '_', 'dep1' ]
      factoryBody: 'dep1=new dep1;return dep1.doit()'
      requireDependencies: [] # extract'em by default, unless {extractRequires:false}


  it "should extract require('..' ) dependencies along with everything else", ->
    js = """
      if (typeof define !== 'function') { var define = require('amdefine')(module); };

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
        var crap = require("crap" + i); // wrongDependency

        return {require: require('finalRequire')};
      });
    """

    expect(extractModuleInfo js).to.deep.equal
      moduleName: 'moduleName'
      type: 'define'
      parameters: [ 'require', '_', 'dep1' ]
      dependencies: [ 'require', 'underscore', 'depdir1/dep1' ]
      requireDependencies: ['someRequire', 'myOtherRequire', 'finalRequire']  # extract'em by default
      wrongDependencies: [ 'require("crap"+i)' ]
      factoryBody: '_=require("underscore");var i=1;var r=require("someRequire");if(require==="require"){for(i=1;i<100;i++){require("myOtherRequire")}require("myOtherRequire")}console.log("\\n main-requiring starting....");var crap=require("crap"+i);return{require:require("finalRequire")}'
