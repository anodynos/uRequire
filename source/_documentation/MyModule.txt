Joffee = #name: "myModule" is taken from filename & package

  # if true, the module will be exported as moduleName (=fileName) will be exported as root.fileName
  # if false, its is globalized only when amd is NOT available on browser
  # if its a string (?or array og strings?), this variable name(s) is/are used as the global 'export' variable.
  gloabilize: false

  nodeJs:
    enforceCommonJs: false # MyRequire favors AMD/RequireJS on both node & browser

  # isDefined as a module that is reused / called etc.
  # Creates an AMD 'define ['a','b','c'], (a,b,c)-> statement
  # otherwise a requireJs call is used. Use it only when you are returning
  # something usefull - see http://stackoverflow.com/questions/9507606/when-to-use-require-and-when-to-use-define
  isDefined: true

  # array of named dependencies.
  # They are always namespaced relative to ?MyModule?
  # these are passed to either
  #   * a RequireJS define([dep1,dep2]) or requirejs([dep1,dep2])
  #   * a nodejs ... = require('dep1'), ... = require('dep2'),
  requires: ['main/library', 'main/anotherlib', 'underscore':'_', ]

# import, include, refer

# package, library, bundle

module:
  target: ["umd", "amd", "noder"]
  define: #default "define", can be "require"
    rootExport: true | "myModule", default=false
  deps: [ "views/PersonView", "views/PersonDetailView"]
  args: [ 'PersonView', "PersonEditView"]

  import: [
    "../anotherLibrary"
  ]
###
  ##imports##
  imports are simply paths that myRequire will generate path resolutions against for this bundle.
  Usefull for tests & more. Type -h modules for more info'
###


#bundle-cache.json - an automatic cache for what was found on the last bundling. Used when import-ed to save from scanning all sources again.
bundle:
  import:[

  ]
  modules:[
    "main/App":
      define:true
      deps: [ "views/PersonView", "views/PersonDetailView"]
      args: [ 'PersonView', "PersonEditView"]

    "views/PersonView":
      require:true
      deps: [ "views/MasterView", "utils/uGetScore", "amd-utils"]
      args: [ 'MasterView', "PersonEditView"]
  ]
