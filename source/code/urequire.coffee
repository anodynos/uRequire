class Urequire
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props

  @property Bundle: get:-> require "./process/Bundle"
  @property BundleBuilder: get:-> require "./process/BundleBuilder"

  # used by UMD-transformed modules when running on nodejs
  @property NodeRequirer: get:-> require './NodeRequirer'

module.exports = new Urequire

Logger = require './utils/Logger'
UModule = require "./process/UModule"
Bundle = require "./process/Bundle"
Build = require './process/Build'
BundleBuilder = require "./process/BundleBuilder"

#YADC = require('YouAreDaChef').YouAreDaChef

#lu = new Logger 'UModule-YADC'
#YADC UModule)
#  .after '_constructor', (match, filename)->
#    lu.log "UModule created:", filename

#lb = new Logger 'Bundle-YADC'
#YADC(Bundle)
#  .before /_constructor/, (match, bundleCfg)->
#    lb.log "\n # Bundle created: bundleCfg = \n", (JSON.stringify bundleCfg, null, ' ')
#
#lbuild = new Logger 'Build-YADC'
#YADC(Build)
#  .before /_constructor/, (match, buildCfg)->
#    lbuild.log "\n # Build created: buildCfg = \n", (JSON.stringify buildCfg, null, ' ')

#lm = new Logger 'UModule-YADC'
#YADC(UModule)
#  .before /_constructor/, (match, bundle, filename, sourcecode)->
#    lm.log "\n # UModule created: bundle = \n", bundle

#lb2 = new Logger 'BundleBuilder-YADC'
#YADC BundleBuilder)
#  .before /_constructor/, (match, cfg)->
#    lb2.log "\n # BundleBuilder created: cfg = \n", cfg

