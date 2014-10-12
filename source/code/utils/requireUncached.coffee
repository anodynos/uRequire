# helper - uncaching require
# based on http://stackoverflow.com/questions/9210542/node-js-require-cache-possible-to-invalidate
# Removes a nodejs module from the cache
module.exports = (name)->
  # Runs over the cache to search for all the cached nodejs modules files
  searchCache = (name, callback)->
    # Resolve the module identified by the specified name
    mod = require.resolve(name)
    # Check if the module has been resolved and found within the cache
    if mod and ((mod = require.cache[mod]) isnt undefined)
      # Recursively go over the results
      (run = (mod)->
        # Go over each of the module's children and run over it
        mod.children.forEach (child)-> run child
        # Call the specified callback providing the found module
        callback mod
      ) mod

  # Run over the cache looking for the files loaded by the specified module name
  searchCache name, (mod)-> delete require.cache[mod.id]
  require name