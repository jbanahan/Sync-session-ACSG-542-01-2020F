var express = require('express')
var app = express()

var mongoose = require('mongoose');
var db = mongoose.connect('mongodb://localhost/mydb');

var itemSchema = require('./item_schema.js').itemSchema;
var Items = mongoose.model('Items', itemSchema);

mongoose.connection.once('open', function(){
    app.use('/', express.query());

    app.delete("/", function (request, response) {
        // Items.remove({_id: request.query.id}).exec()
        console.log(request.query)
        Items.deleteOne({_id: request.query.id}).exec()
    })

    app.listen(8080, function (){
        console.log('Application is running!');
    });
});