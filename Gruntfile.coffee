# requires grunt 0.4.x
sourceDir     = "source/code"
buildDir      = "build/code"
sourceSpecDir = "source/spec"
buildSpecDir  = "build/spec"

# OS directory separator
S = if process.platform is 'win32' then '\\' else '/'

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

    clean:
      build: [
        "<%= options.buildDir %>/**/*.*"
        "<%= options.buildSpecDir %>/**/*.*"
      ]

    concat:
      bin:
        options: banner: "<%= meta.usrBinEnvNode %><%= meta.banner %><%= meta.varVERSION %>"
        src: ['<%= options.buildDir %>/urequireCmd.js' ]
        dest: '<%= options.buildDir %>/urequireCmd.js'

      VERSIONurequire:
        options: banner: "<%= meta.banner %><%= meta.varVERSION %>"
        src: [ '<%= options.buildDir %>/urequire.js']
        dest:  '<%= options.buildDir %>/urequire.js'

    copy:
      specResources:
        files: [ expand: true, cwd: "#{sourceSpecDir}/NR", src: ["*.json"], dest: "#{buildSpecDir}/NR"]

      wiki:
        files: [ expand: true, cwd: "#{sourceDir}/config/", src: ["*.coffee.md"], dest: "../uRequire.wiki/"]

    watch:
      dev: # requires `coffeeWatch` running to compile changed only files! We need a changed-only-files coffee task!
        files: ["source/**/*.*"]
        tasks: ['copy:wiki', 'mochaCmd']

    shell:
      coffee: command: "node_modules#{S}.bin#{S}coffee -cb -o ./build ./source"
      coffeeWatch: command: "node_modules#{S}.bin#{S}coffee -cbw -o ./build ./source"
      chmod: command:
        if process.platform is 'linux' # urequireCmd.js to executable - linux only, I've no idea abt MACs!
          "chmod +x 'build/code/urequireCmd.js'"
        else "@echo " #do nothing
      mochaCmd: command: "node_modules#{S}.bin#{S}mocha #{buildSpecDir}/**/*-spec.js --recursive --reporter spec --bail"
      #doc: command: "node_modules#{S}.bin#{S}codo #{sourceDir} --title '<%= pkg.name %> v<%= pkg.version %> API documentation' --cautious"

      options:
        verbose: true
        failOnError: true
        stdout: true
        stderr: true

  ### shortcuts generation ###
  splitTasks = (tasks)-> if !_.isString tasks then tasks else (_.filter tasks.split(' '), (v)-> v)

  grunt.registerTask cmd, splitTasks "shell:#{cmd}" for cmd of gruntConfig.shell # shortcut to all "shell:cmd"
  grunt.registerTask shortCut, splitTasks tasks for shortCut, tasks of {
     "default": "clean build test"
     "build":   "coffee concat chmod copy"
     "test":    "copy:specResources mochaCmd"

     # some shortcuts
     "cf":      "coffee"
     "cfw":     "coffeeWatch"

     # generic shortcuts
     "cl":      "clean"
     "b":       "build"
     "d":       "concat:bin chmod"
     "m":       "mochaCmd"
     "t":       "test"

     # IDE shortcuts
     "alt-c": "copy:wiki"
     "alt-b": "b"
     "alt-d": "d"
     "alt-t": "t"
  }

  grunt.loadNpmTasks task for task in [
    'grunt-contrib-clean'
    'grunt-contrib-concat'
    'grunt-contrib-copy'
    'grunt-contrib-watch'
    'grunt-shell'
  ]

  grunt.initConfig gruntConfig

  null

module.exports = gruntFunction