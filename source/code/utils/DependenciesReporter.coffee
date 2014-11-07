_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/utils/DependencyReporter'

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
      color: "\u001B[35;1m"
      header: "Untrusted dependencies (i.e non literal String) found:"
      footer: """They are left AS-IS, BUT are added to the dependency array.
              If evaluated name of the `require( utrustedDep )` isnt in dependency array [..],
              your app WILL HALT and WILL NOT WORK on the web/AMD side (but should be OK on node)."""

    # simply interesting
    'node':
      color: "\u001B[35;1m"
      header: "Node-only *bundle dependencies*, NOT added to AMD deps array:"
      footer: """Make sure they are not `require`d when running on Web,
              (i.e use separate execution branches with `__isNode` / `__isWeb` using `runtimeInfo:true`),
              otherwise you code will halt on Web."""

    'nodeLocal':
      color: "\u001B[34;1m"
      header: "Node-only *local dependencies*, NOT added to AMD deps array:"
      footer: """Make sure they are not `require`d when running on Web,
              (i.e use separate execution branches with `__isNode` / `__isWeb` using `runtimeInfo:true`),
              otherwise you code will halt on Web."""

    'local':
      color: "\u001b[33;1m"
      header: "`local` deps (i.those either looking 'localdep' / declared in deps.locals / found in bower.json or package.json) and part of bundle :"
      footer: """Note, when executing :
                  * on nodejs, locals are `require`d as is.
                  * on Web/AMD or uRequire/UMD they use `rjs.baseUrl` / `rjs.paths`.
                  * on Web/Script they are loaded via <script src='path/to/localdep.js'/>.
              """

    'notFoundInBundle':
      color: "\u001b[31;1m"
      header: "Bundle-looking dependencies not found in bundle:",
      footer: """They are added as-is, without path translation from *bundleRelative* to *fileRelative*.
              Even if they are later added to the `dstPath`, they will not load on nodejs cause
              nodejs expects `./` fileRelative paths.

              If a dep is indeed a local dependency, eg `when/callbacks` you must either :
                 * Install it with either `bower install when` or `npm install when` (only the first path part)
                                                OR
                 * Declare it as `dependencies: locals: ['when']` (only the first path part).
              and urequire will recognize it as a local (instead of missing).
              """

    'external':
      color: "\u001b[33m"
      header: "External dependencies (not checked in this version):"
      footer: "They are added as-is."

    'webRootMap':
      color: "\u001b[35m"
      header: "Web root dependencies '/' (not checked in this version):"
      footer: "They are added as-is."

  reportTemplate: (texts, depsFound)->
    maxDepLength = _.max _.map depsFound, (v, k)-> k.length

    '\n   ' + texts.color + texts.header + '\u001B[37;1m\n' +

    ( for dep, modules of depsFound
        "    - '#{dep}'#{ _.pad '(in ' + modules.length + " modules: '", 18 + (maxDepLength - dep.length) +
        (modules.length + '').length}" + modules[0..3].join("', '") + (if modules.length >4 then "', ...)" else "')")
    ).join('\n') +

    '\n   ' + texts.color + texts.footer.split('\n').join('\n   ') + '\u001B[0m\n'

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