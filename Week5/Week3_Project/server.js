var io = require('socket.io').listen(8005)

io.sockets.on('connection', function (socket) {
    socket.on('fred', function (msg) {
        socket.broadcast.emit('fred', msg);
    })
})

var fs = require('fs');
var http = require('http');
var url = require('url');
http.createServer(function (req, res) {
    var urlObj = url.parse("./" + req.url, true, false);
    fs.readFile(urlObj.pathname, function (err,data) {
        if (err) {
            res.writeHead(404);
            res.end(JSON.stringify(err));
            return;
        }
        res.writeHead(200);
        res.end(data);
    });
}).listen(8080);