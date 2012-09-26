define ['require'], (require)->
  console.log 'started d'
  _ = require "/libs/lodash.min" #webRoot path

  l =''
  _.each [1,2,3], (v)->
    console.log 'lodash:', v
    l=l+v

  return d:'d'+l