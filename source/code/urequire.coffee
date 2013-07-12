(require 'uberscore').Logger::VERSION = if VERSION? then VERSION else '{NO_VERSION}' # 'VERSION' variable is added by grant:concat

class Urequire
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p ;null
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p ;null

  VERSION: if VERSION? then VERSION else '{NO_VERSION}'

  @property
    # our main "processor"
    BundleBuilder: get:-> require "./process/BundleBuilder"

    # used by UMD-transformed modules when running on nodejs
    NodeRequirer: get:-> require './NodeRequirer'

    # below, just for reference
    Bundle: get:-> require "./process/Bundle"
    Build: get:-> require "./process/Build"
    Module: get:-> require "./fileResources/Module"

module.exports = new Urequire
