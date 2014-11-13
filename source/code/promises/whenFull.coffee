_ = (_B = require 'uberscore')._

When = require 'when'

# augmenting When
whenLibs = ['keys', 'function', 'node', 'callbacks', 'generator', 'sequence', 'pipeline', 'parallel', 'poll', 'guard']
for wlib in whenLibs
  if _.isUndefined When[wlib]
    When[wlib] = require "when/#{wlib}"

extraFunctions =
  each: (collection, handler)->
    if _B.isHash collection
      iterArray = _.keys collection
      isArray = false
    else
      if _.isArray collection
        iterArray = collection
        isArray = true
      else
        return When.reject new Error "When.each: collection is neither [] or {}."

    When.iterate(
      (i)-> i + 1
      (i)-> !(i < iterArray.length)
      (i)->
        if isArray
          idxOrKey = i
        else
          idxOrKey = iterArray[i]

        handler collection[idxOrKey], idxOrKey # called with (val, idx|key)
      0
    )

for name, extraFn of extraFunctions
  if _.isUndefined When[name]
    When[name] = extraFn

module.exports = When