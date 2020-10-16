var mongoose = require('mongoose');
var Schema = mongoose.Schema;
var itemSchema = new Schema({
    item: {type: String, index: 1, require:true}
}, {collection: 'todo'});
exports.itemSchema = itemSchema;