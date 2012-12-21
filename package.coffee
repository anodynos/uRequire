myPackage =
  name: "urequire"

  description: "Module converter: write modular code once, convert to UMD and run/test on AMD (browser/requirejs) & nodejs."

  version: "0.2.9-3"

  homepage: "https://github.com/anodynos/urequire"

  author:
    name: "Agelos Pikoulas"
    email: "agelos.pikoulas@gmail.com"

  licenses: [
    type: "MIT"
    url: "http://www.opensource.org/licenses/mit-license.php"
  ]

  keywords: ["AMD", "UMD", "UMDjs", "requirejs", "require", "define", "module", "modules", "modular", "format", "convert", "converter", "umdify", "nodefy", "browserify", "dependency", "dependencies", "bundle"]

  repository:
    type: "git"
    url: "git://github.com/anodynos/urequire"

  bugs:
    url: ""

  bin:
    urequire: "./build/code/urequireCmd.js"

  main: "./build/code/urequire.js"

  test: "mocha build/spec --recursive --bail --reporter spec"

  directories:
    doc: "./doc"
    dist: "./build"

  engines:
    "node": "*"

  dependencies:
    "lodash": "0.10.x"
    "commander": "1.1.x"
    "wrench" : "1.4.x"
    "uglify-js": "1.3.x"
    "requirejs": ">=2.0.6" # needed by NodeRequirer - saves you from having it in your deps

  devDependencies:
    #"coffee-script": ">=1.3.3" # needed only as global
    #"codo": ">=1.5.1" # needed only as global
    # "mocha": "*" # needed only as global
    "chai": "*"
    "grunt-shell": "*"  # used in many tasks, including urequire-ing examples, compiling coffee etc
    "grunt-contrib": "*" # using clean & copy

require('fs').writeFileSync './package.json', JSON.stringify(myPackage), 'utf-8'
module.exports = myPackage