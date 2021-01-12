const path = require('path')

// We need to make our global variables available to the entire app
// This is not how webpacker likes to work so we force it here
module.exports = {
  resolve: {
    alias: {
      'ChainAllPages': path.resolve(__dirname, '../every_page/chain_all_pages')
    }
  }
}
