console.log '\nextractModuleInfo-spec loading'

chai = require("chai")
extractModuleInfo = require ("../code/extractModuleInfo")

assert = chai.assert
expect = chai.expect
  #todo: test against minified factory body (removing all spaces/new lines)

describe "extractModuleInfo", ->

  it "should extract basic module info", ->
    js = """
      define(['underscore', 'depdir1/dep1'], function(_, dep1) {
        dep1=new dep1();
        return dep1.doit();
      });
    """

    expect(extractModuleInfo js).to.deep.equal
      dependencies: [ 'underscore', 'depdir1/dep1' ],
      type: 'define',
      parameters: [ '_', 'dep1' ],
      factoryBody: '{\n    dep1 = new dep1;\n    return dep1.doit();\n}'

  it "should ignore amddefine/require, extract uRequire.rootExports and moduleName as well", ->
    js = """
      if (typeof define !== 'function') { var define = require('amdefine')(module) };
      ({
        uRequire: {
          rootExports: 'vourtses'
        }
      });

      define('myModule', ['underscore', 'depdir1/dep1'], function(_, dep1) {
        dep1=new dep1();
        return dep1.doit();
      });
      """

    expect(extractModuleInfo js).to.deep.equal
      rootExports: 'vourtses'
      moduleName: 'myModule'
      dependencies: [ 'underscore', 'depdir1/dep1' ]
      type: 'define'
      parameters: [ '_', 'dep1' ]
      factoryBody: '{\n    dep1 = new dep1;\n    return dep1.doit();\n}'


  it "should extract dependency-less module", ->
    js = """
          define(function(){
            return {foo:bar};
          });
        """

    expect(extractModuleInfo js).to.deep.equal
      dependencies: [],
      type: 'define',
      parameters: [],
      factoryBody: '{\n    return {\n        foo: bar\n    };\n}'


  it "should extract dependency-less with 'require' as factory param", ->
    js = """
      define(function(require){
        return {foo:bar};
      });
    """

    expect(extractModuleInfo js).to.deep.equal
      dependencies: [],
      type: 'define',
      parameters: ['require'],
      factoryBody: '{\n    return {\n        foo: bar\n    };\n}'
