define ['./add'], (add)->

  return {
    add: add
    multiply: require 'calc/multiply'
  }