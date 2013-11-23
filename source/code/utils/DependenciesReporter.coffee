## reporting, in this format
_ = require 'lodash'
_B = require 'uberscore'
Dependency = require './../fileResources/Dependency'

l = new _B.Logger 'urequire/utils/DependencyReporter'
#
# Embarrasing piece of code, full of misnomers and very custom to this project,
# but could refactoreed to support more generic data gathering transformations for reporting
#
# TODO: refactor it to more generic. Make specs
class DependenciesReporter

  constructor: ()->
    @reportData = {}

  dependencyTypesMessages =

    ### 'problematic' ones ###
    untrusted:
      header: "\u001b[31m Untrusted dependencies (i.e non literal String) found:"
      footer: """
        They are left AS-IS, BUT are added to the dependency array.
        If evaluated name of the `require( utrusted + 'string' )` isnt in dependency array [..],
        your app WILL HALT and WILL NOT WORK on the web/AMD side (but should be OK on node).\u001b[0m"""

  ### simply interesting :-) ###
  DT = Dependency.TYPES
  _B.okv dependencyTypesMessages,
    DT.local,
      header: "`local`-looking dependencies (those without fileRelative (eg `./`) & not present in bundle's root):"
      footer: """
        Note: When executing on plain nodejs, locals are `require`d as is.
              When executing on Web/AMD or uRequire/UMD they use `rjs.baseUrl`/`rjs.paths`, if present.
      """

    DT.notFoundInBundle,
      header: "\u001b[31m Bundle-looking dependencies not found in bundle:",
      footer: "They are added as-is.\u001b[0m"

    DT.external,
      header: "External dependencies (not checked in this version):"
      footer: "They are added as-is."

    DT.webRootMap,
      header: "Web root dependencies '/' (not checked in this version):"
      footer: "They are added as-is."

  reportedDepTypes: _.keys dependencyTypesMessages

  reportTemplate: (texts, dependenciesFound)-> """
   \n#{texts.header}
     #{ "'#{dependency}' dependency appears in modules: [
       #{("\n         '" +
         mf + "'" for mf in moduleFiles)}\n  ]\n" for dependency, moduleFiles of dependenciesFound
        }#{
     texts.footer}\n
   """

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

  getReport: (interestingDepTypes = @reportedDepTypes)->
    l.debug 95, 'Getting report only for types :', interestingDepTypes
    report = ""
    for depType, depTypesMsgs of dependencyTypesMessages when depType in interestingDepTypes
      if @reportData[depType]
         report += @reportTemplate depTypesMsgs, @reportData[depType]
    return report

module.exports = DependenciesReporter

##inline tests
#rep = new DependenciesReporter()
#
#rep.addReportData {
#    untrustedAsyncRequireDeps: [ "data + '/messages/hello'", "data + '/messages/bye'" ],
#    untrustedDefineArrayDeps: [ "data + '/messages/ohno'", "data + '/messages/byebye'" ],
#    untrustedAsyncRequireDeps: [ "data + '/messages/hmmmm'", "data + '/messages/nowwhat'" ],
#    notFoundInBundle: ['data/missingLib.js']
#    parameters: ['_'],
#    ext_requireDeps: ['lodash'],
#    wrongDependencies: [ 'require(msgLib)' ],
#    nodeDeps: [ '../data/messages/hello', '../data/messages/bye' ],
#    webRootMap: '..'
#  }
#  , 'some/Module'
#
#console.log rep.getReport()
