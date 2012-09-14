module.exports = (grunt) ->

  sourceDir     = "source/code"
  buildDir      = "build/code"
  sourceTestDir = "source/test"
  buildTestDir  = "build/test"

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
      sourceTestDir: sourceTestDir
      buildTestDir:  buildTestDir

    shell:
      coffee: # this name can be anything
        command: "coffee -cb -o ./#{buildDir} ./#{sourceDir}"

      coffeeTest:
        command: "coffee -cb -o ./#{buildTestDir} ./#{sourceTestDir}"

#      codo: #codo documentation #not working yet
#        command: "codo /#{sourceDir}"

      mocha:
        command: "mocha #{buildTestDir} --recursive --bail --reporter spec"

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
      testJs:
        files:
          "<%= options.buildTestDir %>": [          #dest
            "<%= options.sourceTestDir %>/**/*.js"  #source
          ]

      localInstallTests:
        files:
          "c:/Program Files/nodejs/node_modules/uRequire/build/code": [ #dest
            "<%= options.buildDir %>/**/*.js"  #source
          ]

    clean:
      files: [
        "c:/Program Files/nodejs/node_modules/uRequire/build/code/**/*.*"
        "<%= options.buildDir %>/**/*.*"
        "<%= options.buildTestDir %>/**/*.*"
      ]

  grunt.initConfig gruntConfig

  grunt.loadNpmTasks 'grunt-contrib'
  grunt.loadNpmTasks 'grunt-shell' #https://npmjs.org/package/grunt-shell

  # Default task.
  grunt.registerTask "default", "clean build copy test"
  grunt.registerTask "build",   "shell:coffee concat copy"
  grunt.registerTask "test",    "shell:coffeeTest shell:mocha"

  #some shortcuts
  grunt.registerTask "co",      "shell:coffee"
  grunt.registerTask "b",       "build"
  grunt.registerTask "bt",      "build test"
  grunt.registerTask "cbt",     "clean build test"

  null