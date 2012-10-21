urequire:
  rootExport:'rootB' #rootB should become window.rootB global variable on the web side

define ['./c/c-lib'], (c)->
  console.log 'started b'

  if true
    require ['b/c/d/d-lib'], (d)->         # d-lib should be just changed to fileRelative
      console.log 'got b/c/d/d-lib = ', d  # but since its async it's NOT need in []

  cc = require 'b/c/c-lib' #same './c/c-lib' as above, bundleRelative
  if cc is c
    console.log 'cc === c'

  return b: 'b', c: cc
