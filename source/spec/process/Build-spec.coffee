Build = require '../../code/process/Build'

bundle =
  dependencies:

    paths:
      override:
        lodash: ['../../mystuff/user/defined/lodash'
                 '../../mystuff/user/defined/lodash.js'
                 'stuff/user/defined/lodash' ]
      bower:
        lodash: 'bower/defined/lodash.js'
        jquery: [ 'bower/jquery.js'
                  'bower/jquery' ]  # dublicate if .js is ignored
      npm:
        lodash: 'npm/defined/lodash.js'

class Build_mock
  bundle: bundle

  calcRequireJsConfig: Build::calcRequireJsConfig

  dstPath: 'build/path'

  rjs:
    paths:
      lodash: 'rjs/defined/lodash'
      jquery: ['rjs/defined/jquery']
    shim:
      anything: 'goes'

b = new Build_mock

describe "process/Build:", ->

  describe "`calcRequireJSConfig()` returns a require.config:", ->

    describe "merging all user-defined & discovered dependency paths:", ->

      it "adjusted to `dstPath` if no path argument is passed:", ->
        deepEqual b.calcRequireJsConfig(),
          baseUrl: '.'
          paths:
            lodash: [
              '../../../../mystuff/user/defined/lodash'
              '../../stuff/user/defined/lodash'
              '../../bower/defined/lodash'
              '../../rjs/defined/lodash'
              '../../npm/defined/lodash' ]
            jquery: [
              '../../bower/jquery'
              '../../rjs/defined/jquery' ]
          shim:
            anything: 'goes'

      it "adjusted to `path` argument if its passed:", ->
        deepEqual b.calcRequireJsConfig('some/build/path'),
          baseUrl: '../../some/build/path'
          paths:
            lodash: [
              '../../../../../mystuff/user/defined/lodash'
              '../../../stuff/user/defined/lodash'
              '../../../bower/defined/lodash'
              '../../../rjs/defined/lodash'
              '../../../npm/defined/lodash' ]
            jquery: [
              '../../../bower/jquery'
              '../../../rjs/defined/jquery' ]
          shim:
            anything: 'goes'

      # blendsWith spec is in `urequire-spec`