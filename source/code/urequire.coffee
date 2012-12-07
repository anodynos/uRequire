class Urequire
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props

#  # @todo: legacy
#  process: (options)->
#    bp = new @Bundle options
#    bp.process();

  @property
    Bundle:
      get:-> require "./process/Bundle"

  # used by UMD-transformed modules, to make the node (async) require
  @property
    NodeRequirer:
      get:-> require './NodeRequirer'

module.exports = new Urequire
