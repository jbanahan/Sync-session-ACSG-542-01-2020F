var filesystem = require('fs');
var http = require('http');
var url = require('url');

http.createServer(function (request, response){
    var urlObj = url.parse("../frontend" + request.url, true, false);

    if (request.method === "GET") {
        filesystem.readFile(urlObj.pathname, function (error, data) {
            response.writeHead(200);
            response.end(data);
        })
    }
}).listen(8080)