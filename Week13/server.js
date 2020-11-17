var express = require('express');
var app = express();
var mongoose = require('mongoose');

var db = mongoose.connect('mongodb://localhost/namesdb');
var nameSchema = require('./name_schema.js').nameSchema;
var Names = mongoose.model('Names', nameSchema);

app.use(express.json());

mongoose.connection.once('open', function(){
    app.use(express.static('delete-edit-demo/dist/delete-edit-demo/'))
    app.use('/', express.query());

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
        console.log(newName)
        newName.save(function (err, doc) {
            response.status(200);
            response.send(JSON.stringify(doc));
        })
    })

    app.listen(8080, function () {
        console.log('Application is running!');
    })

    app.delete('/name/*', function (req, res){
        console.log(req.params[0])

        query = Names.deleteOne({'_id': req.params[0]});
        query.exec(function (err) {
                res.status(200);
                res.send(JSON.stringify({}));
            }
        );
    })
});
