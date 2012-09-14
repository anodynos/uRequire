myPackage =
  name: "myRequire"

  description: "Automatically UMDify your AMD code, to make it run on both the browser & nodejs"

  version: "0.0.1"

  homepage: "https://github.com/anodynos/myrequire"

  author:
    name: "Agelos Pikoulas"
    email: "agelos.pikoulas@gmail.com"
    url: ""

  licenses: [
    type: "MIT"
    url: "http://www.opensource.org/licenses/mit-license.php"
  ]

  keywords: ["AMD", "UMD", "UMDjs", "requirejs", "require", "define", "modules", "modular", "converter", "umdify", "dependency", "dependencies", "bundle"]

  repository:
    type: "git"
    url: "git://github.com/anodynos/myrequire"

  bugs:
    url: ""

  bin:
    myRequire: "./build/code/myRequireCmd.js"

  main: "./build/code/myRequire.js"

  test: "mocha build/test --recursive --bail --reporter spec"

  directories:
    doc: "./doc"
    dist: "./build"

  engines:
    "node": "*"

  dependencies:
    underscore: ">= 1.3.x" # or "lodash": "0.5.x"
    commander: "*"
    wrench : "*"
    "uglify-js": "1.3.x"

  devDependencies:
    "coffee-script": ">=1.3.3"
    "mocha": "*"
    "chai": "*"
    "grunt": "*"
    "grunt-shell": "*"  # mocha
    "grunt-contrib": "*" # using clean, copy

require('fs').writeFileSync('./package.json', JSON.stringify(myPackage), 'utf-8')