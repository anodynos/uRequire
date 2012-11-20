define [
        "chai",
        "abc/a-lib" # baseUrl must be set to "../.." or wherever abc is
    ], (
        chai
        alib
    )->
      assert = chai.assert
      expect = chai.expect

      describe "a-lib results to : ", ->
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
