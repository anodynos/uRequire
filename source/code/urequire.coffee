class Urequire
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props

  # our main "processor"
  @property BundleBuilder: get:-> require "./process/BundleBuilder"

  # used by UMD-transformed modules when running on nodejs
  @property NodeRequirer: get:-> require './NodeRequirer'

  # below, just for reference
  @property Bundle: get:-> require "./process/Bundle"
  @property Build: get:-> require "./process/Build"
  @property UModule: get:-> require "./process/UModule"


module.exports = new Urequire