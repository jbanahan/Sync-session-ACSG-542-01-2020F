const { environment } = require('@rails/webpacker')
const coffee =  require('./loaders/coffee')
const webpack = require('webpack')

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
//   Module not found: Error: Can't resolve './locale' in ..
new webpack.ContextReplacementPlugin(/^\.\/locale$/, context => {
  if (!/\/moment\//.test(context.context)) return

  Object.assign(context, {
    regExp: /^\.\/\w+/,
    request: '../locale', // resolved relatively
  })
})

environment.loaders.append('coffee', coffee)
module.exports = environment
