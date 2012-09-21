uRequire:
  rootExport:'rootB'

define ['./c/c-lib'], (c)->
  console.log 'started b'

  if (Math.random() * 100) > 50
    require ['b/c/d/d-lib'], (d)->
      console.log 'got b/c/d/d-lib = ', d

  cc = require 'b/c/c-lib' #same a listed above, absolute version
  if cc is c
    console.log 'cc === c'

  return b: 'b', c: cc
