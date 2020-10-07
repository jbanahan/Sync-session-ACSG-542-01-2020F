var express = require('express')
var app = express()
var MongoClient = require('mongodb').MongoClient;
var bodyParser = require('body-parser');

MongoClient.connect("mongodb://localhost/", function(err, db) {
    app.use(bodyParser.urlencoded({extended: true}));

    app.post('*', function (request, res) {
        var myDB = db.db("yourdatabasename");
        myDB.collection("todo", function (err, todo) {
            todo.save(request.body, function (err, results) {
                console.log(results)
                res.status(200);
                res.send(JSON.stringify({}));
            });
        });

    });
    app.use(express.static('./public'))

    app.listen(8080, function (){
        console.log('Application is running!');
    })
});

