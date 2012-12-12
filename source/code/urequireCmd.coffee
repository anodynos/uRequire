_ = require 'lodash'
_B = require 'uberscore'
_fs = require 'fs'
_wrench = require "wrench"

urequireCmd = require 'commander'
upath = require './paths/upath'

l = new (require './utils/Logger') 'urequireCMD'
uRequireConfigMasterDefaults = require './config/uRequireConfigMasterDefaults'

config =
  bundle:{}
  build:{}

# helpers
toArray = (val)-> val.split(',')

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
  .option('-C --continue', 'NOT IMPLEMENTED Dont bail out while processing (mainly on module processing errors)', true)
  .option('-u, --uglify', 'NOT IMPLEMENTED. Pass through uglify before saving.', false)
  .option('-w, --watch', 'NOT IMPLEMENTED. Watch for changes in bundle files and reprocess those changed files.', toArray)
  .option('-i, --include', "NOT IMPLEMENTED. Process only modules/files in filters - comma seprated list/Array of Strings or Regexp's", toArray)
  .option('-j, --jsonOnly', 'NOT IMPLEMENTED. Output everything on stdout using json only. Usefull if you are building build tools', false)
  .option('-e, --verifyExternals', 'NOT IMPLEMENTED. Verify external dependencies exist on file system.', false)
  #.option('-i, --inline', 'NOT IMPLEMENTED. Use inline nodeRequire, so urequire is not needed @ runtime.', false)

templates = ['AMD', 'UMD', 'nodejs', 'combine']
for template in templates
  do (template)->
    urequireCmd
      .command("#{template} <bundlePath>")
      .description("Converts all modules in <bundlePath> using '#{template}' template.")
      .action (bundlePath)->
        console.log 'urequireCmd Called:', template, bundlePath
        config.build.template = template
        config.bundle.bundlePath = bundlePath

urequireCmd
  .command('config <configFile>') #todo: move out of urequireCmd

  # todo: better/generic way to load from JSON, JS(object literal), Coffee(object literal) ?
  .action (cfgFile)->
    configFile = _fs.realpathSync cfgFile

    if upath.extname(configFile) is '.coffee' # #todo: add .coco etc
      js = (require 'coffee-script').compile (_fs.readFileSync configFile, 'utf-8'), bare:true
      _fs.writeFileSync upath.changeExt(configFile, '.js'), js, 'utf-8'

    config = require upath.changeExt(configFile, '.js')

    _fs.unlinkSync upath.changeExt(configFile, '.js')

    # Some basics options checks
    # assume bundlePath, if its empty
    config.bundle.bundlePath or= upath.dirname cfgFile

    # ? add configFile to exclude'd files ?
#    (options.exclude ?= []).push upath.relative(options.bundlePath, configFile)
#    (options.exclude ?= []).push upath.relative(options.bundlePath, upath.changeExt(configFile, '.js')) # why


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

#copy over to 'config', to decouple urequire from cmd.
#todo: read simple_cfg and options into cfg

cmdOptions = _.map(urequireCmd.options, (o)-> o.long.slice 2) #hack to get cmd options only

bundleKeys = _.keys uRequireConfigMasterDefaults.bundle
buildKeys = _.keys uRequireConfigMasterDefaults.build

_.defaults config.bundle, _B.go urequireCmd, fltr:(v,k)-> k in bundleKeys
_.defaults config.build, _B.go urequireCmd, fltr:(v,k)-> k in buildKeys

config.bundle.VERSION = urequireCmd.version()

# to log or not to log
if not config.verbose then l.verbose = ->

console.log config

urequire = require './urequire'
bp = new urequire.BundleBuilder config