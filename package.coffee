myPackage =
  name: "urequire"

  description: "Write modular code once, convert to UMD and run/test on browser/requirejs & nodejs"

  version: "0.2.0"

  homepage: "https://github.com/anodynos/urequire"

  author:
    name: "Agelos Pikoulas"
    email: "agelos.pikoulas@gmail.com"

  licenses: [
    type: "MIT"
    url: "http://www.opensource.org/licenses/mit-license.php"
  ]

  keywords: ["AMD", "UMD", "UMDjs", "requirejs", "require", "define", "modules", "modular", "converter", "umdify", "dependency", "dependencies", "bundle"]

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
    "lodash": "*"
    "commander": "*"
    "wrench" : "*"
    "uglify-js": ">=1.3.3"
    "requirejs": ">=2.1.1"

  devDependencies:
    #"coffee-script": ">=1.3.3" # needed only as global
    #"codo": ">=1.5.1" # needed only as global
    "mocha": "*"
    "chai": "*"
    "grunt-shell": "*"  # used in many tasks, including urequire-ing examples, compiling coffee etc
    "grunt-contrib": "*" # using clean & copy

require('fs').writeFileSync('./package.json', JSON.stringify(myPackage), 'utf-8')