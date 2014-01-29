class HomeController < ApplicationController
  def index
    # Let user logging in know they're using an outdated browser and will have reducded search screen functionality.
    # Added here because this action is the root application controller/action.
    if old_ie_version? 
      add_flash :notices, "Because you are using an older version of Internet Explorer, the search/report screens will have reduced functionality, showing only 10 search results per page.  Please consider upgrading or using the Chrome browser instead."
      flash.keep
    end

    unless current_user.homepage.blank?
      redirect_to current_user.homepage
    else
      redirect_to dashboard_widgets_path
    end
  end
end