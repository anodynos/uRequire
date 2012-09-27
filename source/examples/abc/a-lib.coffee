define ['b/b-lib'], (b)->
  console.log 'started a'

  if false                    # not actually required at runtime,
    d = require 'b/c/d/d-lib' # but d-lib should be added to [],
                              # as fileRelative './b/c/d/d-lib' right after a 'require'
  return a: 'a', b: b
