chai = require 'chai'
assert = chai.assert
expect = chai.expect

_ = require 'lodash'

{ equal, notEqual, ok, notOk, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
  ixact, notIxact, like, notLike, likeBA, notLikeBA } = require '../spec-helpers'

isFileInSpecs = require '../../code/config/isFileInSpecs'

files = [
  'file.txt'
  'path/file.coffee'
  'draft/mydraft.coffee'
  'literate/draft/*.coffee.md'

  #ommit
  'uRequireConfigUMD.coffee'
  'mytext.md'
  'draft/mydraft.txt'
  'badfile.txt'
]

fileSpecs = [
  '**/*.*'
  '!**/draft/*.*'
  '!uRequireConfig*.*'
  '!', /.*\.md/
  '**/draft/*.coffee'
  '**/*.coffee.md'
  '!', (f)-> f is 'badfile.txt'
]

describe 'isFileInSpecs', ->
  it "correctly expands files", ->
    filteredFiles = _.filter files, (f)-> isFileInSpecs f, fileSpecs
    deepEqual filteredFiles,
      [
        'file.txt'
        'path/file.coffee'
        'draft/mydraft.coffee'
        'literate/draft/*.coffee.md'
      ]