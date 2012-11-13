console.log '\npathRelative-test started'

chai = require 'chai'
assert = chai.assert
expect = chai.expect

pathRelative = require "../code/paths/pathRelative"

describe "pathRelative(from, to)", ->

  it "should work in simple cases", ->
    from  = 'common\\a\\b'
    to    = 'common\\d\\e'

    expect(pathRelative from, to).to.equal "../../d/e"

    [from, to] = [to, from]
    expect(pathRelative from, to).to.equal "../../a/b"

  it "should blank on identical path", ->
    from = to = 'common/a/b'
    expect(pathRelative from, to).to.equal ""


  it "should dot4Current on small identical path", ->
    from = to = '/a'
    expect(pathRelative from, to, dot4Current:true).to.equal "."

  it 'should calc go-back & forth paths', ->
    from  = "/y/work/p/project/sourceTest/code/main"
    to    = "/y/work/p/project/source/code/main//"

    expect(pathRelative from, to).to.equal "../../../source/code/main"

    [from, to] = [to, from]
    expect(pathRelative from, to ).to.equal "../../../sourceTest/code/main"

  it 'should handle mixed unix & windows style seps & doubles `/`', ->
    from  = "/y///work\\p///project\\sourceTest///code/main\\//"
    to    = "/y\\work\\p\\project\\source\\code\\main"

    expect(pathRelative from, to).to.equal "../../../source/code/main"

    [from, to] = [to, from]
    expect(pathRelative from, to).to.equal "../../../sourceTest/code/main"

  it "should handle 'no path found' will null", ->
    expect(pathRelative 'junk\\a\\b', 'bin\\a\\b').to.be.a 'null'

  it 'should handle go-back/go forwards only correctly', ->
    from =  "/y/work/p/a/b/c/d/"
    to =    "/y/work/p"

    expect(pathRelative from, to).to.equal "../../../.."

    [from, to] = [to, from]
    expect(pathRelative from, to).to.equal "a/b/c/d"

  it 'should go from `root` to `to` and vise versa, with dot4Current', ->
    from =  "$"
    to =    "$/work/p"

    expect(pathRelative from, to, dot4Current:true).to.equal "./work/p"

    [from, to] = [to, from]
    expect(pathRelative from, to, dot4Current:true).to.equal "../.."

  it 'should consume pointless back and forths', ->
    from =  "/y/work/./p/./a/../b/./c/../../../" # I am back in work
    to =    "/y/work/p/./d/."

    expect(pathRelative from, to).to.equal "p/d"

    [from, to] = [to, from]
    expect(pathRelative from, to).to.equal "../.."

  it 'should handle it all together', ->
    from =  "/y/work/p/a/..\\b////c/../..\\../" # I am back in /work
    to =    "/y/work\\p/d/../n\\../m///e/f//"

    expect(pathRelative from, to).to.equal "p/m/e/f"

    [from, to] = [to, from]
    expect(pathRelative from, to).to.equal "../../../.."

  it 'should go off cliff (BEFORE the common path), ONLY if `to` says so', ->
    from = "/work/p/a/"
    to   = "/work/../../../f/g" # takes you *off the clif* - a level before `work`

    expect(pathRelative from, to).to.equal "../../../../../f/g"

    [from, to] = [to, from]
    expect(pathRelative from, to).to.equal null

  it 'should navigate back and forth correctly', ->
    from =  "/work1/../work2/g"
    to =    "/work1/p/a" #

    expect(pathRelative from, to).to.equal '../../work1/p/a'

  it 'should understand if `from` is ambiguously off the cliff ', ->
    from =  "/work/../../f/g" # takes you *off the clif* - a level before `work`. Path is lost!
    to =    "/work/p/a/"

    expect(pathRelative from, to).to.equal null
