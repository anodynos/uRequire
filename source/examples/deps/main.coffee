define ['calc/add', 'data/numbers', 'calc/multiply'], (add, numbers)->
  console.log "main:starting"

  sum = add(numbers.a, numbers.b);
  console.log "main:sum = ", sum

  #testing node-style file relative paths
  product = (require './calc/multiply') numbers.a, numbers.b
  console.log "main:product = ", product

  #testing amd-style bundle relative paths
  numToPowerOf3 = (require 'calc/more/powerof') numbers.a, 3
  console.log "main:numToPowerOf3 = ", numToPowerOf3

  # conditionally load a module (asynchronously)
  message = undefined
  if sum > 10
    require ['actions/greet'], (greet) ->
      message = greet(sum)
      console.log "main:message from greet (#{message})"
  else
    console.log 'main:no greet call, small number: ' + sum

  # printed before 'main:message from greet' above,
  # due to asynchronous call to require ['actions/greet']
  console.log "main:returning"

  #return
  added: sum
  multiplied:product
  message: message # intentionally undefined, due to the asynchronous AMD-style of 'require [], ->' above
