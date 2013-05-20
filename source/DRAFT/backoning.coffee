_ = require 'lodash'
_B = require 'uberscore'
l = new _B.Logger 'grunt-plugin'

fs = require 'fs'
wrench = require 'wrench'
path = require 'path'

Backbone = require 'backbone'
{Model, Collection} = Backbone

$ = require 'jquery-deferred'
upromise = require 'upromise'

class NodejsFsStorage
  defaultOptions =
    readPath: '.' #
    writePath: '.'
    writeExtension: undefined

  constructor: (@options = defaultOptions)->
    _.defaults options, defaultOptions if options isnt defaultOptions


#  saveFile: (model)->
#    try
#      fullpathname = "#{@options.writePath}/#{model.get('filename')}"
#      wrench .mkdirSyncRecursive path.dirname fullpathname
#      fs.writeFileSync fullpathname, model.get('content'), 'utf-8'
#    catch err
#      l.warn "Error saving filename = #{model.get('filename')} fullpathname = ", fullpathname, 'err =', err
#      return err
#    return true

#  readFile: (model)->
#    try
#      fullpathname = "#{@options.writePath}/#{model.get('filename')}"
#      content = fs.readFileSync fullpathname, 'utf-8'
#    catch err
#      l.warn 'Error reading filename = ', fullpathname, 'err =', err
#      return false
#
#    return content

  sync: (method, model, options)=>
      l.log "sync -> method: #{method}"
#      l.log 'model = ', model
#      l.log 'options = ', options

      switch method
        when 'create'
          try
            fullpathname = "#{@options.writePath}/#{model.get('filename')}"
            wrench .mkdirSyncRecursive path.dirname fullpathname
            fs.writeFileSync fullpathname, model.get('content'), 'utf-8'
          catch err
            errPretty = l.warn "Error saving model - filename = #{model.get('filename')} fullpathname = ", fullpathname, 'err =', err
            options.error err: errPretty
          options.success model

        when 'read' or 'update'
          try
            fullpathname = "#{@options.readPath}/#{model.get('filename')}"
            content = fs.readFileSync fullpathname, 'utf-8'
            options.success {content}
          catch err
            errPretty l.warn 'Error reading filename = ', fullpathname, 'err =', err
            options.error {err: errPretty}

        when 'delete'
          l.log "DELETE @get('filename'), 'utf-8'"

nodejsFsStorage = new NodejsFsStorage
Backbone.sync = nodejsFsStorage.sync

class UResource extends Model
  constructor:-> super

  initialize:-> l.warn '#### New UResource - filename = ', @get 'filename'
  process: -> l.verbose '...pr>ocessed UResource, filename = ', @get 'filename'

class UBundle extends Collection
  model: UResource
#
ur = new UResource
  filename: 'myFile.txt'
  content: 'My text Oldish'

ur.on 'change:content', (args...)-> l.log 'change:content'
l.log ur.get 'content'

# savePromise = ur.save()# [], @todo: NOT WORKING - check http://stackoverflow.com/questions/14407294/jquery-promises-and-backbone

#ur.save
#  error:-> l.warn 'error saving'
#  success: -> l.verbose 'saved Ok'

fetchDeferred = ur.fetch() #todo: fix it to return a Promisey thing!

#fetchPromise.resolved ->l.log 'I am the fetch cb'
l.warn fetchDeferred
l.log ur.get 'content'



# Working
#uBundle = new UBundle [
#    filename: 'myFile.txt'
#  ,
#    filename: 'myFile2.txt'
#  ]
#
#uBundle.fetch error:-> l.warn 'Error reading'
#
#uBundle.each (ur)->
#  l.log ur.get 'filename'
#
#
