_ = (_B = require 'uberscore')._
l = new _B.Logger 'utils/isFileInSpecs-spec'

chai = require 'chai'
expect = chai.expect
{ equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
  ixact, notIxact, like, notLike, likeBA, notLikeBA, equalSet, notEqualSet } = require '../specHelpers'

isFileInSpecs = require '../../code/config/isFileInSpecs'

files = [
  'file.txt'
  'path/file.coffee'
  'draft/mydraft.coffee'
  'literate/draft/*.coffee.md'
  'uRequireConfigUMD.coffee'
  'mytext.md'
  'draft/mydraft.txt'
  'badfile'
]

specFiltersFiles = (spec, expectedFilteredFiles)->
  equalSet (_.filter files, (f)-> isFileInSpecs f, spec), expectedFilteredFiles

describe 'isFileInSpecs filters', ->

  describe "no files:", ->
    it "with empty specs", -> specFiltersFiles [], []
    it "with silly specs", -> specFiltersFiles ['silly', 'spec'], []
    it "with `-> false`", -> specFiltersFiles [-> false], []

  describe "all files:", ->
    it "with `'**/*'`", -> specFiltersFiles ['**/*'], files
    it "with `/./`", -> specFiltersFiles [/./], files
    it "with `-> true`", -> specFiltersFiles [-> true], files

  describe "only files in root:", ->
    it "with `'*'`", -> specFiltersFiles ['*'], [
      'file.txt'
      'uRequireConfigUMD.coffee'
      'mytext.md'
      'badfile'
    ]

    it "only root files with extension `'*.*'`:", -> specFiltersFiles ['*.*'], [
      'file.txt'
      'uRequireConfigUMD.coffee'
      'mytext.md'
    ]

  describe "include or exclude specifics:", ->
    it "included by name", ->
      expectedFiles = [
        'path/file.coffee'
        'draft/mydraft.coffee'
        'uRequireConfigUMD.coffee'
        'mytext.md'
      ]
      specFiltersFiles expectedFiles, expectedFiles

    describe "included by extension:", ->
      expectedFiles = ['path/file.coffee', 'draft/mydraft.coffee', 'uRequireConfigUMD.coffee']

      it "with string spec", -> specFiltersFiles ['**/*.coffee'], expectedFiles
      it "with RegExp spec", -> specFiltersFiles [/.*\.coffee$/], expectedFiles
      it "with Function spec", -> specFiltersFiles [(f)-> f[f.length-6..] is 'coffee' ], expectedFiles

    describe "excluded by extension:", ->
      expectedFiles = [
        'file.txt'
        'literate/draft/*.coffee.md'
        'mytext.md'
        'draft/mydraft.txt'
        'badfile'
      ]

      it "with string spec", -> specFiltersFiles ['**/*', '!**/*.coffee'], expectedFiles
      it "with RegExp spec", -> specFiltersFiles [/./, '!', /.*\.coffee$/], expectedFiles
      it "with Function spec", -> specFiltersFiles [(->true), '!', (f)-> f[f.length-6..] is 'coffee' ], expectedFiles

    describe "included, then excluded:", ->
      expectedFiles = [
        'path/file.coffee'
        'uRequireConfigUMD.coffee'
        # excluded 'draft/mydraft.coffee'
      ]

      it "with string spec", -> specFiltersFiles ['**/*.coffee', '!*draft/*'], expectedFiles
      it "with RegExp spec", -> specFiltersFiles [/.*\.coffee$/, '!', /draft/], expectedFiles
      it "with Function spec", -> specFiltersFiles [
        (f)-> f[f.length-6..] is 'coffee'
        '!', (f)-> f.indexOf('draft') >= 0
      ], expectedFiles

    describe "excluded, then included:", ->
      expectedFiles = [
        'file.txt'
        'literate/draft/*.coffee.md'
        'mytext.md'
        'draft/mydraft.txt'
        'badfile'

        #included
        'draft/mydraft.coffee'
      ]

      it "with string spec", -> specFiltersFiles ['**/*', '!**/*.coffee', '*draft/*'], expectedFiles
      it "with RegExp spec", -> specFiltersFiles [/./, '!', /.*\.coffee$/, /draft/], expectedFiles
      it "with Function spec", -> specFiltersFiles [
        (->true)
        '!', (f)-> f[f.length-6..] is 'coffee'
        (f)-> f.indexOf('draft') >= 0
      ], expectedFiles

  describe "with String, RegExp, Function combined:", ->
    it "correctly filters files", ->
      specFiltersFiles [
        '**/*'
        '!**/draft/*.*'
        '!uRequireConfig*.*'
        '!', /.*\.md/
        '**/*.coffee.md'
        '**/draft/*.coffee'
        '!', (f)-> f is 'badfile'
      ], [
        'file.txt'
        'path/file.coffee'
        'draft/mydraft.coffee'
        'literate/draft/*.coffee.md'
      ]

