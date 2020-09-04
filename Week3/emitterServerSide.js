var EventEmitter = require('events');

var myEmitter = new EventEmitter();
myEmitter.on('something', function() {
    console.log("Emitter has been called!")
})

myEmitter.emit('something');