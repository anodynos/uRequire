_fs = require 'fs'

module.exports =

  json: (file)->
    JSON.parse _fs.readFileSync file, 'utf-8'


