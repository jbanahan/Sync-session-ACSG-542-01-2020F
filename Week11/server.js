var express = require('express');
var app = express();
var mongoose = require('mongoose');

var db = mongoose.connect('mongodb://localhost/namesdb');
var nameSchema = require('./name_schema.js').nameSchema;
var Names = mongoose.model('Names', nameSchema);

mongoose.connection.once('open', function(){
    app.use(express.static('services-navigation-demo/dist/services-navigation-demo/'))
    app.use('/', express.query());
    app.use(express.json());

    app.get('/names', function (request, response) {
        var query = Names.find();
        query.exec(function (err, docs){
            response.status(200);
            response.send(JSON.stringify({docs}));
        });
    })

    app.post('/name', function (request, response) {
        var newName = new Names({
            name: request.body.name
        });
        newName.save(function (err, doc) {
            response.status(200);
            response.send(JSON.stringify(doc));
        })
    })

    app.listen(8080, function () {
        console.log('Application is running!');
    })
});
