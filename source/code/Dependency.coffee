class Dependency
  constructor: (dep)->
    indexOfSep = dep.indexOf '!'
    @pluginName = (if indexOfSep >= 0 then dep[0..indexOfSep-1] else '').replace /\\/g, '/'
    @resourceName = (if indexOfSep >= 0 then dep[indexOfSep+1..dep.length-1] else dep).replace /\\/g, '/'

  toString:-> "#{dep.pluginName}!#{dep.resourceName}"

_ = require 'lodash'

dep1 = new Dependency 'node!mystuf\\aa'
dep1a = new Dependency 'node!mystuf\\aa'


#dep2 = new Dependency 'text!mystuf\\bbc'
#
##console.log "#{dep1.pluginName}!#{dep1.resourceName}"
##console.log dep1 + ""
#
#
#deps1 = [dep1, dep2 ]
#
#deps2 = [ dep1, dep2,
#    new Dependency 'node!mystuf\\aa'
#    new Dependency 'text!mystuf\\bbd'
#]
#
#
#
#diff = _.difference deps2, deps1
#
#console.log d for d in diff