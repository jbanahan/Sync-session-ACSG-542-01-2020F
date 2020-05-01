class VendorPortalController < ApplicationController
  def index
    @portal_mode = "vendor"
    render layout: false
  end
end
