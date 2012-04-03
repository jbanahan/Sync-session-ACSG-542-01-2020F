class TextileController < ApplicationController
  #no security risk because we're just echoing back what was sent from the browser
  skip_before_filter :require_user
  skip_before_filter :set_user_time_zone
  skip_before_filter :log_request
  def preview
    if params[:c]
      render :text=>RedCloth.new(params[:c]).to_html  
    else
      render :text=>""
    end
  end
end
