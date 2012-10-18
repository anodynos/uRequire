module.exports = (grunt) ->

  sourceDir     = "source/code"
  buildDir      = "build/code"
  sourceSpecDir = "source/spec"
  buildSpecDir  = "build/spec"

  gruntConfig =
    pkg: "<json:package.json>"

    meta:
      banner: """
      /*!
      * <%= pkg.name %> - version <%= pkg.version %>
      * Compiled on <%= grunt.template.today(\"yyyy-mm-dd\") %>
      * <%= pkg.repository.url %>
      * Copyright(c) <%= grunt.template.today(\"yyyy\") %> <%= pkg.author.name %> (<%= pkg.author.email %> )
      * Licensed <%= pkg.licenses[0].type %> <%= pkg.licenses[0].url %>
      */
      """

      usrBinEnvNode : '#!/usr/bin/env node \n\r'

    options:
      sourceDir:     sourceDir
      buildDir:      buildDir
      sourceSpecDir: sourceSpecDir
      buildSpecDir:  buildSpecDir

    shell:
      coffee:
        command: "coffee -cb -o ./#{buildDir} ./#{sourceDir}"

      coffeeSpec:
        command: "coffee -cb -o ./#{buildSpecDir} ./#{sourceSpecDir}"

      coffeeExamples:
        command: "coffee -cb -o ./build/examples ./source/examples"

      coffeeAll:
        command: "coffee -cb -o ./build ./source"

      coffeeWatch:
        command: "coffee -cbw -o ./build ./source"

      uRequireExampleDeps:
        command: "uRequire UMD build/examples/deps -f -v"

      uRequireExampleABC:
        command: "uRequire UMD build/examples/abc -f -a -r ../../.."

      uRequireExampleSpec:
        command: "uRequire UMD build/examples/spec -f -v"

      runExampleDeps:
        command: "node build/examples/deps/main"

      runExampleAbc:
        command: "node build/examples/abc/a-lib"

      runExampleRequirejs:
        command: "node build/examples/rjs/runA"

      mocha:
        command: "mocha #{buildSpecDir} --recursive --bail --reporter spec"

      mochaExamples:
        command: "mocha build/examples/spec/ --recursive --bail --reporter spec"

      _options: # subtasks inherit _options but can override them
        failOnError: true
        stdout: true
        stderr: true

    concat:
      bin:
        src: [
          '<banner:meta.usrBinEnvNode>'
          '<banner>'
          '<%= options.buildDir %>/uRequireCmd.js'
        ]
        dest:'<%= options.buildDir %>/uRequireCmd.js'

      main:
        src: [
          '<banner>'
          '<%= options.buildDir %>/uRequire.js'
        ]
        dest:'<%= options.buildDir %>/uRequire.js'

    copy:
      exampleHtmlAndJs:
        options:
          flatten:false
        files:
          "build/examples": [ #dest
            "source/examples/**/*.html"    #source
            "source/examples/**/*.js"    #source
          ]

      globalInstallTests:
        files:
          "c:/Program Files/nodejs/node_modules/uRequire/build/code": [ #dest
            "<%= options.buildDir %>/**/*.js"  #source
          ]

      localInstallTests: #needed by the examples, makeNodeRequire()
        files:
          "node_modules/uRequire/build/code": [ #dest
            "<%= options.buildDir %>/**/*.js"  #source
          ]

    clean:
        files: [
          "c:/Program Files/nodejs/node_modules/uRequire/build/code/**/*.*"
          "<%= options.buildDir %>/**/*.*"
          "<%= options.buildSpecDir %>/**/*.*"
        ]

  grunt.initConfig gruntConfig

  grunt.loadNpmTasks 'grunt-contrib'
  grunt.loadNpmTasks 'grunt-shell' #https://npmjs.org/package/grunt-shell

  # Default task.
  grunt.registerTask "default", "clean build copy test"
  grunt.registerTask "build",   "shell:coffee concat copy"
  grunt.registerTask "test",    "shell:coffeeSpec shell:mocha"
  grunt.registerTask "examples", """
    shell:coffeeExamples
    shell:uRequireExampleABC
    shell:uRequireExampleDeps
    shell:uRequireExampleSpec
    copy:exampleHtmlAndJs
    shell:mochaExamples
    shell:runExampleDeps
    shell:runExampleAbc
  """
  #some shortcuts
  grunt.registerTask "w",       "shell:coffeeWatch"
  grunt.registerTask "co",      "shell:coffeeAll"
  grunt.registerTask "coe",     "shell:coffeeExamples"
  grunt.registerTask "b",       "build"
  grunt.registerTask "bt",      "build test"
  grunt.registerTask "cbt",     "clean build test"
  grunt.registerTask "abc",     "shell:coffeeExamples shell:uRequireExampleABC shell:uRequireExampleSpec"
  grunt.registerTask "deps",    "shell:coffeeExamples shell:uRequireExampleDeps shell:uRequireExampleSpec"
  grunt.registerTask "r",       "shell:coffeeExamples shell:runExampleRequirejs"

  null