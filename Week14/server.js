var express = require('express');
var app = express();
app.use(express.json());
app.use(express.static('socket-examples-angular/dist/socket-examples-angular'))
app.listen(8080, function () {
    console.log('Application is running!');
})

var io = require('socket.io').listen(8001)
var nicknames = {};

io.sockets.on('connection', function (socket) {
    socket.on('user message', function (msg) {
        // You're going to want to include the nickname for the final project - IM project only
        // socket.broadcast.emit('user message', socket.nickname, msg);
        socket.broadcast.emit('user message', msg);
    })

    socket.on('nickname', function (nick, callback) {
        if (nicknames[nick]) {
            callback(true)
        } else {
            callback(false)
            nicknames[nick] = nick;
            socket.nickname = nick;

            io.sockets.emit('nicknames', nicknames);
        }
    })

    socket.on('timer', function (start) {
        if (start) {
            // Add the current datetime to the db
            console.log('Timer has started!')
        } else {
            console.log('Timer has stopped!')
            // Get appropriate datetime from db
            // Remove the datetime from the db
        }
    })
})
