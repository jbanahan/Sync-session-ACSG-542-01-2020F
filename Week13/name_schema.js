var mongoose = require('mongoose');
var Schema = mongoose.Schema;
var nameSchema = new Schema({
    name: {type: String, index: 1, require:true}
}, {collection: 'names'});
exports.nameSchema = nameSchema;
