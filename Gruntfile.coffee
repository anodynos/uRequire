_fs = require 'fs'
_ = require 'lodash'
_B = require 'uberscore'

isWin32 = process.platform is "win32"

gruntFunction = (grunt) ->

  sourceDir     = "source/code"
  buildDir      = "build/code"
  sourceSpecDir = "source/spec"
  buildSpecDir  = "build/spec"

  pkg = JSON.parse _fs.readFileSync './package.json', 'utf-8'

  globalBuildCode = "c:/Program Files/nodejs/node_modules/urequire/build/code/"

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
      varVersion: "var VERSION = '<%= pkg.version %>'; //injected by grunt:concat"
      mdVersion: "# uRequire v<%= pkg.version %>"
      usrBinEnvNode: "#!/usr/bin/env node"

    options:
      sourceDir:     sourceDir
      buildDir:      buildDir
      sourceSpecDir: sourceSpecDir
      buildSpecDir:  buildSpecDir
      globalBuildCode: globalBuildCode

    shell:
      coffee:
        command: "coffee -cb -o ./#{buildDir} ./#{sourceDir}"

      coffeeSpec:
        command: "coffee -cb -o ./#{buildSpecDir} ./#{sourceSpecDir}"

      coffeeWatch:
        command: "coffee -cbw -o ./build ./source"

      mocha:
        command: "mocha #{buildSpecDir} --recursive --bail --reporter spec"

      chmod: # change urequireCmd.js to executable - linux only (?mac?)
        command:  switch process.platform
          when "linux" then "chmod +x '#{globalBuildCode}urequireCmd.js'"
          else "" #do nothing

      dos2unix: # download from http://sourceforge.net/projects/dos2unix/files/latest/download
        command: switch process.platform
          when "win32" then "dos2unix build/code/urequireCmd.js"
          else "" #do nothing

      globalInstall:
        command: "npm install -g"

      doc:
        command: "codo source/code --title 'uRequire #{pkg.version} API documentation' --cautious"

      _options: # subtasks inherit _options but can override them
        failOnError: true
        stdout: true
        stderr: true

    concat:
      bin:
        src: [
          '<banner:meta.usrBinEnvNode>'
          '<banner>'
          '<%= options.buildDir %>/urequireCmd.js'
        ]
        dest:'<%= options.buildDir %>/urequireCmd.js'

      VERSION: # runtime l.VERSION
        src: [
          '<banner:meta.varVersion>'
          '<%= options.buildDir %>/utils/Logger.js'
        ]
        dest:'<%= options.buildDir %>/utils/Logger.js'

    copy:
      specResources:
        options: flatten: false
        files:                       #copy all ["source/**/*.html", "...txt" ]
          "<%= options.buildSpecDir %>/":
            ("#{sourceSpecDir}/**/#{ext}" for ext in [ "*.html", "*.js", "*.txt", "*.json" ])

  if isWin32 then _B.deepExtend gruntConfig,
    copy:
      globalInstallTests:
        files:
          "<%= options.globalBuildCode %>": [ #dest
            "<%= options.buildDir %>/**/*.js"  #source
          ]

      uRequireExamples_node_modules: #needed by the examples, makeNodeRequire()
        files:
          "../uRequireExamples/node_modules/urequire/build/code/": [ #dest
            "<%= options.buildDir %>/**/*.js"  #source
          ]

      uBerscore_node_modules: #needed by the examples, makeNodeRequire()
        files:
          "../uBerscore/node_modules/urequire/build/code/": [ #dest
            "<%= options.buildDir %>/**/*.js"  #source
          ]

  _B.deepExtend gruntConfig,
    clean:
      build: [
        "<%= options.buildDir %>/**/*.*"
        "<%= options.buildSpecDir %>/**/*.*"
      ]

  if isWin32 then _B.deepExtend gruntConfig,
    clean:
      deploy: [
        "c:/Program Files/nodejs/node_modules/urequire/build/code/**/*.*"
        "../uRequireExamples/node_modules/urequire/build/code/"
        "../uBerscore/node_modules/urequire/build/code/"
      ]

  ### shortcuts generation ###

  # shortcut to all "shell:cmd"
  grunt.registerTask cmd, "shell:#{cmd}" for cmd of gruntConfig.shell

  # generic shortcuts
  grunt.registerTask shortCut, tasks for shortCut, tasks of _B.go {
     # basic commands
     "default": "clean build test" + if isWin32 then ' deploy' else ''
     "build":   "shell:coffee concat"
     "deploy":  if isWin32 then "copy dos2unix chmod" else '' #chmod alternative "shell:globalInstall" (slower but more 'correct')
     "test":    "shell:coffeeSpec copy:specResources mocha"

      # generic shortcuts
     "cf":      "shell:coffee" # there's a 'coffee' task already!
     "cfw":     "coffeeWatch"
     "cl":      "clean"rfefa
     "cp":      "copy" #" todo: all ?

     "b":       "build"
     "d":       "deploy"
     "t":       "test"
  }, fltr: (v)->!!v

  # IDE shortcuts
  grunt.registerTask shortCut, tasks for shortCut, tasks of {
    "alt-c": "cp"
    "alt-b": "b"
    "alt-d": "d"
    "alt-t": "t"
  }

  grunt.initConfig gruntConfig
  grunt.loadNpmTasks 'grunt-contrib'
  grunt.loadNpmTasks 'grunt-shell' #https://npmjs.org/package/grunt-shell

  null

#debug : call with a dummy 'grunt', that spits params on console.log
#gruntFunction
#  initConfig: (cfg)-> console.log 'grunt: initConfig\n', JSON.stringify cfg, null, ' '
#  loadNpmTasks: (tsk)-> console.log 'grunt: registerTask: ', tsk
#  registerTask: (shortCut, task)-> console.log 'grunt: registerTask:', shortCut, task
module.exports = gruntFunction