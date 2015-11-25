module.exports = gruntFunction = (grunt) ->
  gruntConfig =
    urequire: # eat your own dogfood
      _all:
        dependencies: imports:
          lodash: '_'
          uberscore: '_B'
          'utils/UError': 'UError'
        resources:[
          [ '+inject-_B.logger', ['**/*.js'],
            (m)-> m.beforeBody = "var l = new _B.Logger('uRequire/#{m.path}');"] ]
        runtimeInfo: false
        bare: true
        template: name: 'nodejs'

      lib:
        path: 'source/code'
        dstPath: 'build/code'
        main: 'urequire'
        template: banner: true
        resources: [ 'inject-version' ]

      preSpec:
        path: 'source/spec'
        dstPath: 'build/spec'
        copy: /./
        dependencies:
          imports:
            chai: 'chai'
            specHelpers: 'spH'
          replace: '../code/utils/UError' : 'utils/UError'
        resources: [
          ['import-keys',
            specHelpers: """
              equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual,
              notIqual, ixact, notIxact, like, notLike, likeBA, notLikeBA, equalSet, notEqualSet"""
            chai: 'expect' ] ]

      spec: derive: 'preSpec', afterBuild: require('urequire-ab-specrunner').options
        mochaOptions: "-t 10000 --bail"

      specWatch: derive: 'spec', watch: after: 'copy'

    copy: wiki: files: [ expand: true, cwd: "source/code/config", src: ["*.md"], dest: "wiki/"]
    clean: build: 'build', temp: 'temp'

  splitTasks = (tasks)-> if (tasks instanceof Array) then tasks else tasks.split(/\s/).filter((f)->!!f)
  grunt.registerTask shortCut, "urequire:#{shortCut}" for shortCut of gruntConfig.urequire
  grunt.registerTask shortCut, splitTasks tasks for shortCut, tasks of {
    default: 'clean lib spec'
    develop: 'clean lib specWatch'
    "alt-c": "copy" # IDE shortcuts
    "alt-b": "lib"
  }
  grunt.loadNpmTasks task for task of grunt.file.readJSON('package.json').devDependencies when task.lastIndexOf('grunt-', 0) is 0
  grunt.initConfig gruntConfig