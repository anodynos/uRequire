class Urequire
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props

  @property Bundle: get:-> require "./process/Bundle"
  @property BundleBuilder: get:-> require "./process/BundleBuilder"

  # used by UMD-transformed modules when running on nodejs
  @property NodeRequirer: get:-> require './NodeRequirer'

module.exports = new Urequire