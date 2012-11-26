_fs = require 'fs'

gruntFunction = (grunt) ->

  sourceDir     = "source/code"
  buildDir      = "build/code"
  sourceSpecDir = "source/spec"
  buildSpecDir  = "build/spec"

  pkg = JSON.parse _fs.readFileSync './package.json', 'utf-8'

  globalBuildCode = switch process.platform
    when "win32" then "c:/Program Files/nodejs/node_modules/urequire/build/code/"
    when 'linux' then "/usr/local/lib/node_modules/urequire/build/code/"
    else ""

  globalClean = switch process.platform
    when "win32" then  "c:/Program Files/nodejs/node_modules/urequire/build/code/**/*.*"
    when 'linux' then "/usr/local/lib/node_modules/urequire/build/code/**/*.*"
    else ""

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
      varVersion: "var version = '<%= pkg.version %>'; //injected by grunt:concat"
      mdVersion: "# uRequire v<%= pkg.version %>"
      usrBinEnvNode: "#!/usr/bin/env node"

    options:
      sourceDir:     sourceDir
      buildDir:      buildDir
      sourceSpecDir: sourceSpecDir
      buildSpecDir:  buildSpecDir
      globalBuildCode: globalBuildCode
      globalClean: globalClean

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
          else "rem" #do nothing

      dos2unix: # download from http://sourceforge.net/projects/dos2unix/files/latest/download
        command: switch process.platform
          when "win32" then "dos2unix build/code/urequireCmd.js"
          else "echo" #do nothing

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
          '<banner:meta.varVersion>'
          '<%= options.buildDir %>/urequireCmd.js'
        ]
        dest:'<%= options.buildDir %>/urequireCmd.js'

      convertModule: # conversion version
        src: [
          '<banner:meta.varVersion>'
          '<%= options.buildDir %>/process/convertModule.js'
        ]
        dest:'<%= options.buildDir %>/process/convertModule.js'

      NodeRequirer: # runtime version
        src: [
          '<banner:meta.varVersion>'
          '<%= options.buildDir %>/NodeRequirer.js'
        ]
        dest:'<%= options.buildDir %>/NodeRequirer.js'

#      md:
#        src: [
#          '<banner:meta.mdVersion>'
#          './readme.md' #how do we strip 1st line ?
#        ]
#        dest: './readme.md'

    copy:
      specResources:
        options: flatten: false
        files:                       #copy all ["source/**/*.html", "...txt" ]
          "<%= options.buildSpecDir %>/":
            ("#{sourceSpecDir}/**/#{ext}" for ext in [ "*.html", "*.js", "*.txt", "*.json" ])

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

    clean:
        build: [
          "<%= options.buildDir %>/**/*.*"
          "<%= options.buildSpecDir %>/**/*.*"
        ]

        deploy: [
          "<%= options.globalClean %>"
          "../uRequireExamples/node_modules/urequire/build/code/"
        ]

  ### shortcuts generation ###

  # shortcut to all "shell:cmd"
  grunt.registerTask cmd, "shell:#{cmd}" for cmd of gruntConfig.shell

  # generic shortcuts
  grunt.registerTask shortCut, tasks for shortCut, tasks of {
     # basic commands
     "default": "clean build deploy test"
     "build":   "clean:build cf copy:specResources concat"
     "deploy":  "clean:deploy copy dos2unix chmod" #chmod alternative "shell:globalInstall" (slower but more 'correct')
     "test":    "coffeeSpec mocha"
      # generic shortcuts
     "cf":      "shell:coffee" # there's a 'coffee' task already!
     "cfw":     "coffeeWatch"
     "cl":      "clean"
     "cp":      "copy" #" todo: all ?

     "b":       "build"
     "d":       "deploy"
     "t":       "test"
  }

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