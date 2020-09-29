var fs = require('fs');
var http = require('http');
var url = require('url');
var ROOT_DIR = "./";

var MongoClient = require('mongodb').MongoClient;
MongoClient.connect("mongodb://localhost/", function(err, db) {
    http.createServer(function (request, res) {
        //Check for request.method and handle database save if POST or serve files below otherwise
        // Look at examples from the book on how to use MongoClient to save something to the database
        var urlObj = url.parse(request.url, true, false);
        fs.readFile(ROOT_DIR + urlObj.pathname, function (err,data) {
            if (err) {
                res.writeHead(404);
                res.end(JSON.stringify(err));
                return;
            }
            res.writeHead(200);
            res.end(data);
        });
    }).listen(8080);

});