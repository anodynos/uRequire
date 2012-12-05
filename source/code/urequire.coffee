class Urequire
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props

  @property
    BundleProcessor:
      get:-> require "./process/BundleProcessor"

  # used by UMD-transformed modules, to make the node (async) require
  @property
    NodeRequirer:
      get:-> require './NodeRequirer'

module.exports = new Urequire
