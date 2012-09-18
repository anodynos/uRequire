# checking file-relative dependencies also work
define ['./add'], (add) ->
  (num, byNum) ->
    result = 0;
    for times in [1..byNum]
      result += num

    result