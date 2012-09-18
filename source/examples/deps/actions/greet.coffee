define ['../data/messages/hello', 'data/messages/bye'], ()->
  (num)->
    console.log('greet:started')

    if num
      msgLib = if num > 20 then 'data/messages/hello' else 'data/messages/bye'
      message = require(msgLib) + ". The number passed is #{num}"
      console.log "greet:sync message retrieved"
    else
      message = "Hello, world!"

    console.log "greet:returning"
    return message

