chai = require 'chai'
assert = chai.assert
expect = chai.expect

_ = require 'lodash'

isFileInSpecs = require '../../code/utils/isFileInSpecs'

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
    expect(
      filteredFiles
    ).to.deep.equal [
        'file.txt'
        'path/file.coffee'
        'draft/mydraft.coffee'
        'literate/draft/*.coffee.md'
      ]