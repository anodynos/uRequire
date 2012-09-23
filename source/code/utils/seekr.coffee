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
# JSONSelect does this just like we do with jQuery on the DOM!
#
# This is a different approach (version 0.0.0.1), where data+functions are used  to both
# filter (selectors), read ahead and decide what to do and then gather (retrievers)
#
# A 'seeker' is mainly a 'matcher' & a 'retriever'.
# Think of a 'matcher' as a selector in jQuery, or the where clause in SQL.
# Similarly 'retriever' is the select part, but in anabolics!
#
# todo: DOCUMENT it, make it more generic & seperate - a pattern perhaps ?
#
# Example
#mySeeker =
#   matcher:
#     call:
#       name: (it)-> it in ['require', 'define']
#       args: (it)-> it.length is 2
#
#   filterReader (data):
#     name: data.someVal1
#     args: data.someVal2
#
#   retriever: (name, args):->
#     log 'got a function with name #{name} and 2 args #{args}'

seekr = (seekers, data, ctx, _level = 0, _continue = true, _stack = [])->
  _level++
  if _level is 1 #some inits
    if not _(seekers).isArray() then seekers = [seekers] # just one, make it an array!

  if _continue
    _(data).each (dataItem)->
      if _(dataItem).isObject() or _(dataItem).isArray()
        _stack.push dataItem
        seekr seekers, dataItem, ctx, _level, _continue, _stack
        _stack.pop()
      else # do we have an interesting astItem, eg 'call', 'function' etc
        stacktop = _stack[_stack.length-1]
#        log '*************** \n', _level, '\n', stacktop

        # seekers matching & retrieving
        deadSeekers = []
        for skr in seekers
          if _level <= (skr.options?.maxLevel ? 999999) and #should be enough ;-)
          _level >= (skr.options?.minLevel ? 0)

            if skr.matcher[dataItem] # does matcher's 'head' regard dataItem ( eg astItem 'call') ?
              readDataItem = skr.filtersReader stacktop
              isMatch = true # optimistic
              for filterKey, filter of skr.matcher[dataItem] when isMatch
                itemToFilter = readDataItem[filterKey] # eg 'args'
                #   log 'filter key:', selectorKey, ' filter:', fltr, ' ast:', astRead[selectorKey]
                isMatch =
                  if _(filter).isArray()
                    itemToFilter in filter
                  else
                    if _(filter).isFunction()
                      filter itemToFilter
                    else #eg 'string'
                      filter is itemToFilter

              if isMatch # all filters where satisfied
                if not (skr.retriever.apply ctx, _.map readDataItem, (v)->v) # callback with the read astItem found. _stop if cb is false
                  deadSeekers.push skr # retriever killed you

        seekers = _.difference seekers, deadSeekers
        _continue = not _(seekers).isEmpty() # return true for lodash's each to go on
    , @ #bind this for each

seekrsimple = (seekers, data, stackreader, ctx, _level = 0, _continue = true, _stack = [])->
  _level++
  if _level is 1 #some inits
    if not _(seekers).isArray() then seekers = [seekers] # just one, make it an array!

  if _continue
    _(data).each (dataItem)->
      if _(dataItem).isObject() or _(dataItem).isArray()
        _stack.push dataItem
        seekrsimple seekers, dataItem, stackreader, ctx, _level, _continue, _stack
        _stack.pop()
      else # do we have an interesting astItem, eg 'call', 'function' etc
        stacktop = _stack[_stack.length-1]
        #log '*************** \n', _level, '\n', stacktop

        deadSeekers = []
        for skr in seekers
          if (_level >= skr.level?.min or not skr.level?.min) and (_level <= skr.level?.max or not skr.level?.max) #or not skr.level.min
            if _(skr['_' + dataItem]).isFunction() # does seeker regard dataItem ( eg astItem 'call') ?
              if stackreader[dataItem] #do we have a reader ?
                s = skr['_'+dataItem].call ctx, stackreader[dataItem](stacktop) # callback with the read astItem found.
                deadSeekers.push skr if s is 'stop'

        seekers = _.difference seekers, deadSeekers
        _continue = not _(seekers).isEmpty() # return true for lodash's each to go on



module.exports = seekrsimple