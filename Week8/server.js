var express = require('express')
var app = express()
var bodyParser = require('body-parser')

url.location === "/save" && req.mothed === "POST"

// localhost:8080/find?item=12341234
app.use(bodyParser.urlencoded({extended: true}))

app.post('/save', function (req, res) {
    // save to database
});

app.delete('/remove', function (req, res){
    query = itemSchema.deleteOne({'item': req.body.item});
    query.exec();
})