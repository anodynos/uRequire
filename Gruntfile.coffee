_ = (_B = require 'uberscore')._
S = if process.platform is 'win32' then '\\' else '/'
startsWith = (string, substring) -> string.lastIndexOf(substring, 0) is 0
nodeBin = "node_modules#{S}.bin#{S}"

sourceDir     = "source/code"
buildDir      = "build/code"
sourceSpecDir = "source/spec"
buildSpecDir  = "build/spec"

module.exports = gruntFunction = (grunt) ->
  pkg = grunt.file.readJSON 'package.json'

  gruntConfig =
    pkg: pkg

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
      build: 'build'
      temp: 'temp'

    concat:
      VERSIONurequire:
        options: banner: "<%= meta.banner %><%= meta.varVERSION %>"
        src: [ '<%= options.buildDir %>/urequire.js']
        dest:  '<%= options.buildDir %>/urequire.js'

    copy:
      specResources:
        files: [ expand: true, cwd: "#{sourceSpecDir}/NodeRequirer", src: ["*.json"], dest: "#{buildSpecDir}/NodeRequirer"]

      wiki:
        files: [ expand: true, cwd: "#{sourceDir}/config/", src: ["*.md"], dest: "../uRequire.wiki/"]

    watch:
      dev: # requires `coffeeWatch` to compile changed only files! need a changed-only-files coffee task!
        files: ["build/**/*"]
        tasks: ['copy', 'mochaCmd']

      copy:
        files: ["source/**/*"]
        tasks: ['copy:wiki']

    shell:
      coffee: command: "#{nodeBin}coffee -cb -o ./build ./source"
      coffeeWatch: command: "#{nodeBin}coffee -cbw -o ./build ./source"
      mochaCmd: command: "#{nodeBin}mocha #{buildSpecDir}/**/*-spec.js --recursive --timeout 5000 --bail"
      options: verbose: true, failOnError: true, stdout: true, stderr: true

  # copy build files to wherever urequire is a dev dep testbed
  deps = [] #['uberscore']
  for dep in deps
    gruntConfig.copy[dep] =
      files: [ expand: true, src: ["**/*.js", "**/*.json", "!node_modules/**/*"], dest: "../#{dep}/node_modules/urequire"]

  ### shortcuts generation ###
  splitTasks = (tasks)-> if !_.isString tasks then tasks else _.filter tasks.split(/\s/)
  grunt.registerTask cmd, splitTasks "shell:#{cmd}" for cmd of gruntConfig.shell # shortcut to all "shell:cmd"
  grunt.registerTask shortCut, splitTasks tasks for shortCut, tasks of {
    default: "clean build test"
    build: "coffee concat copy"
    test: "copy:specResources mochaCmd"

    # IDE shortcuts
    "alt-c": "copy:wiki"
    "alt-b": "build"
    "alt-d": "default"
    "alt-t": "test"
  }

  grunt.loadNpmTasks task for task of pkg.devDependencies when startsWith(task, 'grunt-')
  grunt.initConfig gruntConfig

  null