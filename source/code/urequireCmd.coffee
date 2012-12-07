_ = require 'lodash'
urequireCmd = require 'commander'
l = require './utils/logger'
upath = require './paths/upath'
_fs = require 'fs'
_wrench = require "wrench"



options = {}

# helpers
toArray = (val)-> val.split(',')

console.log

urequireCmd
#  .version(( JSON.parse require('fs').readFileSync "#{__dirname}/../../package.json", 'utf-8' ).version)
#  .usage('<templateName> <bundlePath> [options]')
  .version(version) # 'var version = xxx' written by grunt's banner
  .option('-o, --outputPath <outputPath>', 'Output converted files onto this directory')
  .option('-f, --forceOverwriteSources', 'Overwrite *source* files (-o not needed & ignored)', false)
  .option('-v, --verbose', 'Print module processing information', false)
  .option('-n, --noExports', 'Ignore all web `rootExports` in module definitions', false)
  .option('-r, --webRootMap <webRootMap>', "Where to map `/` when running in node. On RequireJS its http-server's root. Can be absolute or relative to bundle. Defaults to bundle.", false)
  .option('-s, --scanAllow', "By default, ALL require('') deps appear on []. to prevent RequireJS to scan @ runtime. With --s you can allow `require('')` scan @ runtime, for source modules that have no [] deps (eg nodejs source modules).", false)
  .option('-a, --allNodeRequires', 'Pre-require all deps on node, even if they arent mapped to parameters, just like in AMD deps []. Preserves same loading order, but a possible slower starting up. They are cached nevertheless, so you might gain speed later.', false)
  .option('-C --Continue', 'Dont bail out while processing (mainly on module processing errors)', true)
  .option('-u, --uglify', 'NOT IMPLEMENTED. Pass through uglify before saving.', false)
  .option('-w, --watch', 'NOT IMPLEMENTED. Watch for changes in bundle files and reprocess those changed files.', toArray)
  .option('-l, --listOfModules', 'NOT IMPLEMENTED. Process only modules/files in comma sep list - supports wildcards?', toArray)
  .option('-j, --jsonOnly', 'NOT IMPLEMENTED. Output everything on stdout using json only. Usefull if you are building build tools', false)
  .option('-e, --verifyExternals', 'NOT IMPLEMENTED. Verify external dependencies exist on file system.', false)
  #.option('-i, --inline', 'NOT IMPLEMENTED. Use inline nodeRequire, so urequire is not needed @ runtime.', false)


urequireCmd
  .command('UMD <bundlePath>')
  .description("Converts all .js modules in <bundlePath> using an UMD template")
  .action (bundlePath)->
    options.bundlePath = bundlePath
    options.template = 'UMD'

urequireCmd
  .command('AMD <bundlePath>')
  .description("Converts with an AMD template, pass through r.js optimizer")
  .action (bundlePath)->
    options.bundlePath = bundlePath
    options.template = 'AMD'

    # read webOptimize param
    for cmd in urequireCmd.commands
      if cmd._name is 'AMD' and cmd.webOptimize
        options.webOptimize = cmd.webOptimize

urequireCmd
  .command('nodejs <bundlePath>')
  .description("")
  .action (bundlePath)->
    options.bundlePath = bundlePath
    options.template = 'nodejs'


urequireCmd
  .command('config <configFile>') #todo: move out of urequireCmd

  # todo: better/generic way to load from JSON, JS(object literal), Coffee(object literal) ?
  .action (configFile)->
    cfg = _fs.realpathSync configFile

    if upath.extname(cfg) is '.coffee' # #todo: add .coco etc
      js = (require 'coffee-script').compile (_fs.readFileSync cfg, 'utf-8'), bare:true
      _fs.writeFileSync upath.changeExt(cfg, '.js'), js, 'utf-8'

    options = require upath.changeExt(cfg, '.js')

    _fs.unlinkSync upath.changeExt(cfg, '.js')

    # Some basics options checks
    # assume bundlePath, if its empty
    options.bundlePath ?= upath.dirname configFile
    # add configFile to exclude'd files ?
    (options.exclude ?= []).push upath.relative(options.bundlePath, configFile)
    (options.exclude ?= []).push upath.relative(options.bundlePath, upath.changeExt(configFile, '.js'))


urequireCmd.on '--help', ->
  console.log """
  Examples:
                                                                  \u001b[32m
    $ urequire UMD path/to/amd/moduleBundle -o umd/moduleBundle   \u001b[0m
                    or                                            \u001b[32m
    $ urequire UMD path/to/moduleBundle -f                        \u001b[0m

  Module files in your bundle can conform to the standard AMD format:
      // standard anonymous modules format                  \u001b[33m
    - define(['dep1', 'dep2'], function(dep1, dep2) {...})  \u001b[0m
                            or
      // named modules also work, but are NOT recommended                 \u001b[33m
    - define('moduleName', ['dep1', 'dep2'], function(dep1, dep2) {...})  \u001b[0m

    A 'relaxed' format can be used, see the docs.

  Alternativelly modules can use the nodejs module format:
    - var dep1 = require('dep1');
      var dep2 = require('dep2');
      ...
      module.exports = {my: 'module'}

  Notes:
    --forceOverwriteSources (-f) is useful if your sources are not `real sources`
      eg. you use coffeescript :-).
      WARNING: -f ignores --outputPath
"""

urequireCmd.parse process.argv

cmdOptions = _.map(urequireCmd.options, (o)-> o.long.slice 2) #hack to get cmd options only
#copy over to 'options', to decouple urequire from cmd.
options = _.defaults options, _(urequireCmd).pick(cmdOptions)
options.version = urequireCmd.version()

# to log or not to log
if not options.verbose then l.verbose = ->

urequire = require './urequire'
bp = new urequire.Bundle(options)