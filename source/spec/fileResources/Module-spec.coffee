chai = require "chai"
assert = chai.assert
expect = chai.expect

Module = require "../../code/fileResources/Module"
UError = require "../../code/utils/UError"
_ = require 'lodash'
_B = require 'uberscore'
l = new _B.Logger 'spec/fileResources/Module-spec'
#_B.Logger.addDebugPathLevel 'urequire', 100


{ equal, notEqual, ok, notOk, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
  ixact, notIxact, like, notLike, likeBA, notLikeBA } = require '../spec-helpers'

# replace depStrings @ indexes with a String() having 'untrusted:true` property
untrust = (indexes, depsStrings)->
  for idx in indexes
    depsStrings[idx] = new String depsStrings[idx]
    depsStrings[idx].untrusted = true
    depsStrings[idx].inspect = -> @toString() + ' (untrusted in test)'
  depsStrings

coffee = require 'coffee-script'
esprima = require 'esprima'

escodegenOptions =
  format:
    indent:
      style: ''
      base: 0
    json: false
    renumber: false
    hexadecimal: false
    quotes: 'double'
    escapeless: true
    compact: true
    parentheses: true
    semicolons: true

# helper: create Module, set its js, extract, delete empties, return info()
moduleInfo = (js)-> (new Module {sourceCodeJs: js, escodegenOptions}).extract().info()

describe "Module:", ->

  describe "Static functions :", ->

    describe "`isLikeCode` compares code structure:", ->
      {isLikeCode, isEqualCode} = Module
      codes = _B.okv {},
        '(function(){}).call()', '(function(someParam, anotherParam){var someVar = 1;}).call(this, that)',
        '(function(){})()', '(function(param){}())',
        'require()', "require('someDep')",
        'if (l.deb()){}', "if(l.deb(90)){debug('Hello')}",
        'if (l.deb()){} else {}', "if(l.deb(90)){debug('Hello')} else {debug('goodbuy')}",
        "a = {}", "a = {a:1}"

      count = 0
      for code1, code2 of codes
        count++
        do (code1, code2, count)->
          describe "compares two strings of javascript code ##{count}:", ->
            it "is true if 1st is a 'subset' of 2nd, false otherwise ##{count}", ->
              expect(isLikeCode code1, code2).to.be.true
              expect(isLikeCode code2, code1).to.be.false

              expect(isEqualCode code2, code1).to.be.false

          describe 'accepts one string of code and one AST', ->
            it "is true if 1st is a 'subset' of 2nd, false otherwise ##{count}", ->
              expect(isLikeCode code1, esprima.parse(code2).body[0]).to.be.true
              expect(isLikeCode esprima.parse(code1).body[0], code2).to.be.true

  describe "Extracting Module information :", ->

    describe "NON-AMD modules:", ->

      it "identifies non-AMD/UMD module as nodejs", ->
        likeBA moduleInfo("""
          function dosomething(someVar) {
            abc(['underscore', 'depdir1/dep1'], function(_, dep1) {
               dep1 = new dep1();
               var someVar = require('someDep');
               return dep1.doit();
            });
          }
          """
        ),
        ext_requireDeps: [ 'someDep' ]
        ext_requireVars: [ 'someVar' ]
        kind: 'nodejs'
        factoryBody: 'function dosomething(someVar){abc(["underscore","depdir1/dep1"],function(_,dep1){dep1=new dep1();var someVar=require("someDep");return dep1.doit();});}'

      it.skip "TODO: should identify a UMD (!?) module", ->
        deepEqual moduleInfo("""
          (function (root, factory) {
              "use strict";
              if (typeof exports === 'object') {
                  var nodeRequire = require('urequire').makeNodeRequire('.', __dirname, '.');
                  module.exports = factory(nodeRequire);
              } else if (typeof define === 'function' && define.amd) {
                  define(factory);
              }
          })(this, function (require) {
            doSomething();
          });
          """
        ),
          kind: 'UMD'
          XXXX: 'what?'

    describe "AMD modules :", ->
      describe "AMD define() signature:", ->
        describe "basic signature cases:", ->

          it "recognises define() with a single Function expression", ->
            deepEqual moduleInfo('define(function(){return {foo:"bar"};})'),
              kind: 'AMD'
              factoryBody: 'return{foo:"bar"};'

          it "recognises define() with a single Function expression & params", ->
            deepEqual moduleInfo('define(function(require, exports, module){return {foo:"bar"};})'),
              kind: 'AMD'
              ext_defineFactoryParams: ['require', 'exports', 'module']
              factoryBody: 'return{foo:"bar"};'

          it "recognises define() with dependency array, Function expression & corresponding params", ->
            deepEqual moduleInfo("""
              define(['underscore', 'depdir1/Dep1'], function(_, Dep1) {
                dep1 = new Dep1();
                return dep1.doit();
              });
              """
            ),
              kind: 'AMD'
              ext_defineArrayDeps: [ 'underscore', 'depdir1/Dep1' ]
              ext_defineFactoryParams: [ '_', 'Dep1' ]
              factoryBody: 'dep1=new Dep1();return dep1.doit();'

          it "recognises define() with String literal, dependency array and Function expression with corresponding params", ->
            deepEqual moduleInfo("""
                define('mymodule', ['underscore', 'depdir1/Dep1'], function(_, Dep1) {
                  dep1 = new Dep1();
                  return dep1.doit();
                });
                """
            ),
              kind: 'AMD'
              name: 'mymodule'
              ext_defineArrayDeps: [ 'underscore', 'depdir1/Dep1' ]
              ext_defineFactoryParams: [ '_', 'Dep1' ]
              factoryBody: 'dep1=new Dep1();return dep1.doit();'

        describe "Wrong define() signatures throw error on extract(): ", ->

          it "throws with a dependency array as only arg", ->
            expect(->moduleInfo "define(['underscore', 'depdir1/Dep1']);").to.throw UError, /Invalid AMD define*/

          it "throws with a String as only arg", ->
            expect(->moduleInfo "define('module');").to.throw UError, /Invalid AMD define*/

          it "throws with a String & function ", ->
            expect(->moduleInfo "define('dep', function(){});").to.throw UError, /Invalid AMD define*/

        describe "Deals with more array dependencies or parameters: ", ->

          it "reads more deps than params", ->
            deepEqual moduleInfo("""
              define('mymodule', ['underscore', 'depdir1/Dep1', 'deps/missingDepVar'], function(_, Dep1) {
                dep1 = new Dep1();
                return dep1.doit();
              });"""
            ),
              kind: 'AMD'
              name: 'mymodule'
              ext_defineArrayDeps: [ 'underscore', 'depdir1/Dep1', 'deps/missingDepVar' ]
              ext_defineFactoryParams: [ '_', 'Dep1' ]
              factoryBody: 'dep1=new Dep1();return dep1.doit();'

          it "reads more params than deps", ->
            deepEqual moduleInfo("""
              define('mymodule', ['underscore'], function(_, Dep1, Dep2) {
                dep1 = new Dep1();
                return dep1.doit();
              });"""
            ),
              kind: 'AMD'
              name: 'mymodule'
              ext_defineArrayDeps: [ 'underscore']
              ext_defineFactoryParams: [ '_', 'Dep1', 'Dep2']
              factoryBody: 'dep1=new Dep1();return dep1.doit();'

      describe "recognizes coffeescript & family immediate Function Invocation (IIFE) : ", ->

        it "removes IIFE & gets generated code as preDefineIIFEBody", ->
          deepEqual moduleInfo(
            coffee.compile "define ['dep1', 'dep2'], (depVar1, depVar2)-> for own p of {} then return {}"
          ),
            kind: 'AMD'
            ext_defineArrayDeps: ['dep1', 'dep2']
            ext_defineFactoryParams: ['depVar1', 'depVar2']
            factoryBody: 'var p,_ref;_ref={};for(p in _ref){if(!__hasProp.call(_ref,p))continue;return{};}',
            preDefineIIFEBody: 'var __hasProp={}.hasOwnProperty;'

        it "ignore specific code before define (eg amdefine) & extracts `urequire:` flags", ->
          deepEqual moduleInfo(
            coffee.compile """
              define = require("amdefine")(module) if typeof define isnt "function"

              if typeof define isnt "function" then define = require("amdefine")(module)

              urequire: rootExports: "myLib"

              onlyThisGoesInto_preDefineIIFEBody = true

              define "myModule", ["underscore", "depdir1/dep1"], (_, dep1) ->
                dep1 = new dep1()
                dep1.doit()
              """
          ),
            ext_defineArrayDeps: [ 'underscore', 'depdir1/dep1' ]
            ext_defineFactoryParams: [ '_', 'dep1' ]
            flags: rootExports: 'myLib'
            name: 'myModule'
            kind: 'AMD'
            factoryBody: 'dep1=new dep1();return dep1.doit();'
            preDefineIIFEBody: 'onlyThisGoesInto_preDefineIIFEBody=true;'

        it "recognises body of commonJs/nodeJs modules & flags, but ommits flags & preDefineIIFEBody ", ->
          deepEqual moduleInfo(coffee.compile """
            urequire: {rootExports: "myLib", someUknownFlag: "yeah!"}

            _ = require "underscore"
            dep1 = require "depdir1/dep1"

            dep1 = new dep1()
            module.exports = dep1.doit()
            """
          ),
            ext_requireDeps: [ 'underscore', 'depdir1/dep1' ]
            ext_requireVars: [ '_', 'dep1' ]
            flags: {rootExports: 'myLib', someUknownFlag: "yeah!"}
            kind: 'nodejs'
            factoryBody: 'var dep1,_;_=require("underscore");dep1=require("depdir1/dep1");dep1=new dep1();module.exports=dep1.doit();'

      describe "trusted and untrusted require('myDep') & require(['myDep'], function(){}) dependencies #1:", ->

        js = """
          if (typeof define !== 'function') { var define = require('amdefine')(module); };

          ({urequire: { rootExports: ['myLib', 'myLib2']}});

          define('myModule', ['require', 'underscore', 'depdir1/dep1'], function(require, _, dep1) {
            underscore = require('underscore');
            var i = 1;
            var someRequire = require('someRequire');
            if (require === 'require') {
             for (i=1; i < 100; i++) {
                require('myOtherRequire');
             }
             require('anotherRequire');
            }
            console.log("main-requiring starting....");
            var crap = require("crap" + i); // untrustedRequireDeps

            require(['asyncDep1', 'asyncDep2'], function(asyncDep1, asyncDep2) {
              if (require('underscore')) {
                  require(['asyncDepOk', 'async' + crap2], function(asyncDepOk, asyncCrap2) {
                    return asyncDepOk + asyncCrap2;
                  });
              }
              return asyncDep1 + asyncDep2;
            });

            return {require: finale = require('finalRequire')};
          });
        """

        mod = new Module {sourceCodeJs: js, escodegenOptions: escodegenOptions}

        it "should extract, prepare & adjust a module's info", ->
          mod.extract()
          mod.prepare()
          mod.adjust()
          expected =
            # extract info
            ext_defineArrayDeps: [
              'require'
              'underscore'
              'depdir1/dep1'
            ]

            ext_defineFactoryParams: [
              'require'
              '_'
              'dep1'
            ]

            ext_requireDeps: untrust [2], [
              'underscore'
              'someRequire'
              '"crap"+i'
              'finalRequire'
              'myOtherRequire'
              'anotherRequire'
              'underscore'
            ]

            ext_requireVars: [
              'underscore'
              'someRequire'
              'crap'
              'finale'
            ]

            ext_asyncRequireDeps: untrust [3], [
              'asyncDep1'
              'asyncDep2'
              'asyncDepOk'
              '"async"+crap2'
            ]

            ext_asyncFactoryParams: [
              'asyncDep1'
              'asyncDep2'
              'asyncDepOk'
              'asyncCrap2'
            ]

            flags: rootExports: ['myLib', 'myLib2']
            name: 'myModule'
            kind: 'AMD'
            factoryBody: 'underscore=require("underscore");var i=1;var someRequire=require("someRequire");if(require==="require"){for(i=1;i<100;i++){require("myOtherRequire");}require("anotherRequire");}console.log("main-requiring starting....");var crap=require("crap"+i);require(["asyncDep1","asyncDep2"],function(asyncDep1,asyncDep2){if(require("underscore")){require(["asyncDepOk","async"+crap2],function(asyncDepOk,asyncCrap2){return asyncDepOk+asyncCrap2;});}return asyncDep1+asyncDep2;});return{require:finale=require("finalRequire")};'

            # adjusted info
            defineArrayDeps: untrust [3], [
               'underscore'
               'depdir1/dep1'
               'someRequire'
               '"crap"+i'
               'finalRequire'
               'myOtherRequire'
               'anotherRequire'
            ]
            nodeDeps: [
               'underscore'
               'depdir1/dep1'
            ]

            parameters: [ '_', 'dep1' ]

          deepEqual mod.info(), expected

        it "should retrieve module's deps & corresponding vars/params via getDepsVars()", ->
          deepEqual mod.getDepsVars(),
            underscore: [ '_', 'underscore' ]
            'depdir1/dep1': [ 'dep1' ]
            finalRequire: [ 'finale' ]
            someRequire: [ 'someRequire' ]
            myOtherRequire: []
            anotherRequire: []
            asyncDep1: [ 'asyncDep1' ]
            asyncDep2: [ 'asyncDep2' ]
            asyncDepOk: [ 'asyncDepOk' ]
            '"async"+crap2': [ 'asyncCrap2' ]
            '"crap"+i': ['crap']

      describe "trusted and untrusted require('myDep') & require(['myDep'], function(){}) dependencies #2:", ->
        js = "(function(){" + """
          var a = 'alpha' + (function(){return 'A'})();
          var b = 'beta';

          ({urequire: {rootExports: ['myMod', 'myModOtherExport'], noConflict: true} });

          define('modName',
            ['arrayDep1', 'arrayDepUntrusted'+crap, 'arrayDep2', 'arrayDepWithoutParam', 'untrustedArrayDepWithoutParam'+crap],
            function(arrayDepVar1, arrayVarUntrusted, arrayDepVar2){

              // initialized/assigned to a variable
              var depVar3 = require('dep3');

              // cant infer require depVar
              var anArray = []
              anArray[0] = require('depAssignedToMemberExpression');

              // untrusted & not assigned to a require depVar
              require('untrustedRequireDep'+crap);

              // assigned to a variable
              var depVar4;
              depVar4 = require('dep4');

              // not assigned to a require depVar
              if (true) {
                require('depUnassingedToVar');
              }

              // outer is untrusted, inner is assigned to var
              require(dep9 = require('dep9'))

              require(['asyncArrayDep1', 'asyncArrayUntrusted' + crap, 'asyncArrayDep2'],
                        function(asyncArrayVar1, asyncArrayUntrustedVar, asyncArrayVar2){
                          return asyncArrayVar1 + asyncArrayVar2
                        }
              );

              return {the: 'module'}
            }
          );
          """ + "})();"

        mod = new Module {sourceCodeJs: js, escodegenOptions: escodegenOptions}

        expected =
          ext_defineArrayDeps: untrust [1, 4], [
             'arrayDep1'
             '"arrayDepUntrusted"+crap'
             'arrayDep2'
             'arrayDepWithoutParam'
             '"untrustedArrayDepWithoutParam"+crap'
          ]

          ext_defineFactoryParams:
           [ 'arrayDepVar1'
             'arrayVarUntrusted'
             'arrayDepVar2' ]

          ext_requireDeps: untrust [4, 6], [
            'dep3'
            'dep4'
            'dep9'
            'depAssignedToMemberExpression'
            '"untrustedRequireDep"+crap'
            'depUnassingedToVar'
            'dep9=require("dep9")'
          ]

          ext_requireVars: [
            'depVar3'
            'depVar4'
            'dep9'
          ]

          ext_asyncRequireDeps: untrust [1], [
             'asyncArrayDep1'
             '"asyncArrayUntrusted"+crap'
             'asyncArrayDep2'
          ]

          ext_asyncFactoryParams: [
            'asyncArrayVar1'
            'asyncArrayUntrustedVar'
            'asyncArrayVar2'
          ]

          flags:
             rootExports: [ 'myMod', 'myModOtherExport' ]
             noConflict: true

          name: 'modName'
          kind: 'AMD'
          factoryBody: 'var depVar3=require("dep3");var anArray=[];anArray[0]=require("depAssignedToMemberExpression");require("untrustedRequireDep"+crap);var depVar4;depVar4=require("dep4");if(true){require("depUnassingedToVar");}require(dep9=require("dep9"));require(["asyncArrayDep1","asyncArrayUntrusted"+crap,"asyncArrayDep2"],function(asyncArrayVar1,asyncArrayUntrustedVar,asyncArrayVar2){return asyncArrayVar1+asyncArrayVar2;});return{the:"module"};'
          preDefineIIFEBody: 'var a="alpha"+function(){return"A";}();var b="beta";'

          # prepared/adjusted info

          parameters: [
             'arrayDepVar1'
             'arrayVarUntrusted'
             'arrayDepVar2'
          ]

          defineArrayDeps: untrust [1,4,9,11],[
            'arrayDep1'
            '"arrayDepUntrusted"+crap'
            'arrayDep2'
            'arrayDepWithoutParam'
            '"untrustedArrayDepWithoutParam"+crap'
            'dep3'
            'dep4'
            'dep9'
            'depAssignedToMemberExpression',
            '"untrustedRequireDep"+crap'
            'depUnassingedToVar'
            'dep9=require("dep9")'
          ]
          nodeDeps: untrust [1,4], [
             'arrayDep1'
             '"arrayDepUntrusted"+crap'
             'arrayDep2'
             'arrayDepWithoutParam'
             '"untrustedArrayDepWithoutParam"+crap'
          ]

        it "should extract all deps, even untrusted and mark them so", ->
          mod.extract()
          mod.prepare()
          mod.adjust()

          deepEqual mod.info(), expected

        it "should re-extract, deleting adjusted/resolved info", ->
          modInfo = mod.extract().info()
          for rd in mod.keys_resolvedDependencies
            expect(modInfo[rd]).to.be.undefined
          expect(modInfo.parameters).to.be.undefined
          exp = _.omit expected, (v,k)-> (k is 'parameters') or (k in mod.keys_resolvedDependencies)
          deepEqual modInfo, exp

        it "should re-adjust with the exact results:", ->
          mod.prepare()
          mod.adjust()
          deepEqual mod.info(), expected

        it "should retrieve module's deps & corresponding vars/params via getDepsVars()", ->
          deepEqual mod.getDepsVars(),
            arrayDep1: [ 'arrayDepVar1' ]
            '"arrayDepUntrusted"+crap': [ 'arrayVarUntrusted' ]
            arrayDep2: [ 'arrayDepVar2' ]
            arrayDepWithoutParam: []
            '"untrustedArrayDepWithoutParam"+crap': []
            dep9: [ 'dep9' ]
            dep4: [ 'depVar4' ]
            dep3: [ 'depVar3' ]
            depAssignedToMemberExpression: []
            depUnassingedToVar: []
            asyncArrayDep1: [ 'asyncArrayVar1' ]
            '"asyncArrayUntrusted"+crap': [ 'asyncArrayUntrustedVar' ]
            asyncArrayDep2: [ 'asyncArrayVar2' ]
            '"untrustedRequireDep"+crap': []
            'dep9=require("dep9")': []

  describe "Replacing & injecting adjusted dependencies:", ->
    js =   """
      define(['require', 'underscore', 'depDir1/Dep1', '../depDir1/uselessDep', 'someDir/someDep', 'depDir1/removedDep'],
        function(require, _, Dep1) {
          dep2 = require('depDir2/Dep2');
          aGlobal = require('aGlobal');
          return dep1.doit();
        }
      );
    """

    mod = (new Module {
      sourceCodeJs: js
      escodegenOptions: escodegenOptions
      srcFilename: 'someDepDir/MyModule'
      bundle: dstFilenames: [
        'depDir1/Dep1.js'
        'depDir2/Dep2.js'
        'depDir1/uselessDep.js'
        'aNewDepInTown.js'
      ]
    })
      .extract()
      .prepare()
      .adjust()

    # replace & inject deps
    mod.replaceDep 'underscore', 'lodash'
    mod.replaceDep 'aGlobal', 'smallVillage'
    mod.replaceDep 'depDir2/Dep2', '../aNewDepInTown'

    # remove
    mod.replaceDep 'depDir1/uselessDep'
    mod.replaceDep '../depDir1/removedDep'

    mod.injectDeps 'myInjectedDep': ['myInjectedDepVar1', 'myInjectedDepVar2']
    mod.injectDeps 'anotherInjectedDep' : 'anotherInjectedVar'
    mod.replaceDep 'myInjectedDep', '../myProperInjectedDep'

    expected =
      #extracted info
      ext_defineArrayDeps:[
        'require'
        'underscore'
        'depDir1/Dep1'
        '../depDir1/uselessDep'
        'someDir/someDep'
        'depDir1/removedDep'
      ]
      ext_defineFactoryParams: [
        'require'
        '_',
        'Dep1'
      ]
      ext_requireDeps: [ 'depDir2/Dep2', 'aGlobal' ]
      ext_requireVars: [ 'dep2', 'aGlobal']
      kind: 'AMD'
      path: 'someDepDir/MyModule'
      factoryBody:'dep2=require("../aNewDepInTown");aGlobal=require("smallVillage");return dep1.doit();'

#      # adjusted, replaced & injected info

      parameters: [
        '_'
        'Dep1'
        'myInjectedDepVar1'
        'myInjectedDepVar2'
        'anotherInjectedVar'
      ]
      defineArrayDeps: [
         'lodash'
         '../depDir1/Dep1'
         '../myProperInjectedDep'
         '../myProperInjectedDep'
         'anotherInjectedDep'
         'someDir/someDep'
         '../aNewDepInTown'
         'smallVillage'
      ]
      nodeDeps: [
         'lodash'
         '../depDir1/Dep1'
         '../myProperInjectedDep'
         '../myProperInjectedDep'
         'anotherInjectedDep'
         'someDir/someDep'
      ]

    it "has the correct injected & replaced deps", ->
      deepEqual mod.info(), expected

  describe "Replacing & deleting code:", ->
    js =   """
      var b = 0;
      if (l.deb(10)) {
        b = 1;
        if (l.deb(20) && true) {
          b = 2;
          if (l.deb(30)) {
            b = 3;
          }
        }
      }
      if (l.deb(40)) {
        b = 4;
      }
      c = 3;
    """

    mod = (new Module {sourceCodeJs: js, escodegenOptions}).extract()

    it "replaces code via function, returning ast or String", ->
      cnt = 1
      mod.replaceCode 'if (l.deb()){}', (ast)->
        ast.test.arguments[0].value++;
        if cnt++ % 2 is 0
          ast
        else
          mod.toCode ast

      expect(Module.isEqualCode(
        "if (true){" + mod.toCode(mod.AST_top) + "}", """
          if (true){
            var b = 0;
            if (l.deb(11)) {
              b = 1;
              if (l.deb(20) && true) {
                b = 2;
                if (l.deb(31)) {
                  b = 3;
                }
              }
            }
            if (l.deb(41)) {
              b = 4;
            }
            c = 3;
          }
        """)
      ).to.be.true

    it "replaces code via String", ->
      mod.replaceCode 'if (l.deb(31)){}', "if (l.deb(31)) { changed = 56; }"
      expect(Module.isEqualCode(
        "if (true){" + mod.toCode(mod.AST_top) + "}", """
          if (true){
            var b = 0;
            if (l.deb(11)) {
              b = 1;
              if (l.deb(20) && true) {
                b = 2;
                if (l.deb(31)) {
                  changed = 56;
                }
              }
            }
            if (l.deb(41)) {
              b = 4;
            }
            c = 3;
          }
        """)
      ).to.be.true

    it "deletes code if 2nd argument == null, traversing only outers", ->
      cnt = 0
      mod.replaceCode 'if (l.deb()){}', -> cnt++; null
      expect(mod.toCode(mod.AST_top)).to.be.equal "var b=0;c=3;"
      expect(cnt).to.equal 2