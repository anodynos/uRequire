  # Find the path that connects two paths
  # eg. from  = "Y:/WebStormWorkspace/p/uGetScore/sourceTest/code/main"
  #     to    = "Y:/WebStormWorkspace/p/uGetScore/source/code/main/"
  #     results "../../../source/code/main"
  #
  #  Features @ a glance
  #  - similar to (but extending?) path.relative
  #  - normalization : It understands `a/b/..` is `a` and normalizes paths while calculating connecting path
  #  - paths can be unix, windows and mixed.
  #
  # @param from {String} the starting path
  # @param from {to} the destination path
  # @option dot4Current ????
  # @return {String} the path that connects from -> to
module.exports = (from, to, options)->
    options or= {}
    #console.log "from: #{from}, to: #{to}"
    # replace '\' with '/' and split 'em (to an array). I lOOOOOOve coffeescript!
    [from, to] =
      for path in [from, to]
        (path.replace /\\/g, '/').split('/')

    #remove empty path parts (eg the last `/`, or `//` and `.`)
    [from, to] =
      for path in [from, to]
        (part for part in path when part not in ['', '.'])

    for path in [from, to]
      if path.length is 0 then return null

    # store common paths parts.
    commonPath = []
    while (lastFrom = from.shift()) is (lastTo = to.shift()) and (from.length>0 or to.length>0)
      commonPath.push lastFrom

    finalPath = []
    if commonPath.length > 0
      if lastFrom isnt lastTo #exact same path case
        if lastFrom then from.unshift lastFrom
        if lastTo then to.unshift lastTo

        for part in from
          if part isnt '..'
            finalPath.push '..' # go one step back on our finalPath
          else
            if finalPath.length > 0
              finalPath.pop()
            else
              if commonPath.length > 0
                to.unshift commonPath.pop() #add it later, as a pathpart to follow :-)
              else
                return null # fell off the cliff

        for part in to
          if part isnt '..'
            finalPath.push "#{part}"
          else
            if finalPath[finalPath.length-1] is '..'
              finalPath.push '..' #the part actually, that is '..'
            else
              finalPath.pop();

      if options.dot4Current #todo decide if needed, default value, add specs
        if finalPath[0] isnt '..' # if path isnt backwards
          finalPath.unshift '.'

      return finalPath.join "/"
    else
      return null # no path found


#_path = require("path")
#from =  "Y:/work/p/a/../b/c/../../../" # I am back in work
#to =    "Y:/work/p/d"
#
#console.log '\n result:', calcPath from, to
#console.log '\n _path', _path.relative from, to
#[from, to] = [to, from]
##console.log '\n result:', calcPath from, to