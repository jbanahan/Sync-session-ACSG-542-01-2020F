var mongoose = require('mongoose');
var Schema = mongoose.Schema;
var somethingSchema = new Schema({
    something: {type: String},
    age: {type: Number}
}, {collection: 'something_collection'});
exports.somethingSchema = somethingSchema;