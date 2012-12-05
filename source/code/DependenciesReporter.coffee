## reporting, in this format
_ = require 'lodash'
_B = require 'uberscore'

log = console.log

#
# Embarrasing piece of code, full of misnomers and very custom to this project,
# but could refactoreed to support more generic data gathering transformations for reporting
#
# TODO: refactor it to more generic. Make specs
class DependenciesReporter

  constructor: (@interestingDepTypes = _.keys(dependencyTypesMessages))->
    @reportData = {}

  dependencyTypesMessages=
    untrustedRequireDependencies:
      header: "\u001b[31m Untrusted require('') dependencies found:"
      footer: "They are IGNORED. If evaluated name of the require() isnt in dependency array [..] before require() call, your app WILL HALT and WILL NOT WORK on the web-side (but should be OK on node).\u001b[0m"
    untrustedAsyncDependencies:
      header: "\u001b[31m Untrusted async require(['']) dependencies found:"
      footer: "They are IGNORED. If evaluated name of the require([..]) isnt found, you'll get an http error on web, or exception 'module not found' on node.).\u001b[0m"
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

  reportTemplate: (texts, dependenciesFound)-> """
   \n#{texts.header}
     #{ "'#{dependency}' @ [
       #{("\n         '" +
         mf + "'" for mf in moduleFiles)}\n  ]\n" for dependency, moduleFiles of dependenciesFound
        }#{
     texts.footer}\n
   """

  reportDep: (dep, modyle)->
    depType =
      if dep.isGlobal()
        'global'
      else # external-looking deps, like '../../../someLib'
        if not (dep.isBundleBoundary() or dep.isWebRoot())
          'external'
        else  # seem to belong to bundle, but not found, like '../myLib'
          if dep.isBundleBoundary() and not (dep.isFound() or dep.isGlobal())
            'notFoundInBundle'
          else  # webRoot deps, like '/assets/myLib'
            if dep.isWebRoot()
              'webRoot'
            else
              ''
    if depType
      @addReportData (_B.okv {}, depType, [dep.resourceName]), modyle

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
      @reportData[depType] or= {}
      for resDep in resDeps
        (@reportData[depType][resDep] or= []).push modyle
    null

  getReport: ()->
    report = ""
    for depType, depTypesMsgs of dependencyTypesMessages when depType in @interestingDepTypes
      if @reportData[depType]
         report += @reportTemplate depTypesMsgs, @reportData[depType]
    return report

module.exports = DependenciesReporter

##inline tests
#rep = new DependenciesReporter()
#
#rep.addReportData {
#    dependencies: [ 'data/messages/hello', 'data/messages/bye' ],
#    parameters: [],
#    requireDependencies: [],
#    wrongDependencies: [ 'require(msgLib)' ],
#    nodeDependencies: [ '../data/messages/hello', '../data/messages/bye' ],
#    webRoot: '..'
#  }
#  , 'some/Module'
#
#console.log rep.reportData
#console.log rep.getReport()
