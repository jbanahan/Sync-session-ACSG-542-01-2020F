class LogoController < ApplicationController
  skip_before_filter :require_user
  def logo
    image_file = master_setup.logo_image.blank? ? "vfi_logo.png" : master_setup.logo_image
    send_file "public/images/#{image_file}", type: 'image/png', disposition: 'inline'
  end
end