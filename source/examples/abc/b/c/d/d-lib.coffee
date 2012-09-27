define ['require'], (require)-> # ['require'] not really needed and will be ommited from UMD
                                # unless -scanPrevent is used, where even lodash will appear in []
  console.log 'started d-lib'
  _ = require "/libs/lodash.min" # using a webRoot path

  l =''
  _.each [1,2,3], (v)->
    console.log 'lodash:', v
    l=l+v

  return d:'d'+l