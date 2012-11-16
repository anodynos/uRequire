class Urequire
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props

  @property
    processBundle:
      get:-> require "./processBundle"

  # used by UMD-transformed modules, to make the node (async) require
  @property
    NodeRequirer:
      get:-> require './NodeRequirer'

module.exports = new Urequire
