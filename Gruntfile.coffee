# requires grunt >= 0.4.1
_ = (_B = require 'uberscore')._

sourceDir     = "source/code"
buildDir      = "build/code"
sourceSpecDir = "source/spec"
buildSpecDir  = "build/spec"

# OS directory separator
S = if process.platform is 'win32' then '\\' else '/'

gruntFunction = (grunt) ->

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

    clean: build: 'build'

    concat:
      VERSIONurequire:
        options: banner: "<%= meta.banner %><%= meta.varVERSION %>"
        src: [ '<%= options.buildDir %>/urequire.js']
        dest:  '<%= options.buildDir %>/urequire.js'

    copy:
      specResources:
        files: [ expand: true, cwd: "#{sourceSpecDir}/NR", src: ["*.json"], dest: "#{buildSpecDir}/NR"]

      wiki:
        files: [ expand: true, cwd: "#{sourceDir}/config/", src: ["*.md"], dest: "../uRequire.wiki/"]

    watch:
      dev: # requires `coffeeWatch` to compile changed only files! need a changed-only-files coffee task!
        files: ["build/**/*", "!build/spec/urequire/code/**/*"]
        tasks: ['copy', 'mochaCmd']

      copy:
        files: ["source/**/*"]
        tasks: ['copy:wiki']

    shell:
      coffee: command: "node_modules#{S}.bin#{S}coffee -cb -o ./build ./source"
      coffeeWatch: command: "node_modules#{S}.bin#{S}coffee -cbw -o ./build ./source"
      chmod: command:
        if process.platform is 'linux' # urequireCmd.js to executable - linux only, I've no idea abt MACs!
          "chmod +x 'build/code/urequireCmd.js'"
        else "@echo " #do nothing
      mochaCmd: command: "node_modules#{S}.bin#{S}mocha #{buildSpecDir}/**/*-spec.js --recursive --bail" #--reporter spec"
      #doc: command: "node_modules#{S}.bin#{S}codo #{sourceDir} --title '<%= pkg.name %> v<%= pkg.version %> API documentation' --cautious"
      options: verbose: true, failOnError: true, stdout: true, stderr: true

  # copy build files to wherever urequire is a dep
  deps = [] #['uberscore']
  for dep in deps
    gruntConfig.copy[dep] =
      files: [ expand: true, src: ["**/*.js", "**/*.json", "!node_modules/**/*"], dest: "../#{dep}/node_modules/urequire"]

  ### shortcuts generation ###
  splitTasks = (tasks)-> if !_.isString tasks then tasks else (_.filter tasks.split(/\s/), (v)-> v)
  grunt.registerTask cmd, splitTasks "shell:#{cmd}" for cmd of gruntConfig.shell # shortcut to all "shell:cmd"
  grunt.registerTask shortCut, splitTasks tasks for shortCut, tasks of {
     default: "clean build test"
     build:   "coffee concat chmod copy"
     test:    "copy:specResources mochaCmd"

     # some shortcuts
     cf:      "coffee"
     cfw:     "coffeeWatch"

     # generic shortcuts
     cl:      "clean"
     b:       "build"
     d:       "concat:bin chmod"
     m:       "mochaCmd"
     t:       "test"
     wd:      "watch:dev"

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