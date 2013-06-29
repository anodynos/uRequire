# requires grunt 0.4.x
sourceDir     = "source/code"
buildDir      = "build/code"
sourceSpecDir = "source/spec"
buildSpecDir  = "build/spec"

gruntFunction = (grunt) ->
  _ = grunt.util._

  gruntConfig =
    pkg: grunt.file.readJSON('package.json')

    meta:
      banner: """
      /*!
      * <%= pkg.name %> - version <%= pkg.version %>
      * Compiled on <%= grunt.template.today(\"yyyy-mm-dd\") %>
      * <%= pkg.repository.url %>
      * Copyright(c) <%= grunt.template.today(\"yyyy\") %> <%= pkg.author.name %> (<%= pkg.author.email %> )
      * Licensed <%= pkg.licenses[0].type %> <%= pkg.licenses[0].url %>
      */\n
      """
      varVERSION: "var VERSION = '<%= pkg.version %>'; //injected by grunt:concat\n"
      mdVersion: "# <%= pkg.name %> v<%= pkg.version %>\n"
      usrBinEnvNode: "#!/usr/bin/env node\n"

    options: {sourceDir, buildDir, sourceSpecDir, buildSpecDir}

    shell:
      coffee: command: "coffee -cb -o ./#{buildDir} ./#{sourceDir}"
      coffeeSpec: command: "coffee -cb -o ./#{buildSpecDir} ./#{sourceSpecDir}"
      coffeeWatch: command: "coffee -cbw -o ./build ./source"
      mocha: command: "mocha #{buildSpecDir} --recursive --bail --reporter spec"
      doc: command: "codo source/code --title '<%= pkg.name %> v<%= pkg.version %> API documentation' --cautious"
      # chmod +x urequireCmd.js

      options: # subtasks inherit options but can override them
        verbose: true
        failOnError: true
        stdout: true
        stderr: true

    copy:
      specResources:
        files: [
          expand: true
          cwd: "#{sourceSpecDir}/"
          src: ["*.json"]
          dest: "#{buildSpecDir}/"
        ]

      wiki:
        files: [
          src: ["source/code/config/uRequireConfigMasterDefaults.coffee.md"]
          dest: "../uRequire.wiki/uRequireConfigMasterDefaults.coffee.md"
        ]

    concat:
      bin:
        options: banner: "<%= meta.usrBinEnvNode %><%= meta.banner %><%= meta.varVERSION %>"
        src: ['<%= options.buildDir %>/urequireCmd.js' ]
        dest: '<%= options.buildDir %>/urequireCmd.js'

      VERSIONurequire:                # add a runtime l.VERSION to _B.Logger's prototype
        options: banner: "<%= meta.banner %><%= meta.varVERSION %>"
        src: [ '<%= options.buildDir %>/urequire.js']
        dest:  '<%= options.buildDir %>/urequire.js'

    clean:
      build: [
        "<%= options.buildDir %>/**/*.*"
        "<%= options.buildSpecDir %>/**/*.*"
      ]

  ### shortcuts generation ###
  splitTasks = (tasks)-> if !_.isString tasks then tasks else (_.filter tasks.split(' '), (v)-> v)

  grunt.registerTask cmd, splitTasks "shell:#{cmd}" for cmd of gruntConfig.shell # shortcut to all "shell:cmd"

  grunt.registerTask shortCut, splitTasks tasks for shortCut, tasks of {
     "default": "build test"
     "build":   "shell:coffee concat copy:wiki"
     "test":    "shell:coffeeSpec copy:specResources mocha"

     # some shortcuts
     "cf":      "shell:coffee"
     "cfw":     "shell:coffeeWatch"

     # generic shortcuts
     "cl":      "clean"
     "b":       "build"
     "d":       "deploy"
     "m":       "mocha"
     "t":       "test"

     # IDE shortcuts
     "alt-c": "cp"
     "alt-b": "b"
     "alt-d": "d"
     "alt-t": "t"
  }

  grunt.initConfig gruntConfig
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-contrib-concat'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-shell'

  null

module.exports = gruntFunction