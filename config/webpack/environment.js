const { environment } = require('@rails/webpacker')
const erb =  require('./loaders/erb')
const coffee =  require('./loaders/coffee')
const webpack = require('webpack')

// JQuery is called useing several different methods and we let webpack
// know that we just always mean jquery
environment.plugins.prepend('Provide', new webpack.ProvidePlugin({
  $: 'jquery/src/jquery',
  jQuery: 'jquery/src/jquery',
  jquery: 'jquery',
  'window.jQuery': 'jquery',
  moment: 'moment',
  Popper: ['popper.js', 'default']
}))

environment.loaders.append('coffee', coffee)
environment.loaders.append('erb', erb)
module.exports = environment
