class Module
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props
  Function::staticProperty = (props) => Object.defineProperty @::, name, descr for name, descr of props

  constructor: ()->

  @property
    name: {}
    source: {} # String of source eg coffee (or .js) - used only to compare for file changes
    sourceJs: {} # String of source code in js
    convertedJs: {}  # String of
    convertedTemplate: {} #eg 'UMD'

    moduleType: @moduleInfo.moduleType
    modulePath: @modyle # full module path within bundle
    webRootMap: @options.webRootMap || '.'
    arrayDependencies: arrayDependencies
    nodeDependencies: if @options.allNodeRequires then arrayDependencies else (d.name() for d in arrayDeps)
    parameters: @moduleInfo.parameters
    factoryBody: @moduleInfo.factoryBody

    rootExports: @moduleInfo.rootExports # todo: generalize
    noConflict: @moduleInfo.noConflict
    nodejs: @moduleInfo.nodejs #todo: not working


module.exports = Module

m = new Module

m.name = 'agelos'
console.log m.name