var mongoose = require('mongoose');
var db = mongoose.connect("mongodb://localhost/mydb");

var schema = require('./schema_file.js').somethingSchema;
var Dodad = mongoose.model('Dodad', schema);

mongoose.connection.once('open', function () {

    var newItem = new Dodad({
        something: "Another",
        age: 24
    })
    newItem.save(function (err, doc){
        console.log("Saved to the database: " + doc)
        var query = Dodad.find()
        query.exec(function (err, docs) {
            console.log("Things in the database: " + docs);
        })
    })

});