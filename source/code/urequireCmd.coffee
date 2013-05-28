_ = require 'lodash'
fs = require 'fs'
wrench = require "wrench"
_B = require 'uberscore'

_B.Logger::VERSION = if VERSION? then VERSION else '{NO_VERSION}' # 'VERSION' variable is added by grant:concat
l = new _B.Logger 'urequire/urequireCMD'

urequireCommander = require 'commander'
upath = require './paths/upath'
Build = require './process/Build'


# helpers
toArray = (val)->
  _.map val.split(','), (v)-> if _.isString(v) then v.trim() else v

config = {}

urequireCommander
#  .version(( JSON.parse require('fs').readFileSync "#{__dirname}/../../package.json", 'utf-8' ).version)
#  .usage('<templateName> <bundlePath> [options]')
  .version(l.VERSION) # 'var version = xxx' written by grunt's banner
  .option('-o, --outputPath <outputPath>', 'Output converted files onto this directory')
  .option('-f, --forceOverwriteSources', 'Overwrite *source* files (-o not needed & ignored)', undefined)
  .option('-v, --verbose', 'Print module processing information', undefined)
  .option('-d, --debugLevel <debugLevel>', 'Pring debug information (0-100)', undefined)
  .option('-n, --noExports', 'Ignore all web `rootExports` in module definitions', undefined)
  .option('-r, --webRootMap <webRootMap>', "Where to map `/` when running in node. On RequireJS its http-server's root. Can be absolute or relative to bundle. Defaults to bundle.", undefined)
  .option('-s, --scanAllow', "By default, ALL require('') deps appear on []. to prevent RequireJS to scan @ runtime. With --s you can allow `require('')` scan @ runtime, for source modules that have no [] deps (eg nodejs source modules).", undefined)
  .option('-a, --allNodeRequires', 'Pre-require all deps on node, even if they arent mapped to parameters, just like in AMD deps []. Preserves same loading order, but a possible slower starting up. They are cached nevertheless, so you might gain speed later.', undefined)
  .option('-t, --template <template>', 'Template (AMD, UMD, nodejs), to override a `configFile` setting. Should use ONLY with `config`', undefined)
  .option('-O, --optimize', 'Pass through uglify2 while saving/optimizing - currently works only for `combined` template, using r.js/almond.', undefined)
  .option('-C, --continue', 'NOT IMPLEMENTED Dont bail out while processing (mainly on module processing errors)', undefined)
  .option('-w, --watch', 'NOT IMPLEMENTED. Watch for changes in bundle files and reprocess those changed files.', undefined)
  .option('-i, --include', "NOT IMPLEMENTED. Process only modules/files in filters - comma seprated list/Array of Strings or Regexp's", toArray)
  .option('-j, --jsonOnly', 'NOT IMPLEMENTED. Output everything on stdout using json only. Usefull if you are building build tools', undefined)
  .option('-e, --verifyExternals', 'NOT IMPLEMENTED. Verify external dependencies exist on file system.', undefined)

for tmplt in Build.templates #['AMD', 'UMD', 'nodejs', 'combined']
  do (tmplt)->
    urequireCommander
      .command("#{tmplt} <bundlePath>")
      .description("Converts all modules in <bundlePath> using '#{tmplt}' template.")
      .action (bundlePath)->
        config.template = tmplt
        config.bundlePath = bundlePath

urequireCommander
  .command('config <configFiles...>')
  .action (cfgFiles)->
    config.derive = toArray cfgFiles

urequireCommander.on '--help', ->
  l.log """
  Examples:
                                                                                         \u001b[32m
    $ urequire UMD path/to/amd/moduleBundle -o umd/moduleBundle                          \u001b[0m
                    or                                                                   \u001b[32m
    $ urequire AMD path/to/moduleBundle -f                                               \u001b[0m
                    or                                                                   \u001b[32m
    $ urequire config path/to/configFile.json,anotherConfig.js,masterConfig.coffee -d 30 \u001b[0m

  *Notes: Command line values have precedence over configFiles;
          Values on config files on the left have precedence over those on the right (deeply traversing).*

  Module files in your bundle can conform to the *standard AMD* format: \u001b[36m
      // standard AMD module format - unnamed or named (not recommended by AMD)
      define(['dep1', 'dep2'], function(dep1, dep2) {...});  \u001b[0m

  Alternativelly modules can use the *standard nodejs/CommonJs* format: \u001b[36m
      var dep1 = require('dep1');
      var dep2 = require('dep2');
      ...
      module.exports = {my: 'module'} \u001b[0m

  Finally, a 'relaxed' format can be used (combination of AMD+commonJs), along with asynch requires, requirejs plugins, rootExports + noConflict boilerplate, bundleExports and much more - see the docs. \u001b[36m
      // uRequire 'relaxed' modules format
    - define(['dep1', 'dep2'], function(dep1, dep2) {
        ...
        // nodejs-style requires, with no side effects
        dep3 = require('dep3');
        ....
        // asynchronous AMD-style requires work in nodejs
        require(['someDep', 'another/dep'], function(someDep, anotherDep){...});

        // RequireJS plugins work on web + nodejs
        myJson = require('json!ican/load/requirejs/plugins/myJson.json');
        ....
        return {my: 'module'};
      }); \u001b[0m

  Notes:
    --forceOverwriteSources (-f) is useful if your sources are not `real sources`  eg. you use coffeescript :-).
      WARNING: -f ignores --outputPath

    - Your source can be coffeescript (more will follow) - .coffee files are internally translated to js.

    - configFiles can be written as a .js module, .coffee module, json and much more - see 'butter-require'

    uRequire version #{l.VERSION}
  """

urequireCommander.parse process.argv

#hack to get cmd options only ['verbose', 'scanAllow', 'outputPath', ...] etc
CMDOPTIONS = _.map(urequireCommander.options, (o)-> o.long.slice 2)

# overwrite anything on config's root by cmdConfig - BundleBuilder handles the rest
_.extend config, _.pick(urequireCommander, CMDOPTIONS)
delete config.version
l.log config

if _.isEmpty config
  l.err """
    No CMD options or config file specified.
    Not looking for any default config file in this uRequire version.
    Type -h if U R after help!"
  """
  l.log "uRequire version #{l.VERSION}"
else
  if config.debugLevel?
    _B.Logger.setDebugLevel config.debugLevel, 'urequire'
    l.debug 0, "Setting cmd _B.Logger.setDebugLevel(#{config.debugLevel}, 'urequire')"

  if config.verbose
    l.verbose 'uRequireCmd called with cmdConfig=\n', config

  config.done = (doneValue)->
    if (doneValue is true) or (doneValue is undefined)
      l.verbose "uRequireCmd done() successfully!"
    else
      l.err "uRequireCmd done(), with errors!"
      process.exit 1

  bb = new (require './urequire').BundleBuilder [config]
  bb.buildBundle()