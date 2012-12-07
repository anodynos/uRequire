class Bundle
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props
  Function::staticProperty = (props) => Object.defineProperty @::, name, descr for name, descr of props

  @property
    bundlePath: ''
    bundleFiles: []
    modules: []
    options: @options #!!!

  # methods ?
  addGlobalDependency: (depName, varName)->
    # visits all UModules and adds a new Dependency in their arrays.

module.exports = Bundle

