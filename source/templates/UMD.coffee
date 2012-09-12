calcPath = require('../relativePath')
# todo: read javascript source and match with parser.
# todo: recognise define [], -> or require [], -> and adjust both node & browser amd accordingly
# todo: make node part really async with timeout
# todo: make unit tests

module.exports = (d)->
  """
    (function (root, factory) {
        if (typeof exports === 'object') {

              var makeRequire = require('myRequire').makeRequire;
              var asyncRequire = makeRequire('#{calcPath d.bundlePath, d.filePath}');
              module.exports = factory(asyncRequire#{(", require('#{dep}')" for dep in d.deps).join('')});

        } else if (typeof define === 'function' && define.amd) {

              // AMD. Register as an anonymous module.

              define(['require'#{(", '#{dep}'" for dep in d.deps).join('')}], #{
              if d.rootExports # Adds browser/root globals if needed
                "function (require#{(', ' + par for par in d.args).join('')}) { \n" +
                "  return (root.#{d.rootExports} = factory(require#{(', ' + par for par in d.args).join('')})); \n" +
                "});"
              else
                'factory);'
              }
        }
    }(this, function(require#{ (", #{par}" for par in d.args).join ''}) {
        #{d.body}
    }));
 """

