_ = require 'lodash'
log = console.log

# A 'seeker' function, that recursivelly walks a tree (like AST)
# trying to find `matches` of the `seeker`, read ahead and filter candidate nodes,
# and if all are satisfied call `retriever` to gather data.
#
# It's not very generic yet, quite tied to AST structure for now!
#
# Theoretically, we could parse JavaScript, JSON and anything else, extracting information
# via selectors/matchers & retrievers.
#
# JSONSelect does this in a way similar jQuery does on the DOM!
#
# This is a different approach (version 0.0.0.1), where data+functions are used  to both
# filter (selectors), read ahead and decide what to do and then gather (retrievers)
#
#
#
seekr = (seekers, data, stackreader, ctx, _level = 0, _continue = true, _stack = [])->
  _level++
  if _level is 1 #some inits
    if not _.isArray(seekers) then seekers = [seekers] # just one, make it an array!
  if _continue
    _(data).each (dataItem)->
      if _.isObject(dataItem) or _.isArray(dataItem)
        _stack.push dataItem
        seekr seekers, dataItem, stackreader, ctx, _level, _continue, _stack
        _stack.pop()
      else # do we have an interesting astItem, eg 'call', 'function' etc
        stacktop = _stack[_stack.length-1]
        deadSeekers = []
        for skr in seekers
          if _level >= (skr.level?.min ? 0) and _level <= (skr.level?.max ? 99999)
            if _.isFunction(skr['_'+dataItem]) # does seeker regard dataItem ( eg astItem 'call') ?
              if stackreader[dataItem] #do we have a reader ?
                s = skr['_'+dataItem].call ctx, stackreader[dataItem](stacktop) # callback with the read astItem found.
                deadSeekers.push skr if s is 'stop'

        seekers = _.difference seekers, deadSeekers
        _continue = not _.isEmpty(seekers) # return true for lodash's each to go on

module.exports = seekr




