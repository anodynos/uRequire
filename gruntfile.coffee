module.exports = (grunt) ->

  sourceDir       = "source/code"
  buildDir        = "build/code"
  sourceTestDir   = "source/test"
  buildTestDir    = "build/test"

  #
  # Grunt 'official' configuration :-)
  #
  gruntConfig =
    pkg: "<json:package.json>"

    meta:
      banner: """
      /*! <%= pkg.name %> - v<%= pkg.version %>
      * Compiled on <%= grunt.template.today(\"yyyy-mm-dd\") %>
      * <%= pkg.repository.url %>
      * Copyright (c) <%= pkg.author.name %> <%= grunt.template.today(\"yyyy\") %>
      * Licensed <%= pkg.licenses[0].url %>
      */
      """

    options:
      sourceDir:   sourceDir
      buildDir:    buildDir
      sourceTestDir:  sourceTestDir
      buildTestDir: buildTestDir

    shell:
      coffee: # this name can be anything
        command: "coffee -cb -o ./#{buildDir} ./#{sourceDir}"

      coffeeTest:
        command: "coffee -cb -o ./#{buildTestDir} ./#{sourceTestDir}"

      codo: #codo documentation
        command: "codo /#{sourceDir}"

      mocha:
        command: "mocha #{buildTestDir} --recursive --bail --reporter spec"

      _options: # subtasks inherit _options but can override them
        failOnError: true
        stdout: true
        stderr: true

    lint:
      files: ["#{buildDir}/**/*.js"]

    copy:
#      options:   #Check 'working', ask fix if not
#        flatten:true
      testJs:
        files:
          "<%= options.buildTestDir %>": [ #dest
            "<%= options.sourceTestDir %>/**/*.js"    #source
          ]

    clean:
      files: [
        "#{buildDir}/**/*.*"
        "#{buildTestDir}/**/*.*"
      ]

  grunt.initConfig gruntConfig

  grunt.loadNpmTasks 'grunt-contrib'
  grunt.loadNpmTasks 'grunt-shell' #https://npmjs.org/package/grunt-shell

  # Default task.
  grunt.registerTask "default", "clean shell:coffee copy test"
  grunt.registerTask "build",   "shell:coffee shell:coffeeTest copy"
  grunt.registerTask "test",    "shell:coffeeTest shell:mocha"
  grunt.registerTask "all",     "clean shell:coffee shell:coffeeTest shell:mocha copy shell:codo"

  #some shortcuts
  grunt.registerTask "co",      "shell:coffee"
  grunt.registerTask "b",       "build"
  grunt.registerTask "bt",      "build test"
  grunt.registerTask "cbt",     "clean build test"

  null