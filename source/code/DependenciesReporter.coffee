## reporting, in this format
_ = require 'lodash'
_B = require 'uberscore'
Dependency = require './Dependency'

#
# Embarrasing piece of code, full of misnomers and very custom to this project,
# but could refactoreed to support more generic data gathering transformations for reporting
#
# TODO: refactor it to more generic. Make specs
class DependenciesReporter

  constructor: (@interestingDepTypes = _.keys dependencyTypesMessages )->
    @reportData = {}

  dependencyTypesMessages =

    ### 'problematic' ones ###
    untrustedRequireDependencies:
      header: "\u001b[31m Untrusted require('') dependencies found:"
      footer: "They are IGNORED. If evaluated name of the require() isnt in dependency array [..] before require() call, your app WILL HALT and WILL NOT WORK on the web-side (but should be OK on node).\u001b[0m"
    untrustedAsyncDependencies:
      header: "\u001b[31m Untrusted async require(['']) dependencies found:"
      footer: "They are IGNORED. If evaluated name of the require([..]) isnt found, you'll get an http error on web, or exception 'module not found' on node.).\u001b[0m"

    ### simply interesting :-) ###

  DT = Dependency.TYPES
  _B.okv dependencyTypesMessages,
    DT.global,
      header: "Global-looking dependencies (not checked in this version):"
      footer: "They are added as-is."

    DT.notFoundInBundle,
      header: "\u001b[31m Bundle-looking dependencies not found in bundle:",
      footer: "They are added as-is.\u001b[0m"

    DT.external,
      header: "External dependencies (not checked in this version):"
      footer: "They are added as-is."

    DT.webRootMap,
      header: "Web root dependencies '/' (not checked in this version):"
      footer: "They are added as-is."

  reportTemplate: (texts, dependenciesFound)-> """
   \n#{texts.header}
     #{ "'#{dependency}' @ [
       #{("\n         '" +
         mf + "'" for mf in moduleFiles)}\n  ]\n" for dependency, moduleFiles of dependenciesFound
        }#{
     texts.footer}\n
   """

  # Augments reportData, that ends up in this form
  #   {
  #     global: { 'underscore': [ 'some/module', 'other/module' ] },
  #     external: { '../../some/external/lib': [ 'some/module' ]}
  #   }
  #
  # @param {Object} resolvedDeps, eg
  #     global: [ 'lodash' ]
  #     external: [ '../../some/external/lib', '../../../anotherLib'' ]
  #     notFoundInBundle: [ '../lame/dir', 'another/lame/lib']
  #
  # @param {String} modyle The module name, eg 'isAgree.js'
  addReportData: (resolvedDeps, modyle)->
    for depType, resDeps of resolvedDeps when (not _.isEmpty resDeps) and depType in @interestingDepTypes
      @reportData[depType] or= {}
      for resDep in resDeps
        foundModules = (@reportData[depType][resDep] or= [])
        foundModules.push modyle if modyle not in foundModules
    null

  getReport: ()->
    report = ""
    for depType, depTypesMsgs of dependencyTypesMessages when depType in @interestingDepTypes
      if @reportData[depType]
         report += @reportTemplate depTypesMsgs, @reportData[depType]
    return report

module.exports = DependenciesReporter


## some debugging code
#(require('YouAreDaChef').YouAreDaChef DependenciesReporter)
#
#  .before 'addReportData', ( resolvedDeps, modyle)->
#    console.log 'addReportData:', {resolvedDeps, modyle}
#

##inline tests
#rep = new DependenciesReporter()
#
#rep.addReportData {
#    untrustedAsyncDependencies: [ "data + '/messages/hello'", "data + '/messages/bye'" ],
#    notFoundInBundle: ['data/missingLib.js']
#    parameters: [],
#    requireDependencies: [],
#    wrongDependencies: [ 'require(msgLib)' ],
#    nodeDependencies: [ '../data/messages/hello', '../data/messages/bye' ],
#    webRootMap: '..'
#  }
#  , 'some/Module'
#
#console.log rep.reportData
#console.log rep.getReport()
