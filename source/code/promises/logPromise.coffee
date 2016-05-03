module.exports = (l) ->
  throw "not (l instanceof _B.Logger)" if not (l instanceof _B.Logger)

  logPromise = (promisingFn, fnName='not-named promising function', resultName='result', rejectName='reject') ->
    throw new Error '1st param must be a promise-returning function' if not _.isFunction promisingFn
    (args...) ->
      (argsClone = _.clone args).unshift "#{fnName} called with:\n"
      l.debug.apply l, argsClone
      (promisingFn.apply @, args).then(
        (res) ->
          head = "#{fnName} #{resultName} is:\n"
          if _.isArray res
            (resLog = _.clone res).unshift head
          else
            resLog = [head, res]
          l.debug.apply l, resLog
          res
      , (rej) ->
        head = "#{fnName} #{rejectName} is:\n"
        if _.isArray rej
          (rejLog = _.clone rej).unshift head
        else
          rejLog = [head, rej]
        l.err.apply l, rejLog
        throw rej
      )
