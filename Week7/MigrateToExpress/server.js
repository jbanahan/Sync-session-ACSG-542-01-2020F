var express = require('express')
var app = express()
var MongoClient = require('mongodb').MongoClient;

MongoClient.connect("mongodb://localhost/", function(err, db) {
    app.post('*', function (req, res) {
        var jsonData = "";
        req.on('data', function (chunk) {
            jsonData += chunk;
        });
        req.on('end', function () {
            var requestObject = JSON.parse(jsonData);
            var myDB = db.db("yourdatabasename");
            myDB.collection("todo", function (err, todo) {
                todo.save(requestObject, function (err, results) {
                    console.log(results);
                });
            });
            res.status(200);
            res.send(JSON.stringify({}));
        });
    });
    app.use(express.static('./public'))

    app.listen(8080, function (){
        console.log('Application is running!');
    })
});

