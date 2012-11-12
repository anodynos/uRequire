define [
        "chai",
        "../deps/main"
        "../abc/a-lib"
    ], (
        chai
        main
        alib
    )->
      assert = chai.assert
      expect = chai.expect

      describe "main", ->
        it "main = {added: 42, multiplied:440, message: undefined}", ->
          expect(main).to.be.deep.equal
            added:42
            multiplied:440
            message: undefined


      describe "a-lib", ->
        result =
          a: 'a'
          b:
            b: 'b'
            c:
              c: 'c'
              d:
                d: 'd123'
        it "alib = {a:'a',b:{b:'b',c:{c:'c',d:{d:'d123'}}}} #{result}", ->
          expect(alib).to.be.deep.equal result
