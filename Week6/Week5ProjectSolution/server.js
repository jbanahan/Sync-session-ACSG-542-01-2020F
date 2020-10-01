var http = require('http');
var fs = require('fs');
var url = require('url');
var ROOT_DIR = "./";
var MongoClient = require('mongodb').MongoClient;

MongoClient.connect("mongodb://localhost/", function(err, db) {
    http.createServer(function (req, res) {
        if (req.method === "POST") {
            var jsonData = "";
            req.on('data', function (chunk) {
                jsonData += chunk;
            });
            req.on('end', function () {
                var requestObject = JSON.parse(jsonData);
                var myDB = db.db("yourdatabasename");
                myDB.collection("todo", function(err, todo){
                    todo.save(requestObject, function(err, results){
                        console.log(results);
                    });
                });
                res.writeHead(200);
                res.end(JSON.stringify({}));
            });
        } else {
            var urlObj = url.parse(req.url, true, false);
            fs.readFile(ROOT_DIR + urlObj.pathname, function (err,data) {
                if (err) {
                    res.writeHead(404);
                    res.end(JSON.stringify(err));
                    return;
                }
                res.writeHead(200);
                res.end(data);
            });
        }
    }).listen(8080);
});

