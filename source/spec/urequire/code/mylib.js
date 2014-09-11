({ urequire: {  // uRequire Module Configuration
     rootExports: ['_B', 'uberscore'],
     noConflict: true
}})

define(['./models/person'], function (person) {

    var add = require('calc/add');
    person.age = add(person.age, 2);

    var calc = require('calc') // loads 'calc/index.js'

    return {
        person: person,
        add: add
    }
});
