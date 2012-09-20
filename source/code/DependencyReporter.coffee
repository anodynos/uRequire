## reporting, in this format
_ = require 'lodash'
log = console.log

#
# Embarrasing piece of code, full of misnomers and very custom to this project,
# but could refactoreed to support more generic data gathering transformations for reporting
#
# TODO: refactor it to more generic. Make specs
class DependencyReporter

  constructor: (@interestingDepTypes = _.keys(dependencyTypesMessages))->
    @reportData = {}

  dependencyTypesMessages=
    wrongDependencies:
      header: "\u001b[31m Wrong -possibly- require() dependencies found:"
      footer: "They are IGNORED. If the evaluated name of the require() is not in a dependency array [..] before the require() call, your app WILL HALT and WILL NOT WORK on the web-side (but should be OK on node).\u001b[0m"
    notFoundInBundle:
      header: "\u001b[31m Bundle-looking dependencies not found in bundle:",
      footer: "They are added as-is.\u001b[0m"
    external:
      header: "External dependencies (not checked in this version):"
      footer: "They are added as-is."
    global:
      header: "Global-looking dependencies (not checked in this version):"
      footer: "They are added as-is."
    webRoot:
      header: "Web root dependencies '/' (not checked in this version):"
      footer: "They are added as-is."


  # Augments reportData, that ends up in this form
  #   {
  #     global: { 'underscore': [ 'some/module', 'other/module' ] },
  #     external: { '../../some/external/lib': [ 'some/module' ]}
  #   }
  # @param {Object} resolvedDeps, eg
  #     external:[ '../../some/external/lib', '../../../anotherLib'' ]
  #     notFoundInBundle:[ '../lame/dir', 'another/lame/lib']
  # @param {String} modyle The module name
  addReportData: (resolvedDeps, modyle)->
    for depType, resDeps of resolvedDeps when (not _.isEmpty resDeps) and depType in @interestingDepTypes
        @reportData[depType] = @reportData[depType] || {}
        for resDep in resDeps
          @reportData[depType][resDep] = @reportData[depType][resDep] || []
          @reportData[depType][resDep].push modyle

  reportTemplate: (texts, dependenciesFound)->"""
   \n#{texts.header}
     #{ "'#{dependency}' @ [
       #{("\n         '" +
         mf + "'" for mf in moduleFiles)}\n  ]\n" for dependency, moduleFiles of dependenciesFound
        }#{
     texts.footer}\n
   """

  getReport: ()->
    report = ""
    for depType, depTypesMsgs of dependencyTypesMessages when depType in @interestingDepTypes
      if @reportData[depType]
         report += @reportTemplate depTypesMsgs, @reportData[depType]
    return report


module.exports = DependencyReporter

# inline tests
#rep = new DependencyReporter()
#
#rep.addReportData { dependencies: [ 'data/messages/hello', 'data/messages/bye' ],
#parameters: [],
#requireDependencies: [],
#wrongDependencies: [ 'require(msgLib)' ],
#nodeDependencies: [ '../data/messages/hello', '../data/messages/bye' ],
#webRoot: '..' }, 'some/Module'
#console.log rep.reportData
#console.log rep.getReport()