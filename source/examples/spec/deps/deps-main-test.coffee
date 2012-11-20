define [
        "chai",
        "main" # baseUrl must be set to "../../deps/" or wherever deps is
    ], (
        chai
        main
    )->
      assert = chai.assert
      expect = chai.expect

      describe "main", ->
        it "main = {added: 42, multiplied:440, message: undefined}", ->
          expect(main).to.be.deep.equal
            added:42
            multiplied:440
            message: undefined
