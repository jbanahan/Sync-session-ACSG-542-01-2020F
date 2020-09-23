var io = require('socket.io').listen(8001)
var nicknames = {};

io.sockets.on('connection', function (socket) {
    socket.on('user message', function (msg) {
        socket.broadcast.emit('user message', socket.nickname, msg);
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
})