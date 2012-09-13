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

  keywords: ["AMD", "UMD", "UMDjs", "requirejs", "require", "define", "modules", "modular", "converter", "umdify", "dependency", "dependencies"]

#  repository:
#    type: "git"
#    url: "git://github.com/anodynos/myrequire"

  bugs:
    url: ""

  main: "./build/code/myRequireCmd.js"

  directories:
#    doc: "./doc"
    dist: "./dist"

  engines:
    "node": "*"

  dependencies:
    underscore: ">= 1.3.x" # or "lodash": "0.5.x"
    commander: ">= 1.0.4"
    wrench : "~1.3.9"

  devDependencies:
    "coffee-script": "1.3.x"
    "mocha": "*"
    "chai": "*"
    "grunt-shell": "0.1.x"  # mocha
    "grunt-contrib": "0.1.x" # using clean, copy

require('fs').writeFileSync('./package.json', JSON.stringify(myPackage), 'utf-8')