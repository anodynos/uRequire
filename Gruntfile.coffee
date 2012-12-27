#! Grunt configuration for this project.
#!

module.exports = (grunt) ->

  # Package
  # =======
  pkg = require './package.json'

  # Configuration
  # =============
  grunt.initConfig

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

    # Template
    # --------
    template:
      code:
        files: grunt.file.expandMapping 'source/code/**/*.coffee', 'temp/'
          rename: (base, path) ->
            path.replace(/^source\/code\//, base)

        options:
          data:
            pkg: pkg

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

  # Custom
  # ======

  # Template
  # --------
  grunt.registerMultiTask 'template', 'Render underscore templates', ->
    # Compile each file; concatenating them into the source if desired.
    output = for filename in @file.src
      grunt.template.process grunt.file.read(filename), @options()

    # If we managed to get anything; let the world know.
    if output.length > 0
      grunt.file.write @file.dest, output.join('\n') || ''
      grunt.log.writeln "File #{@file.dest.cyan} created."

  # Tasks
  # =====

  # Build
  # -----
  grunt.registerTask 'build', [
    'copy:code'
    'template:code'
    'coffee:code'
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
