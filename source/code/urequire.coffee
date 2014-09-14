exports.VERSION = if VERSION? then VERSION else '{NO_VERSION}' # 'VERSION' variable is added by grant:concat

Object.defineProperties exports, # lazily export
  # our main "processor"
  BundleBuilder: get:-> require "./process/BundleBuilder"

  # used by UMD-transformed modules when running on nodejs
  NodeRequirer: get:-> require './NodeRequirer'

  upath: get:-> require "./paths/upath"

  # below, just for reference
  Bundle: get:-> require "./process/Bundle"
  Build: get:-> require "./process/Build"
  Module: get:-> require "./fileResources/Module"