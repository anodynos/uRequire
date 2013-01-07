#! Grunt configuration for this project.
#!

module.exports = (grunt) ->

  # Package
  # =======
  pkg = require './package.json'

  # Configuration
  # =============
  grunt.initConfig

    # Package
    # -------
    pkg: pkg

    # Metadata
    # --------
    meta:
      version: "var version = '<%= pkg.version %>';"
      shebang: '#!/usr/bin/env node'
      banner: '''
      /*!
       * <%= pkg.name %> - version <%= pkg.version %>
       * Compiled on <%= grunt.template.today(\"yyyy-mm-dd\") %>
       * <%= pkg.repository.url %>
       * Copyright(c) <%= grunt.template.today(\"yyyy\") %> <%= pkg.author.name %> (<%= pkg.author.email %> )
       * Licensed <%= pkg.licenses[0].type %> <%= pkg.licenses[0].url %>
       */
      '''

    # Clean
    # -----
    clean:
      build: 'build'
      temp:  'temp'

    # Preparation
    # -----------
    copy:
      code:
        files:
          'temp/': 'source/code/**/*'

      spec:
        files:
          'build/spec/': [
            'source/spec/**/*'
            '!*.coffee'
          ]

    # Concatenation
    # -------------
    concat:
      options:
        banner: '<%= meta.version %>'

      urequireCmd:
        files: [
          dest: 'build/code/urequireCmd.js'
          src: 'build/code/urequireCmd.js'
        ]

        options:
          banner: '''
          <%= meta.shebang %>
          <%= meta.banner %>
          <%= meta.version %>
          '''

      convertModule:
        files: [
          dest: 'build/code/process/convertModule.js'
          src: 'build/code/process/convertModule.js'
        ]

      processBundle:
        files: [
          dest: 'build/code/process/processBundle.js'
          src: 'build/code/process/processBundle.js'
        ]

      NodeRequirer:
        files: [
          dest: 'build/code/NodeRequirer.js'
          src: 'build/code/NodeRequirer.js'
        ]

    # Compilation
    # -----------
    # TODO: 0.4.x (unreleased) of `grunt-contrib-*` removes destination glob
    coffee:
      code:
        files: 'build/code/*.js': 'temp/**/*.coffee'
        options:
          basePath: 'temp/'
          bare: true

      spec:
        files: 'build/spec/*.js': 'source/spec/**/*.coffee'
        options:
          basePath: 'source/spec/'
          bare: true

    # Lint
    # ----
    coffeelint:
      source: ['source/**/*.coffee']
      grunt: ['Gruntfile.coffee']

    # Test
    # ----
    simplemocha:
      options:
        ui: 'bdd'
        reporter: 'dot'

      source:
        src: 'build/spec/**/*.js'

  # Dependencies
  # ============
  for name of pkg.devDependencies when name.substring(0, 6) is 'grunt-'
    grunt.loadNpmTasks name

  # Tasks
  # =====

  # Build
  # -----
  grunt.registerTask 'build', [
    'copy:code'
    'coffee:code'
    'concat'
  ]

  # Lint
  # ----
  grunt.registerTask 'lint', [
    'coffeelint'
  ]

  # Test
  # ----
  grunt.registerTask 'test-core', [
    'copy:spec'
    'coffee:spec'
    'simplemocha'
  ]

  grunt.registerTask 'test', [
    'clean'
    'build'
    'test-core'
  ]

  # Default
  # -------
  grunt.registerTask 'default', [
    'lint'
    'clean'
    'build'
    'test-core'
  ]
