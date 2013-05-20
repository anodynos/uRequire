# Based on https://github.com/jeromegn/Backbone.nodejsFsStorage/blob/master/backbone.nodejsFsStorage.js

_ = require 'lodash'
Backbone = require 'backbone'
Backbone.$ = require 'jquery'
fs = require 'fs'
path = require 'path'
wrench = require 'wrench'

# A simple module to replace `Backbone.sync` with *nodejsFsStorage*-based
# persistence. Models are given GUIDS, and saved into a JSON object. Simple
# as that.

# attributes:
  # filename: the filename of the file
  # content

class NodejsFsStorage
  defaultOptions =
    readPath: '.'
    writePath: '.'

  constructor: (options = defaultOptions)->
    _.defaults options, defaultOptions if options isnt defaultOptions

  # Save the current state of the **Store** to *nodejsFsStorage*.
  save: (model)->
    _wrench.mkdirSyncRecursive path.dirname "#{options.writePath}/#{model.get('filename')}"
    _fs.writeFileSync "#{options.writePath}/#{model.get('filename')}", model.get 'content', 'utf-8'

  # Add a model, giving it a (hopefully)-unique GUID, if it doesn't already
  # have an id of it's own.
  create: (model) ->
    unless model.id
      model.id = guid()
      model.set model.idAttribute, model.id
    @nodejsFsStorage().setItem @currentPath + "-" + model.id, JSON.stringify(model)
    @records.push model.id.toString()
    @save model
    @find model


  # Update a model by replacing its copy in `this.data`.
  update: (model) ->
    @nodejsFsStorage().setItem @currentPath + "-" + model.id, JSON.stringify(model)
    @records.push model.id.toString()  unless _.include(@records, model.id.toString())
    @save model
    @find model


  # Retrieve a model from `this.data` by id.
  find: (model) ->
    @jsonData @nodejsFsStorage().getItem(@currentPath + "-" + model.id)
    #_fs.readFileSync fullModulePath, 'utf-8'


  # Return the array of all models currently in storage.
  findAll: ->

    # Lodash removed _#chain in v1.0.0-rc.1
    (_.chain or _)(@records).map((id) ->
      @jsonData @nodejsFsStorage().getItem(@currentPath + "-" + id)
    , this).compact().value()


  # Delete a model from `this.data`, returning it.
  destroy: (model) ->
    return false  if model.isNew()
    @nodejsFsStorage().removeItem @currentPath + "-" + model.id
    @records = _.reject(@records, (id) ->
      id is model.id.toString()
    )
    @save()
    model

  nodejsFsStorage: ->
    nodejsFsStorage


  # fix for "illegal access" error on Android when JSON.parse is passed null
  jsonData: (data) ->
    data and JSON.parse(data)


  # Clear nodejsFsStorage for specific collection.
  _clear: ->
    local = @nodejsFsStorage()
    itemRe = new RegExp("^" + @currentPath + "-")

    # Remove id-tracking item (e.g., "foo").
    local.removeItem @currentPath

    # Lodash removed _#chain in v1.0.0-rc.1
    # Match all data items (e.g., "foo-ID") and remove.
    (_.chain or _)(local).keys().filter((k) ->
      itemRe.test k
    ).each (k) ->
      local.removeItem k



  # Size of nodejsFsStorage.
  _storageSize: ->
    @nodejsFsStorage().length


# nodejsFsSync delegate to the model or collection's
# *nodejsFsStorage* property, which should be an instance of `Store`.
# Backbone.nodejsFsSync is deprecated, use Backbone.NodejsFsStorage.sync instead
Backbone.NodejsFsStorage.sync = Backbone.nodejsFsSync = (method, model, options) ->
  store = model.nodejsFsStorage or model.collection.nodejsFsStorage
  resp = undefined #If $ is having Deferred - use it.
  errorMessage = undefined
  syncDfd = Backbone.$.Deferred and Backbone.$.Deferred()
  try
    switch method
      when "read"
        resp = (if model.id isnt `undefined` then store.find(model) else store.findAll())
      when "create"
        resp = store.create(model)
      when "update"
        resp = store.update(model)
      when "delete"
        resp = store.destroy(model)
  catch error
    if error.code is DOMException.QUOTA_EXCEEDED_ERR and store._storageSize() is 0
      errorMessage = "Private browsing is unsupported"
    else
      errorMessage = error.message
  if resp
    if options and options.success
      if Backbone.VERSION is "0.9.10"
        options.success model, resp, options
      else
        options.success resp
    syncDfd.resolve resp  if syncDfd
  else
    errorMessage = (if errorMessage then errorMessage else "Record Not Found")
    if options and options.error
      if Backbone.VERSION is "0.9.10"
        options.error model, errorMessage, options
      else
        options.error errorMessage
    syncDfd.reject errorMessage  if syncDfd

  # add compatibility with $.ajax
  # always execute callback for success and error
  options.complete resp  if options and options.complete
  syncDfd and syncDfd.promise()

Backbone.ajaxSync = Backbone.sync
Backbone.getSyncMethod = (model) ->
  return Backbone.nodejsFsSync  if model.nodejsFsStorage or (model.collection and model.collection.nodejsFsStorage)
  Backbone.ajaxSync


# Override 'Backbone.sync' to default to nodejsFsSync,
# the original 'Backbone.sync' is still available in 'Backbone.ajaxSync'
Backbone.sync = (method, model, options) ->
  Backbone.getSyncMethod(model).apply this, [method, model, options]

Backbone.NodejsFsStorage


#((root, factory) ->
#  if typeof exports is "object"
#    module.exports = factory(require("underscore"), require("backbone"))
#  else if typeof define is "function" and define.amd
#
#    # AMD. Register as an anonymous module.
#    define ["underscore", "backbone"], (_, Backbone) ->
#
#      # Use global variables if the locals are undefined.
#      factory _ or root._, Backbone or root.Backbone
#
#  else
#
#    # RequireJS isn't being used. Assume underscore and backbone are loaded in <script> tags
#    factory _, Backbone
#) this, (_, Backbone) ->
#
#  # A simple module to replace `Backbone.sync` with *localStorage*-based
#  # persistence. Models are given GUIDS, and saved into a JSON object. Simple
#  # as that.
#
#  # Hold reference to Underscore.js and Backbone.js in the closure in order
#  # to make things work even if they are removed from the global namespace
#
#  # Generate four random hex digits.
#  S4 = ->
#    (((1 + Math.random()) * 0x10000) | 0).toString(16).substring 1
#
#  # Generate a pseudo-GUID by concatenating random hexadecimal.
#  guid = ->
#    S4() + S4() + "-" + S4() + "-" + S4() + "-" + S4() + "-" + S4() + S4() + S4()
#
#  # Our Store is represented by a single JS object in *localStorage*. Create it
#  # with a meaningful name, like the name you'd give a table.
#  # window.Store is deprectated, use Backbone.LocalStorage instead
#  Backbone.LocalStorage = window.Store = (name) ->
#    @name = name
#    store = @localStorage().getItem(@name)
#    @records = (store and store.split(",")) or []
#
#  _.extend Backbone.LocalStorage::,
#
#    # Save the current state of the **Store** to *localStorage*.
#    save: ->
#      @localStorage().setItem @name, @records.join(",")
#
#
#    # Add a model, giving it a (hopefully)-unique GUID, if it doesn't already
#    # have an id of it's own.
#    create: (model) ->
#      unless model.id
#        model.id = guid()
#        model.set model.idAttribute, model.id
#      @localStorage().setItem @name + "-" + model.id, JSON.stringify(model)
#      @records.push model.id.toString()
#      @save()
#      @find model
#
#
#    # Update a model by replacing its copy in `this.data`.
#    update: (model) ->
#      @localStorage().setItem @name + "-" + model.id, JSON.stringify(model)
#      @records.push model.id.toString()  unless _.include(@records, model.id.toString())
#      @save()
#      @find model
#
#
#    # Retrieve a model from `this.data` by id.
#    find: (model) ->
#      @jsonData @localStorage().getItem(@name + "-" + model.id)
#
#
#    # Return the array of all models currently in storage.
#    findAll: ->
#
#      # Lodash removed _#chain in v1.0.0-rc.1
#      (_.chain or _)(@records).map((id) ->
#        @jsonData @localStorage().getItem(@name + "-" + id)
#      , this).compact().value()
#
#
#    # Delete a model from `this.data`, returning it.
#    destroy: (model) ->
#      return false  if model.isNew()
#      @localStorage().removeItem @name + "-" + model.id
#      @records = _.reject(@records, (id) ->
#        id is model.id.toString()
#      )
#      @save()
#      model
#
#    localStorage: ->
#      localStorage
#
#
#    # fix for "illegal access" error on Android when JSON.parse is passed null
#    jsonData: (data) ->
#      data and JSON.parse(data)
#
#
#    # Clear localStorage for specific collection.
#    _clear: ->
#      local = @localStorage()
#      itemRe = new RegExp("^" + @name + "-")
#
#      # Remove id-tracking item (e.g., "foo").
#      local.removeItem @name
#
#      # Lodash removed _#chain in v1.0.0-rc.1
#      # Match all data items (e.g., "foo-ID") and remove.
#      (_.chain or _)(local).keys().filter((k) ->
#        itemRe.test k
#      ).each (k) ->
#        local.removeItem k
#
#
#
#    # Size of localStorage.
#    _storageSize: ->
#      @localStorage().length
#
#
#  # localSync delegate to the model or collection's
#  # *localStorage* property, which should be an instance of `Store`.
#  # window.Store.sync and Backbone.localSync is deprecated, use Backbone.LocalStorage.sync instead
#  Backbone.LocalStorage.sync = window.Store.sync = Backbone.localSync = (method, model, options) ->
#    store = model.localStorage or model.collection.localStorage
#    resp = undefined #If $ is having Deferred - use it.
#    errorMessage = undefined
#    syncDfd = Backbone.$.Deferred and Backbone.$.Deferred()
#    try
#      switch method
#        when "read"
#          resp = (if model.id isnt `undefined` then store.find(model) else store.findAll())
#        when "create"
#          resp = store.create(model)
#        when "update"
#          resp = store.update(model)
#        when "delete"
#          resp = store.destroy(model)
#    catch error
#      if error.code is DOMException.QUOTA_EXCEEDED_ERR and store._storageSize() is 0
#        errorMessage = "Private browsing is unsupported"
#      else
#        errorMessage = error.message
#    if resp
#      if options and options.success
#        if Backbone.VERSION is "0.9.10"
#          options.success model, resp, options
#        else
#          options.success resp
#      syncDfd.resolve resp  if syncDfd
#    else
#      errorMessage = (if errorMessage then errorMessage else "Record Not Found")
#      if options and options.error
#        if Backbone.VERSION is "0.9.10"
#          options.error model, errorMessage, options
#        else
#          options.error errorMessage
#      syncDfd.reject errorMessage  if syncDfd
#
#    # add compatibility with $.ajax
#    # always execute callback for success and error
#    options.complete resp  if options and options.complete
#    syncDfd and syncDfd.promise()
#
#  Backbone.ajaxSync = Backbone.sync
#  Backbone.getSyncMethod = (model) ->
#    return Backbone.localSync  if model.localStorage or (model.collection and model.collection.localStorage)
#    Backbone.ajaxSync
#
#
#  # Override 'Backbone.sync' to default to localSync,
#  # the original 'Backbone.sync' is still available in 'Backbone.ajaxSync'
#  Backbone.sync = (method, model, options) ->
#    Backbone.getSyncMethod(model).apply this, [method, model, options]
#
#  Backbone.LocalStorage
#
