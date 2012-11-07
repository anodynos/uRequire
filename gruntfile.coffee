module.exports = (grunt) ->

  sourceDir     = "source/code"
  buildDir      = "build/code"
  sourceSpecDir = "source/spec"
  buildSpecDir  = "build/spec"

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

      coffeeExamples:
        command: "coffee -cb -o ./build/examples ./source/examples"

      coffeeAll:
        command: "coffee -cb -o ./build ./source"

      coffeeWatch:
        command: "coffee -cbw -o ./build ./source"

      urequireExampleDeps:
        command: "urequire UMD build/examples/deps -f"

      urequireExampleABC:
        command: "urequire UMD build/examples/abc -f -v -r ../../.."

      urequireExampleSpec:
        command: "urequire UMD build/examples/spec -f"

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

      # change urequireCmd.js to executable - linux only (?mac?)
      chmod:
        command:  switch process.platform
          when "linux" then "chmod +x '#{globalBuildCode}urequireCmd.js'"
          else "rem" #do nothing

      dos2unix: # download from http://sourceforge.net/projects/dos2unix/files/latest/download
        command: switch process.platform
          when "win32" then "dos2unix build/code/urequireCmd.js"
          else "echo" #do nothing

      globalInstall:
        command: "npm install -g"

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

      main:
        src: [
          '<banner>'
          '<%= options.buildDir %>/urequire.js'
        ]
        dest:'<%= options.buildDir %>/urequire.js'

    copy:
      exampleHtmlAndJs:
        options:
          flatten:false
        files:
          "build/examples/": [ #dest
            "source/examples/**/*.html"    #source
            "source/examples/**/*.js"    #source
            "source/examples/**/*.txt"    #source
            "source/examples/**/*.json"    #source
          ]

      globalInstallTests:
        files:
          "<%= options.globalBuildCode %>": [ #dest
            "<%= options.buildDir %>/**/*.js"  #source
          ]

      localInstallTests: #needed by the examples, makeNodeRequire()
        files:
          "node_modules/urequire/build/code/": [ #dest
            "<%= options.buildDir %>/**/*.js"  #source
          ]

    clean:
        files: [
          "<%= options.globalClean %>"
          "node_modules/urequire/build/code/"
          "<%= options.buildDir %>/**/*.*"
          "<%= options.buildSpecDir %>/**/*.*"
        ]

  grunt.initConfig gruntConfig

  grunt.loadNpmTasks 'grunt-contrib'
  grunt.loadNpmTasks 'grunt-shell' #https://npmjs.org/package/grunt-shell

  # Default task.
  grunt.registerTask "default", "clean build copy test"
  grunt.registerTask "build",   "shell:coffee concat shell:dos2unix copy shell:chmod" #chmod alternative "shell:globalInstall" (slower but more 'correct')
  grunt.registerTask "test",    "shell:coffeeSpec shell:mocha"

  #some shortcuts

  grunt.registerTask "examples", """
    shell:coffeeExamples
    shell:urequireExampleABC
    shell:urequireExampleDeps
    shell:urequireExampleSpec
    copy:exampleHtmlAndJs
    shell:mochaExamples
    shell:runExampleDeps
    shell:runExampleAbc
  """

  grunt.registerTask "w",       "shell:coffeeWatch"
  grunt.registerTask "co",      "shell:coffeeAll"
  grunt.registerTask "coe",     "shell:coffeeExamples"
  grunt.registerTask "b",       "build"
  grunt.registerTask "bt",      "build test"
  grunt.registerTask "cbt",     "clean build test"
  grunt.registerTask "cbte",    "clean build test examples"
  grunt.registerTask "abc",     "shell:coffeeExamples shell:urequireExampleABC shell:urequireExampleSpec shell:runExampleAbc"
  grunt.registerTask "deps",    "shell:coffeeExamples shell:urequireExampleDeps shell:urequireExampleSpec shell:runExampleDeps"
  grunt.registerTask "r",       "shell:coffeeExamples shell:runExampleRequirejs"

  null