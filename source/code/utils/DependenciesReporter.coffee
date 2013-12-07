_ = (_B = require 'uberscore')._
l = new _B.Logger 'urequire/utils/DependencyReporter'

Dependency = require './../fileResources/Dependency'

#
# Embarrasing piece of code, full of misnomers and very custom to this project,
# but could refactoreed to support more generic data gathering transformations for reporting
#
# TODO: refactor it to more generic. Make specs
class DependenciesReporter

  constructor: ()->
    @reportData = {}

  dependencyTypesMessages =
    # 'problematic' ones
    'untrusted':
      header: "\u001b[33m Untrusted dependencies (i.e non literal String) found:"
      footer: "They are left AS-IS, BUT are added to the dependency array." +
              "If evaluated name of the `require( utrustedDep )` isnt in dependency array [..]," +
              "your app WILL HALT and WILL NOT WORK on the web/AMD side (but should be OK on node).\u001b[0m"

    # simply interesting
    'node':
      header: "\u001b[33m Node only dependencies, NOT added to AMD deps array:"
      footer: "Make sure they are not `require`d when running on Web, " +
              "(i.e separate execution branches when __isNode / __isWeb), " +
              "otherwise you code will halt on Web."

    'nodeLocal':
      header: "\u001b[33m Node only *local dependencies*, NOT added to AMD deps array:"
      footer: "Make sure they are not `require`d when running on Web, " +
              "(i.e separate execution branches when __isNode / __isWeb), " +
              "otherwise you code will halt on Web."

    'local':
      header: "\u001b[33m `local` deps (i.e either looking 'local' / declared in deps.locals) not present in bundle :" # @todo: or infered from package/bower.JSON
      footer: "Note: When executing on plain nodejs, locals are `require`d as is. " +
              "When executing on Web/AMD or uRequire/UMD they use `rjs.baseUrl`/`rjs.paths`, if present."

    'notFoundInBundle':
      header: "\u001b[31m Bundle-looking dependencies not found in bundle:",
      footer: "They are added as-is.\u001b[0m"

    'external':
      header: "External dependencies (not checked in this version):"
      footer: "They are added as-is."

    'webRootMap':
      header: "Web root dependencies '/' (not checked in this version):"
      footer: "They are added as-is."

  reportTemplate: (texts, depsFound)->
    maxDepLength = _.max _.map depsFound, (v, k)-> k.length

    '\n   ' + texts.header + '\n' +

    ( for dep, modules of depsFound
        "    - '#{dep}'#{ _.pad '(in ' + modules.length + " modules: '", 18 + (maxDepLength - dep.length) + (modules.length + '').length}" +
        (mod for mod, i in modules when i<3).join("', '") + (if modules.length >=3 then "', ...)" else "')")
    ).join('\n') +

    '\n    ' + texts.footer + '\n'

  # Augments reportData, that ends up in this form
  #   {
  #     local: { 'underscore': [ 'some/module', 'other/module' ] },
  #     external: { '../../some/external/lib': [ 'some/module' ]}
  #   }
  #
  # @param {Object} resolvedDeps, eg
  #     local: [ 'lodash' ]
  #     external: [ '../../some/external/lib', '../../../anotherLib'' ]
  #     notFoundInBundle: [ '../lame/dir', 'another/lame/lib']
  #
  # @param {String} modyle The module name, eg 'isAgree.js'
  addReportData: (resolvedDeps, modyle)->
    for depType, resDeps of resolvedDeps when (not _.isEmpty resDeps)
      @reportData[depType] or= {}
      for resDep in _B.arrayize resDeps
        foundModules = (@reportData[depType][resDep] or= [])
        foundModules.push modyle if modyle not in foundModules
    null

  getReport: (interestingDepTypes = _.keys dependencyTypesMessages)->
    l.debug 95, 'Getting report only for types :', interestingDepTypes
    report = ""
    for depType, depTypesMsgs of dependencyTypesMessages when depType in interestingDepTypes
      if @reportData[depType]
         report += @reportTemplate depTypesMsgs, @reportData[depType]
    return report

module.exports = DependenciesReporter