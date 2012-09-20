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
      usrBinEnvNode : '#!/usr/bin/env node'

    options:
      sourceDir:     sourceDir
      buildDir:      buildDir
      sourceSpecDir: sourceSpecDir
      buildSpecDir:  buildSpecDir

    shell:
      coffee: # this name can be anything
        command: "coffee -cb -o ./#{buildDir} ./#{sourceDir}"

      coffeeSpec:
        command: "coffee -cb -o ./#{buildSpecDir} ./#{sourceSpecDir}"

      coffeeWatch: # this name can be anything
        command: "coffee -cbw -o ./build ./source"

      coffeeExamples: # this name can be anything
        command: "coffee -cb -o ./build/examples ./source/examples"

      uRequireExampleDeps:
        command: "uRequire UMD #{buildDir}/../examples/deps -f -v"

      uRequireExampleABC:
        command: "uRequire UMD #{buildDir}/../examples/abc -f -v -w f:/javascript"

      uRequireExampleSpec:
        command: "uRequire UMD #{buildDir}/../examples/spec -f -v"

      runExampleDeps:
        command: "node build/examples/deps/main"
#      codo: #codo documentation #not working yet
#        command: "codo /#{sourceDir}"

      # tests
      mocha:
        command: "mocha #{buildSpecDir} --recursive --bail --reporter spec"

      mochaExamples:
        command: "mocha build/examples/spec/ --recursive --bail --reporter spec"

      _options: # subtasks inherit _options but can override them
        failOnError: true
        stdout: true
        stderr: true

    lint:
      files: ["<%= options.buildDir %>/**/*.js"]

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
#      options:   #Check 'working', ask fix if not
#        flatten:true
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

      localInstallTests:
        files:
          "node_modules/uRequire/build/code": [ #dest
            "<%= options.buildDir %>/**/*.js"  #source
          ]

      depsTestInstallTests:
        files:
          "Y:/WebStormWorkspace/p/uRequireDepsTest/node_modules/uRequire/build/code": [ #dest
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
  grunt.registerTask "examples", "shell:coffeeExamples shell:uRequireExampleABC shell:uRequireExampleDeps shell:uRequireExampleSpec copy:exampleHtmlAndJs shell:mochaExamples shell:runExampleDeps"
  #some shortcuts
  grunt.registerTask "watch",   "shell:coffeeWatch"
  grunt.registerTask "co",      "shell:coffee"
  grunt.registerTask "b",       "build"
  grunt.registerTask "bt",      "build test"
  grunt.registerTask "cbt",     "clean build test"
  grunt.registerTask "abc",     "shell:coffeeExamples shell:uRequireExampleABC"
  grunt.registerTask "deps",     "shell:coffeeExamples shell:uRequireExampleDeps"


  null