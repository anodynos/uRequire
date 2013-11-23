chai = require 'chai'
assert = chai.assert
expect = chai.expect

_B = require 'uberscore'
l = new _B.Logger 'urequire/ResourceConverter-spec'
_ = require 'lodash'

ResourceConverter = require '../../code/config/ResourceConverter'

{ equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
  ixact, notIxact, like, notLike, likeBA, notLikeBA } = require '../spec-helpers'

rcSpec1 = [
  '$Coffeescript' # a title of the resource (a module since starting with $)
  [
    '**/*.coffee'
    /.*\.(coffee\.md|litcoffee)$/i
    '!**/*.amd.coffee'
  ]
  (source)-> source
  (filename)-> filename.replace '.coffee', '.js' # dummy filename converter
]

expectedRc =
    # _originalName: '$Coffeescript'
  ' type': 'module'         # display value, as set in 'type'
  ' name': 'Coffeescript'   # display value is 'name' stripped of flags
  descr: 'No descr for ResourceConverter \'Coffeescript\''
  filez:
   [ '**/*.coffee'
     /.*\.(coffee\.md|litcoffee)$/i
     '!**/*.amd.coffee' ]
  convert: rcSpec1[2]
  ' convFilename': rcSpec1[3]   # display value
  _convFilename: rcSpec1[3]   # display value
  isTerminal: false
  isMatchSrcFilename: false

  #when to run
  isBeforeTemplate: false
  isAfterTemplate: false
  isAfterOptimize: false

describe 'ResourceConverter creation, cloning & updating:', ->

  initialRegistryKeys = _.keys ResourceConverter.registry

  rc1 = new ResourceConverter rcSpec1
  rc2 = rc1.clone()

  for rc, rcIdx in [rc1, rc2, rc2.clone()]
    do (rc, rcIdx)->
      describe "ResourceConverter creation & updates (for #{if rcIdx then 'clone() #'+rcIdx else 'original instance'}):", ->

        describe "creates correct RC instance from an rc-spec:", ->
          it "deep equal", ->
            deepEqual rc, expectedRc

          it "clazz.name", ->
            expect(rc.clazz.name).to.equal 'Module'

          it "type", ->
            expect(rc.type).to.equal 'module'

          it "convFilename", ->
            expect(rc.convFilename).to.equal rcSpec1[3]

          it "all clones are equal", ->
            deepEqual rc, rc.clone()

        describe "updating:", ->
          it "`type` on instance, updates hidden clazz field", ->
            rc.type = 'text'
            expect(rc[' type']).to.equal 'text'
            expect(rc['type']).to.equal 'text'
            expect(rc.clazz.name).to.equal 'TextResource'

          it "`name` on instance, updates all relevant fields", ->
            rc.name = '$~!aNewName'
            expect(rc.name).to.equal 'aNewName'
            expect(rc.clazz.name).to.equal 'Module'
            expect(rc.type).to.equal 'module'
            expect(rc[' type']).to.equal 'module'
            expect(rc.isAfterTemplate).to.equal true

          it "`convFilename` as a '.changeExt' String, updates relevant fields", ->
            rc.convFilename = '.javascript'
            expect(rc[' convFilename']).to.equal '.javascript'
            expect(rc.convFilename).to.be.a.Function
            expect(rc.convFilename).to.not.be.equal rcSpec1[2]
            expect(rc.convFilename 'myFilename.coffee').to.equal 'myFilename.javascript'

          it "`convFilename` as a '.changeExt' String (srcFilename), updates relevant fields", ->
            rc.convFilename = '~.javascript'
            expect(rc[' convFilename']).to.equal '~.javascript'  # display value is the original
            expect(rc.convFilename).to.be.a.Function
            expect(rc.convFilename).to.not.be.equal rcSpec1[2]
            expect(rc.convFilename 'myFilename.coffee', 'mySrcFilename.coffee').to.equal 'mySrcFilename.javascript'

          it.skip "No RC added to registry", -> # blendConfigs-spec has run before reaching here... argh mocha!
            expect(_.keys(ResourceConverter.registry).length).to.equal initialRegistryKeys.length
            expect(_B.isEqualArraySet (_.keys ResourceConverter.registry), initialRegistryKeys).to.be.true # need set check
  null

  describe "ResourceConverter .clone():", ->
    rc1Clone = rc1.clone()

    it "is equal with original", ->
      expect(_.isEqual rc1, rc1Clone)
      expect(rc1.convert is rc1Clone.convert)
      expect(rc1.convFilename is rc1Clone.convFilename)
      expect(rc1Clone.convFilename('bla.coffee') is 'bla.js')

  describe "ResourceConverter.registry :", ->
    rc = rcClone = newRc = foundRc = undefined # 'declare' in closure to share in all `it` functions

    describe "Registering ResourceConverters basics:", ->

      it "Creates correct instance from rcSpec", ->
        rc = newRc = ResourceConverter.searchRegisterUpdate rcSpec1

      it "identical clones only update ", ->
        rcClone = rc.clone()
        expect(rc isnt rcClone).to.be.true
        deepEqual rc, expectedRc
        deepEqual rcClone, expectedRc
        newRc = ResourceConverter.searchRegisterUpdate rcClone
        expect(newRc).to.equal rc

      it "The instance is registered", ->
        expect(ResourceConverter.registry[rc.name]).to.be.equal rc
        expect(ResourceConverter.searchRegisterUpdate(rc.name) is rc)
        expect(ResourceConverter.searchRegisterUpdate(rcSpec1) is rc)

      it "Updates instance from another instance", ->
        rc = ResourceConverter.searchRegisterUpdate rcClone
        expect(rc).to.not.be.equal rcClone
        expect(rc).to.be.equal newRc
        deepEqual rc, expectedRc

      it "Updates instance from another instance, returned from a function", ->
        rc = ResourceConverter.searchRegisterUpdate -> rcClone
        expect(rc).to.not.be.equal rcClone
        expect(rc).to.be.equal newRc
        deepEqual rc, expectedRc

      it "Updates instance from a rcSpec, returned from nested functions", ->
        rc = ResourceConverter.searchRegisterUpdate -> -> -> rcSpec1
        expect(rc).to.not.be.equal rcSpec1
        expect(rc).to.be.equal newRc
        deepEqual rc, expectedRc

    describe "Searching for ResourceConverters:", ->

      it "The instance is retrieved via `search by name`", ->
        foundRc = ResourceConverter.searchRegisterUpdate rc.name
        expect(foundRc).to.be.equal rc
        deepEqual foundRc, expectedRc

      it "The instance is retrieved passing a function with `search by name` as context", ->
        foundRc = ResourceConverter.searchRegisterUpdate -> @ rc.name
        expect(foundRc).to.be.equal rc
        deepEqual foundRc, expectedRc

      it "some funky ->->->", ->
        foundRc = ResourceConverter.searchRegisterUpdate -> -> -> -> @ rc.name
        expect(foundRc).to.be.equal rc
        deepEqual foundRc, expectedRc

      it "Searched instance is updated via search flags", ->
        flagsToApply = '!#'
        expectedRcWithAppliedFlags = _.extend _.clone(expectedRc, true), {isAfterTemplate:true, ' type': 'text'}
        foundRc = ResourceConverter.searchRegisterUpdate -> @ flagsToApply + rc.name
        expect(foundRc).to.be.equal rc
        deepEqual foundRc, expectedRcWithAppliedFlags

      it "Searching via an Array, returns a registered RC", ->
        foundRc = ResourceConverter.searchRegisterUpdate rcSpec1
        expect(foundRc).to.be.equal rc
        deepEqual foundRc, expectedRc

      it "Registering a function that returns an Array, returns a registered RC", ->
        foundRc = ResourceConverter.searchRegisterUpdate -> @ rcSpec1
        expect(foundRc).to.be.equal rc
        deepEqual foundRc, expectedRc

      it "Searching via an Array spec of a new RC, returns a newly creatred/registered RC", ->
        rcspec = _.clone(rcSpec1, true)
        rcspec[0] = '$Livescript'
        rcspec[1] = ['**/*.ls']
        foundRc = ResourceConverter.searchRegisterUpdate -> -> @ rcspec #@todo : search and register do the same stuff - merge 'em ?
        expect(foundRc).to.not.be.equal rc
        expect(foundRc instanceof ResourceConverter).to.be.true
        foundRc.name = '#LivescriptTextResource'
        deepEqual foundRc,
          ' type': 'text'
          ' name': 'LivescriptTextResource'
          descr: 'No descr for ResourceConverter \'Livescript\''
          filez:[ '**/*.ls' ]
          convert: rcSpec1[2]
          ' convFilename': rcSpec1[3]   # display value
          _convFilename: rcSpec1[3]
          isTerminal: false
          isMatchSrcFilename: false
          isBeforeTemplate: false
          isAfterTemplate: false
          isAfterOptimize: false

        expect(foundRc.convFilename is rcSpec1[3]).to.be.true

      it "Searching for a non registered name throws error", ->
        expect(-> ResourceConverter.searchRegisterUpdate 'foo').to.throw Error

    describe "Registering ResourceConverters behavior: ", ->

      it "Registering a renamed already registered instance, renames its registry key", ->
        ResourceConverter.searchRegisterUpdate -> _.extend (@ rc.name), name: 'someOtherNewName'
        expect(ResourceConverter.registry['someOtherNewName']).to.equal newRc
        expect(ResourceConverter.searchRegisterUpdate 'someOtherNewName').to.equal newRc

      it "Renaming a registered instance, renames its registry key", ->
        newRc.name = 'someOtherName'
        expect(ResourceConverter.registry['someOtherName']).to.equal newRc
        expect(ResourceConverter.searchRegisterUpdate 'someOtherName').to.equal newRc

      it.skip "Two more RC are added to registry", -> # blendConfigs-spec has run before reaching here... argh mocha!
        expect(_.keys(ResourceConverter.registry).length).to.equal initialRegistryKeys.length + 2

    describe "accepts null and undefined, they just dont get registered", ->

      it "accepts null", ->
        deepEqual new ResourceConverter(null), {}
        deepEqual ResourceConverter.searchRegisterUpdate(null), {}

      it "accepts undefined", ->
        deepEqual new ResourceConverter(undefined), {}
        deepEqual ResourceConverter.searchRegisterUpdate(undefined), {}

