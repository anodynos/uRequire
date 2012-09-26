define ['b/b-lib'], (b)->
  console.log 'started a'

  if false                    # not actually required at runtime,
    d = require 'b/c/d/d-lib' # but b/c/d/d-lib should be changed to fileRelative ./b/c/d/d-lib
                              # & to added to [], right after 'require' is introduced

  return a: 'a', b: b
