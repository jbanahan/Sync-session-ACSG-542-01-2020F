# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += %w( login.js login.css legacy.js html5shim.js vendor_portal.js vendor_portal.css 
                                                  trade_lanes.js trade_lanes.css chain_vendor_maint.css chain_vendor_maint.js chain_admin.css 
                                                  chain_admin.js pdfobject.js jquery_ujs.js)