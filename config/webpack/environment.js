const { environment } = require('@rails/webpacker')
const erb =  require('./loaders/erb')
const coffee =  require('./loaders/coffee')
const webpack = require('webpack')

// See in config/webpack/custom file for addtional details
const customConfig = require('./custom')
environment.config.merge(customConfig)

// JQuery is called useing several different methods and we let webpack
// know that we just always mean jquery
environment.plugins.prepend('Provide', new webpack.ProvidePlugin({
  $: 'jquery/src/jquery',
  jQuery: 'jquery/src/jquery',
  jquery: 'jquery',
  'window.jQuery': 'jquery',
  Popper: ['popper.js', 'default']
}))

// Fixes warning in moment-with-locales.min.js
//   Module not found:E rror: Can't resolve './locale' in ..
new webpack.ContextReplacementPlugin(/^\.\/locale$/, context => {
  if (!/\/moment\//.test(context.context)) return

  Object.assign(context, {
    regExp: /^\.\/\w+/,
    request: '../locale', // resolved relatively
  })
})

environment.loaders.append('coffee', coffee)
environment.loaders.append('erb', erb)
module.exports = environment
