define [
        "chai",
        "../deps/main",
    ], (chai, main, mainn)->
      assert = chai.assert
      expect = chai.expect

      describe "main", ->
        it "main is a {added: 42, multiplied:440, message: undefined}", ->
          expect(main).to.be.deep.equal
            added:42
            multiplied:440
            message: undefined


