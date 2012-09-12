log = console.log
#log process.argv
cmd = require('commander');
_ = require('underscore')

options = {}

# helpers
toArray = (val)-> val.split(',')

cmd
  .version('0.0.1')
  .usage('[options] <bundlePath...>')
  .option('-i, --imports <items>', 'Comma seperated module bundles to import.', toArray)
  .option('-f, --forceOverwriteSources', 'Overwrite bundle source* files. (*Useful if not real `sources` eg. you use coffeescript :-). WARNING: it ignores -o even if passed.')
  .option('-o --outputPath <outputPath>', 'Output files on this directory')
  .option('-n, --noExports', 'Ignore all exports in module definitions')


cmd
  .command('* <bundlePath>')
  .description('UMDify bundle in <bundlePath>')
  .action (bundlePath)->
    #log "bundlePath = #{bundlePath}" #", outputPath = #{cmd.outputPath}"
    options.bundlePath = bundlePath
    log "myRequire: processing modules from bundle '#{options.bundlePath}'"

cmd.on '--help', ->
  console.log """
    Examples:

      $ myRequire path/to/amd/module umd/module
        - UMDify *.js in path

      $ myRequire path/to/amd/module -f
   """

cmd.parse process.argv

#copy over to 'options', to decouple myRequire from cmd.
cmdOptions = _.map(cmd.options, (o)-> o.long.slice 2)
options = _.defaults options, _.pick(cmd, cmdOptions)
options.version = cmd.version()

if options.forceOverwriteSources
  options.outputPath = options.bundlePath
  log "myRequire: forced output to '#{options.outputPath}'"

# checks everything? is OK
if not options.outputPath
  log "myRequire: quitting, no -outputPath specified. Use -f *with caution* to overwrite sources."
else
  if options.outputPath is options.bundlePath
    log "myRequire: quitting, outputPath == bundlePath. Use -f *with caution* to overwrite sources."
  else
    myRequire = require('./myRequire')
    myRequire.processBundle options