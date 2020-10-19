var express = require('express');
var app = express();
var bodyParser = require('body-parser');

var mongoose = require('mongoose');
var db = mongoose.connect('mongodb://localhost/mydb');
var itemSchema = require('./item_schema.js').itemSchema;
var Items = mongoose.model('Items', itemSchema);

mongoose.connection.once('open', function(){
    app.use(bodyParser.urlencoded({extended: true}));
    app.use(express.static('../front-end'))
    app.use('/', express.query());

    app.post('/save', function (request, response) {
        var newItem = new Items({
            item: request.body.item
        });
        newItem.save(function (err, doc) {
            console.log(doc);
            response.status(200);
            response.send(JSON.stringify({}));
        })
    })

    app.get('/list', function (request, response) {
        var query = Items.find();
        query.exec(function (err, docs){
            response.status(200);
            response.send(JSON.stringify({docs}));
        });
    })

    app.delete('/', function (request, response) {
        Items.deleteOne({_id: request.query.id}).exec(function (err) {
            response.status(200);
            response.send(JSON.stringify({}));
        })
    });

    app.listen(8080, function () {
        console.log('Application is running!');
    })
});
