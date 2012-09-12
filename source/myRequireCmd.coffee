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
  .option('-f, --forceOverwriteSources', 'Overwrite bundle source* files. (*Useful if not real `sources` eg. you use coffeescript :-)')
  .option('-o --outputPath', 'Output files on this directory')
  .option('-ne, --noExports', 'Ignore all exports in module definitions')


cmd
  .command('* <bundlePath>')
  .description('UMDify bundle in <bundlePath>')
  .action (bundlePath)->
    log "bundlePath = #{bundlePath}" #", outputPath = #{cmd.outputPath}"
    options.bundlePath = bundlePath

cmd.on '--help', ->
  console.log """
    Examples:

      $ myRequire path/to/amd/module umd/module
        - UMDify *.js in path

        $ myRequire path/to/amd/module -f
   """

cmd.parse process.argv

if cmd.forceOverwriteSources
  options.outputPath = cmd.bundlePath

myRequire = require('./myRequire')
options = _.extend options, _.pick(cmd, 'outputpath', 'imports', 'noExports')
myRequire options
