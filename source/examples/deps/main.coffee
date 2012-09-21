define ['calc/add', 'data/numbers', 'calc/multiply'], (add, numbers)->
  console.log "main:starting"

  added = add(numbers.a, numbers.b);

  #testing node-style module loading
  multiplied = (require './calc/multiply') numbers.a, numbers.b
  console.log "main:multiplied numbers = ", multiplied

  #testing node-style module loading & relative paths
  numToPowerOf3 = (require 'calc/more/powerof') numbers.a, 2
  console.log "main:numToPowerOf3 = ", numToPowerOf3

  # conditionally load a module (asynchronously)
  message = undefined
  if added > 10
    require ['./actions/greet'], (greet) ->
      message = greet(added)
      console.log "main:message retrieved from greet (#{message})"
  else
    console.log 'main:no greet call, small number: ' + added;

  # this is printed before the message above,
  # right after 'main:started'
  # because the call to require ['actions/greet'] is asynchronous
  console.log "main:returning"

  #return
  added: added
  multiplied:multiplied
  message: message # intentionally, this is undefined, due to the asynchronous AMD-style of 'require [], ->' above
