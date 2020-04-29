class TextileController < ApplicationController
  # no security risk because we're just echoing back what was sent from the browser
  skip_before_filter :require_user
  skip_before_filter :set_user_time_zone

  def preview
    if params[:c]
      render html: RedCloth.new(params[:c]).to_html.html_safe
    else
      render html: ""
    end
  end
end
