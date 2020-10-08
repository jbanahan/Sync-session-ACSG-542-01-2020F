var fs = require('fs');
var http = require('http');
var url = require('url');
var ROOT_DIR = "../front-end";

// New Stuff
var mongoose = require('mongoose');
var db = mongoose.connect('mongodb://localhost/mydb');
var itemSchema = require('./item_schema.js').itemSchema;
var Items = mongoose.model('Items', itemSchema);

mongoose.connection.once('open', function(){
    http.createServer(function (request, response) {
        if (request.method === "POST") {
            var jsonData = "";
            request.on('data', function (chunk) {
                jsonData += chunk;
            });
            request.on('end', function () {
                var reqObj = JSON.parse(jsonData);
                var newItem = new Items({
                    item: reqObj.item
                });

                newItem.save(function (err, doc) {
                    console.log(doc);
                })

                response.writeHead(200);
                response.end(JSON.stringify({}));
            })

        } else if (request.method === "GET" && request.url === "/list") {
            var query = Items.find();
            query.exec(function (err, docs){
                response.writeHead(200);
                response.end(JSON.stringify({docs}));
            });
        } else {
            var urlObj = url.parse(request.url, true, false);
            fs.readFile(ROOT_DIR + urlObj.pathname, function (err,data) {
                response.writeHead(200);
                response.end(data);
            });
        }
    }).listen(8080);
});
