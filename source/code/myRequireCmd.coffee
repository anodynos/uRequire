_ = require('underscore')
cmd = require('commander');
l = require('./utils/logger')

options = {}

# helpers
toArray = (val)-> val.split(',')

cmd
  .version('0.0.1')
  .usage('[options] <bundlePath>')
  #.option('-i, --imports <items>', 'Comma seperated module bundles to import.', toArray)
  .option('-o, --outputPath <outputPath>', 'Output converted files on this directory')
  .option('-f, --forceOverwriteSources', 'Overwrite source* files')
  .option('-n, --noExports', 'Ignore all exports in module definitions')
  .option('-v, --verbose', 'Fill you screen with useless? info', true)


cmd
  .command('* <bundlePath...>')
#  .description('UMDify bundle in <bundlePath>')
  .action (bundlePath)->
    options.bundlePath = bundlePath

cmd.on '--help', ->
  console.log """
    Examples:

      $ myRequire path/to/amd/moduleBundle -o umd/moduleBundle

                or

      $ myRequire path/to/moduleBundle -f


    * Notes:
      --forceOverwriteSources (-f) is useful if your sources
        are not `real sources` eg. you use coffeescript :-).
        Note: -f ignores --outputPath
     """

cmd.parse process.argv

cmdOptions = _.map(cmd.options, (o)-> o.long.slice 2) #hack to get cmd options only
#copy over to 'options', to decouple myRequire from cmd.
options = _.defaults options, _.pick(cmd, cmdOptions)
options.version = cmd.version()

# to log or not to log
if not options.verbose then l.log = ->

if not options.bundlePath
  l.err """
    Quitting, no bundlePath specified.
    Use -h for help"""
  process.exit(1)
else
  if options.forceOverwriteSources
    options.outputPath = options.bundlePath
    l.log "Forced output to '#{options.outputPath}'"
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

l.log "processing modules from bundle '#{options.bundlePath}'"
myRequire = require('./myRequire')
myRequire.processBundle options