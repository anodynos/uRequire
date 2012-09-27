#!/usr/bin/env coffee
_ = require('lodash')
cmd = require('commander');
l = require('./utils/logger')

options = {}

# helpers
toArray = (val)-> val.split(',')

cmd
  .version('0.0.8') #todo:read from package.json
  .usage('UMD <bundlePath> [options]')
  .option('-o, --outputPath <outputPath>', 'Output converted files onto this directory')
  .option('-f, --forceOverwriteSources', 'Overwrite *source* files (-o not needed & ignored)', false)
  .option('-n, --noExport', 'Ignore all web rootExports in module definitions', false)
  .option('-v, --verbose', 'Filling your screen with useless? info', false)
  .option('-r, --webRootMap <webRootMap>', "Where to map `/` when running in node. On RequireJS its http-server's root. Can be absolute or relative to bundle. Defaults to bundle.", false)
  .option('-s, --scanPrevent', "All require('') deps appear on [], preventing RequireJS scan @ runtime.", false)
  .option('-a, --allNodeRequires', 'Pre-require all deps on node, just like in AMD deps []', false)
  .option('-w, --watch', 'NOT IMPLEMENTED. Watch for changes in bundle files and reprocess those changed files.', toArray)
  .option('-l, --listOfModules', 'NOT IMPLEMENTED. Process only modules/files in comma sep list - supports wildcards?', toArray)
  .option('-j, --jsonOnly', 'NOT IMPLEMENTED. Output everything on stdout using json only.', false)
  .option('-e, --verifyExternals', 'NOT IMPLEMENTED. Verify external dependencies exist on file system.', false)
  .option('-m, --masterBundles <items>', 'NOT IMPLEMENTED. Comma seperated module bundles that are `imported.`.', toArray)
  .option('-i, --inline', 'NOT IMPLEMENTED. Use inline nodeRequire, so uRequire is not needed @ runtime.', false)
  .option('-W, --webOptimize', 'NOT IMPLEMENTED. Just re-define AMD with no UMD (and pass through r.js optimizer?)', false)


cmd
  .command('UMD <bundlePath...>')
  .description("Converts all .js modules in <bundlePath> using an UMD template")
  .action (bundlePath)->
    options.bundlePath = bundlePath

cmd.on '--help', ->
  console.log """
  Examples:
                                                                  \u001b[32m
    $ uRequire UMD path/to/amd/moduleBundle -o umd/moduleBundle   \u001b[0m
                    or                                            \u001b[32m
    $ uRequire UMD path/to/moduleBundle -f                        \u001b[0m

  Module files in your bundle must conform to the standard AMD format:
      // standard anonymous modules format                  \u001b[33m
    - define(['dep1', 'dep2'], function(dep1, dep2) {...})  \u001b[0m
                            or
      // named modules also work, but are NOT recommended                 \u001b[33m
    - define('moduleName', ['dep1', 'dep2'], function(dep1, dep2) {...})  \u001b[0m

  Notes:
    --forceOverwriteSources (-f) is useful if your sources are not `real sources`
      eg. you use coffeescript :-).
      WARNING: -f ignores --outputPath
"""

cmd.parse process.argv

#options.bundlePath = cmd.bundlePath

cmdOptions = _.map(cmd.options, (o)-> o.long.slice 2) #hack to get cmd options only
#copy over to 'options', to decouple uRequire from cmd.
options = _.defaults options, _.pick(cmd, cmdOptions)
options.version = cmd.version()

# to log or not to log
if not options.verbose then l.verbose = ->

if not options.bundlePath
  l.err """
    Quitting, no bundlePath specified.
    Use -h for help"""
  process.exit(1)
else
  if options.forceOverwriteSources
    options.outputPath = options.bundlePath
    l.verbose "Forced output to '#{options.outputPath}'"
  else
    if not options.outputPath
      l.err """
        Quitting, no --outputPath specified.
        Use -f *with caution* to overwrite sources."""
      process.exit(1)
    else
      if options.outputPath is options.bundlePath
        l.err """
          Quitting, outputPath == bundlePath.
          Use -f *with caution* to overwrite sources (no need to specify --outputPath).
          """
        process.exit(1);

uRequire = require('./uRequire')
uRequire.processBundle options
