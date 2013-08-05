chai = require 'chai'
assert = chai.assert
expect = chai.expect

_B = require 'uberscore'
l = new _B.Logger 'urequire/ResourceConverter-spec'

_ = require 'lodash'

BundleFile =   require '../../code/fileResources/BundleFile'
#FileResource = require '../../code/fileResources/FileResource'
#TextResource = require '../../code/fileResources/TextResource'
#Module =       require '../../code/fileResources/Module'

ResourceConverter = BundleFile.requireUncached '../../code/config/ResourceConverter'

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
  isTerminal: false
  isAfterTemplate: false
  isMatchSrcFilename: false

initialRegistryKeys = _.keys ResourceConverter.registry

describe 'ResourceConverter creation, cloning & updating:', ->
  rc1 = new ResourceConverter rcSpec1
  rc2 = rc1.clone()

  for rc, rcIdx in [rc1, rc2, rc2.clone()]
    do (rc, rcIdx)->
      describe "ResourceConverter creation & updates (for #{if rcIdx then 'clone() #'+rcIdx else 'original instance'}):", ->

        it "created correct RC instance from an rc-spec", ->
          expect(rc).to.deep.equal expectedRc
          expect(rc.clazz.name).to.equal 'Module'
          expect(rc.type).to.equal 'module'
          expect(rc.convFilename).to.equal rcSpec1[3]

        it "all clones are equal", -> expect(rc).to.deep.equal rc.clone()

        it "updating `type` on instance, updates hidden clazz field", ->
          rc.type = 'text'
          expect(rc[' type']).to.equal 'text'
          expect(rc['type']).to.equal 'text'
          expect(rc.clazz.name).to.equal 'TextResource'

        it "updating `name` on instance, updates all relevant fields", ->
          rc.name = '$~!aNewName'
          expect(rc.clazz.name).to.equal 'Module'
          expect(rc.type).to.equal 'module'
          expect(rc[' type']).to.equal 'module'
          expect(rc.isAfterTemplate).to.equal true

        it "updating `convFilename` as a '.changeExt' String, updates relevant fields", ->
          rc.convFilename = '.javascript'
          expect(rc[' convFilename']).to.equal '.javascript'
          expect(rc.convFilename).to.be.a.Function
          expect(rc.convFilename).to.not.be.equal rcSpec1[2]
          expect(rc.convFilename 'myFilename.coffee').to.equal 'myFilename.javascript'

        it "updating `convFilename` as a '.changeExt' String (srcFilename), updates relevant fields", ->
          rc.convFilename = '~.javascript'
          expect(rc[' convFilename']).to.equal '~.javascript'  # display value is the original
          expect(rc.convFilename).to.be.a.Function
          expect(rc.convFilename).to.not.be.equal rcSpec1[2]
          expect(rc.convFilename 'myFilename.coffee', 'mySrcFilename.coffee').to.equal 'mySrcFilename.javascript'

        it "No RC added to registry", ->
          expect(_.keys(ResourceConverter.registry).length).to.equal initialRegistryKeys.length
          expect(_B.isEqualArraySet (_.keys ResourceConverter.registry), initialRegistryKeys).to.be.true # need set check
  null

describe "ResourceConverter registry (static `registry` {} & `register` & `search` functions):", ->
  rc = rcClone = newRc = foundRc = undefined # 'declare' in closure to share in all `it` functions

  describe "Registering ResourceConverters basics:", ->

    it "Creates correct instance from rcSpec", ->
      rc = newRc = ResourceConverter.register rcSpec1
      rcClone = rc.clone()
      expect(rc).to.deep.equal expectedRc

    it "The instance is registered", ->
      expect(ResourceConverter.registry[rc.name]).to.be.equal rc

    it "Updates instance from another instance", ->
      rc = ResourceConverter.register rcClone
      expect(rc).to.not.be.equal rcClone
      expect(rc).to.be.equal newRc
      expect(rc).to.deep.equal expectedRc

    it "Updates instance from another instance, returned from a function", ->
      rc = ResourceConverter.register -> rcClone
      expect(rc).to.not.be.equal rcClone
      expect(rc).to.be.equal newRc
      expect(rc).to.deep.equal expectedRc

    it "Updates instance from a rcSpec, returned from a function", ->
      rc = ResourceConverter.register rcSpec1
      expect(rc).to.not.be.equal rcSpec1
      expect(rc).to.be.equal newRc
      expect(rc).to.deep.equal expectedRc

  describe "Searching for ResourceConverters:", ->

    it "The instance is retrieved via `search by name`", ->
      foundRc = ResourceConverter.search rc.name
      expect(foundRc).to.be.equal rc
      expect(foundRc).to.deep.equal expectedRc

    it "The instance is retrieved on 'register', passing a function with `search by name` as context", ->
      foundRc = ResourceConverter.register -> @ rc.name
      expect(foundRc).to.be.equal rc
      expect(foundRc).to.deep.equal expectedRc

    it "some funky ->->->", ->
      foundRc = ResourceConverter.register -> -> -> -> @ rc.name
      expect(foundRc).to.be.equal rc
      expect(foundRc).to.deep.equal expectedRc

    it "Searched instance is updated via search flags", ->
      flagsToApply = '!#'
      expectedRcWithAppliedFlags = _.extend _.clone(expectedRc, true), {isAfterTemplate:true, ' type': 'text'}
      foundRc = ResourceConverter.register -> @ flagsToApply + rc.name
      expect(foundRc).to.be.equal rc
      expect(foundRc).to.deep.equal expectedRcWithAppliedFlags

    it "Searching for a non registered name throws error", ->
      try
        ResourceConverter.search 'foo'
      catch err
      expect(err instanceof Error).to.be.true

  describe "Registering ResourceConverters behavior: ", ->

    it "Registration with same name, updates (but not overwrites) instance", ->
      newRc = ResourceConverter.register rcSpec1
      expect(newRc).to.be.equal rc
      expect(newRc).to.deep.equal rcClone # original has been updated in previous test

    it "Registering a renamed already registered instance, renames its registry key", ->
      ResourceConverter.register -> _.extend (@ rc.name), name: 'someOtherNewName'
      expect(ResourceConverter.registry['someOtherNewName']).to.equal newRc
      expect(ResourceConverter.search 'someOtherNewName').to.equal newRc

    it "Renaming a registered instance, renames its registry key", ->
      newRc.name = 'someOtherName'
      expect(ResourceConverter.registry['someOtherName']).to.equal newRc
      expect(ResourceConverter.search 'someOtherName').to.equal newRc

    it "Just one more RC is added to registry", ->
      expect(_.keys(ResourceConverter.registry).length).to.equal initialRegistryKeys.length + 1

  describe "accepts null and undefined, they just dont get registered", ->
    it "accepts null", ->
      expect(new ResourceConverter null).to.deep.equal {}
      expect(ResourceConverter.register null).to.deep.equal {}

    it "accepts undefined", ->
      expect(new ResourceConverter undefined).to.deep.equal {}
      expect(ResourceConverter.register undefined).to.deep.equal {}

