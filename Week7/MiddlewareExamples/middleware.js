var express = require('express')
var app = express();

app.use('/', express.static('./static'));
app.use('/gallery', express.static('./images', {maxAge:60*60*1000})); // 1000 millisecond to second

// Separate examples p369
app.use('/your/path', express.logger())
    .use('/your/path', express.bodyParser())
    .use('/your/path', express.query());

// Custom Middleware example on p381
function someCustomMiddleware(request, response, next) {
    console.log("Our middleware was used!");
    next();
}
app.use(someCustomMiddleware);
app.get('/any/path', function (req, res) {
    res.send("test");
})

// never do this for this class, you should have nginx setup in front of web server anyway to redirect 80 and 443 requests to 8080
app.listen(80);