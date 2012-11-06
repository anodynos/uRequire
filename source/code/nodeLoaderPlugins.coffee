_fs = require 'fs'

module.exports =
  text: (file)-> _fs.readFileSync file, 'utf-8'

  json: (file)-> 'json not supported!'

