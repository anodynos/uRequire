console.log '\nextractModule-test loading'

#`if (typeof define !== 'function') {
#  var define = require('amdefine')(module);
#  var requirejs = require("requirejs");
#  requirejs.config({
#    // We set baseUrl to be pointing to "PROJECT/build/code/main/", i.e our modular codebase.
#    // So the relative path between THIS file and "...code/main/" is injected after _dirname.
#    // This allows us to refer to our files (on tests etc) on the "code/main" simply by their name, eg 'project'
#    baseUrl: __dirname + "/../../../build/code/",
#    nodeRequire: require
#  });
#}
#`
# From now on can use either* requirejs() OR define(), either in the browser or in node! PALIA RE!
#
# * Just  keep in mind 'define' means 'I want this to be a reused module, which I am returning'
# whereas 'requirejs' means 'I just need these modules, load em up!'
# see http://stackoverflow.com/questions/9507606/when-to-use-require-and-when-to-use-define

chai = require("chai")
parseAMD = require ("../code/extractModuleInfo")

assert = chai.assert
expect = chai.expect

describe "extractModule()", ->

  it "should deep equal correctly ", ->
    js = """
    if (typeof define !== 'function') { var define = require('amdefine')(module) };
    ({
      module: {
        rootExports: 'vourtses'
      }
    });

    require(['underscore', 'depdir1/dep1'], function(_, dep1) {
      console.log("\n main starting....");
      dep1 = new dep1();
      dep1.myEach([1, 2, 3], function(val) {
        return console.log('each :' + val);
      });
      return "main";
    });
    """

#    console.log parseAMD js

    expect(parseAMD js).to.deep.equal
      rootExports: 'vourtses',
      dependencies: [ 'underscore', 'depdir1/dep1' ],
      type: 'require',
      parameters: [ '_', 'dep1' ],
      factoryBody: '{\n    console.log("\\n main starting....");\n    dep1 = new dep1;\n    dep1.myEach([ 1, 2, 3 ], function(val) {\n        return console.log("each :" + val);\n    });\n    return "main";\n}'
