define ['require'], (require)-> # ['require'] not really needed and will be ommited from UMD
                                # unless -scanPrevent is used, where even lodash will appear in []
  console.log 'started d-lib'
  _ = require "/libs/lodash.min.js" # using a webRoot path - note:
                                    # a) on web it assumes it exists on web server's root, as defined here.
                                    # b) .js is needed, cause RequireJs is not adding .js for deps that start with '/'

  l =''
  _.each [1,2,3], (v)->
    console.log 'lodash:', v
    l=l+v

  return d:'d'+l