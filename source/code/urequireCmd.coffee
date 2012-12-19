_ = require 'lodash'
_B = require 'uberscore'
_fs = require 'fs'
_wrench = require "wrench"

urequireCmd = require 'commander'
upath = require './paths/upath'
Logger = require './utils/Logger'
l = new Logger 'urequireCMD'

# helpers
toArray = (val)-> val.split(',')

config = {}

urequireCmd
#  .version(( JSON.parse require('fs').readFileSync "#{__dirname}/../../package.json", 'utf-8' ).version)
#  .usage('<templateName> <bundlePath> [options]')
  .version(VERSION) # 'var version = xxx' written by grunt's banner
  .option('-o, --outputPath <outputPath>', 'Output converted files onto this directory')
  .option('-f, --forceOverwriteSources', 'Overwrite *source* files (-o not needed & ignored)', undefined)
  .option('-v, --verbose', 'Print module processing information', undefined)
  .option('-n, --noExports', 'Ignore all web `rootExports` in module definitions', undefined)
  .option('-r, --webRootMap <webRootMap>', "Where to map `/` when running in node. On RequireJS its http-server's root. Can be absolute or relative to bundle. Defaults to bundle.", undefined)
  .option('-s, --scanAllow', "By default, ALL require('') deps appear on []. to prevent RequireJS to scan @ runtime. With --s you can allow `require('')` scan @ runtime, for source modules that have no [] deps (eg nodejs source modules).", undefined)
  .option('-a, --allNodeRequires', 'Pre-require all deps on node, even if they arent mapped to parameters, just like in AMD deps []. Preserves same loading order, but a possible slower starting up. They are cached nevertheless, so you might gain speed later.', undefined)
  .option('-C --continue', 'NOT IMPLEMENTED Dont bail out while processing (mainly on module processing errors)', undefined)
  .option('-u, --uglify', 'NOT IMPLEMENTED. Pass through uglify before saving.', undefined)
  .option('-w, --watch', 'NOT IMPLEMENTED. Watch for changes in bundle files and reprocess those changed files.', undefined)
  .option('-i, --include', "NOT IMPLEMENTED. Process only modules/files in filters - comma seprated list/Array of Strings or Regexp's", toArray)
  .option('-j, --jsonOnly', 'NOT IMPLEMENTED. Output everything on stdout using json only. Usefull if you are building build tools', undefined)
  .option('-e, --verifyExternals', 'NOT IMPLEMENTED. Verify external dependencies exist on file system.', undefined)
  .option('-t, --template <template>', 'Template (AMD, UMD, nodejs), to override a `config` setting. Used ONLY with `config`', undefined)
  #.option('-i, --inline', 'NOT IMPLEMENTED. Use inline nodeRequire, so urequire is not needed @ runtime.', false)

templates = ['AMD', 'UMD', 'nodejs', 'combine']
for tmplt in templates
  do (tmplt)->
    urequireCmd
      .command("#{tmplt} <bundlePath>")
      .description("Converts all modules in <bundlePath> using '#{tmplt}' template.")
      .action (bundlePath)->
        console.log 'urequireCmd Called:', tmplt, bundlePath
        config.template = tmplt
        config.bundlePath = bundlePath

urequireCmd
  .command('config <configFile>') #todo: move out of urequireCmd
  # todo: better/generic way to load from JSON, JS(object literal), Coffee(object literal) ?
  .action (cfgFile)->
    configFile = _fs.realpathSync cfgFile

    if upath.extname(configFile) is '.coffee' # #todo: add .coco etc
      js = (require 'coffee-script').compile (_fs.readFileSync configFile, 'utf-8'), bare:true
      _fs.writeFileSync upath.changeExt(configFile, '.js'), js, 'utf-8'

    config = require upath.changeExt configFile, '.js'
    _fs.unlinkSync upath.changeExt configFile, '.js'

    # Some basics options checks
    # assume bundlePath, if its empty
    config.bundle.bundlePath or= upath.dirname cfgFile
    # we allow --template for 'config' action, but there's no easy way to get it in commander
    if urequireCmd.template
      if urequireCmd.template in templates
        config.template = urequireCmd.template
      else
        l.err 'Wrong --template : ', urequireCmd.template

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

cmdOptions = _.map(urequireCmd.options, (o)-> o.long.slice 2) #hack to get cmd options only ['verbose', 'scanAllow'] etc
cmdConfig = {}
_.defaults cmdConfig, _.pick(urequireCmd, cmdOptions)

_.extend config, cmdConfig # overwrite anything on config's root by cmdConfig - BundleBuilder overwrites the rest.

urequire = require './urequire'
bp = new urequire.BundleBuilder config