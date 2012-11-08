#'text!data/abc.txt'
define [
    "text!example_abc.html" # relative to bundleRoot, working ok.
#    "text!./example_abc.html" # TODO: single dot isFileRelative to bundleRoot, working ok in node, FAILS ion Web - why?
#    "text!./example_abc.html!strip" #TODO: check this - here and in UMD!

    #TODO: fix these -> Check for RequireJS.bug or uRequire.fix.
#    "text!../data/abc.txt"  # when relative to bundleRoot (when isFileRelative) fails:
                       #  it goes 2 (or 3?) steps back!

#    "text!./../data/abc.txt" # also tried to fool it, but still too many steps back!
#    "text!data/abc.txt"       # also tried relative to THIS file, still no luck, it goes to bundleRoot!
  ], (
    abcHtml1
#    abcHtml2
#    abcHtmlStripped
#    abcText1
#    abcText2
#    abcText3
  )->
      """
      I am an AMD 'native' module!
      But I can be called from within a urequire UMD module!

      Some text I loaded:\n
      #{abcHtml1[0..20]}
    """
#    abcHtml1 #{if abcHtml1 is abcHtml2 then '===' else '!==' } abcHtml2

#    abcHtml1 #{abcHtml1}
#
#    abcHtml2 #{abcHtml2}
#
#    abcHtmlStripped #{abcHtmlStripped}

#    abcText1 #{abcText1 or ''}
#    abcText2 #{abcText2 or ''}
#    abcText3 #{abcText3 or ''}