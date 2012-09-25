# checking bundle-relative dependencies work
define ['calc/add'], (add) ->
  (num, byNum) ->
    result = 0;
    for times in [1..byNum]
      result += num

    result