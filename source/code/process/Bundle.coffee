class Bundle
  Function::property = (props) -> Object.defineProperty @::, name, descr for name, descr of props
  Function::staticProperty = (props) => Object.defineProperty @::, name, descr for name, descr of props


module.exports = Bundle

