# checking file-relative dependencies work
define ['../multiply'], (multiply) ->
  (num, toPower)->
    result = 1
    for pow in [1..toPower]
      result = result * num

    result


