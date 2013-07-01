class DashboardWidgetsController < ApplicationController
  def index
    # Let user logging in know they're using an outdated browser and will have reducded search screen functionality.
    # Added here because this action is the root application controller/action.
    if old_ie_version? 
      add_flash :notices, "Because you are using an older version of Internet Explorer, the search/report screens will have reduced functionality, showing only 10 search results per page.  Please consider upgrading or using the Chrome browser instead."
    end

    @widgets = current_user.dashboard_widgets
    render :layout=>'one_col'
  end

  def edit
    @widgets = current_user.dashboard_widgets
    @searches = current_user.search_setups.order("module_type ASC")
  end
  def save
    to_save = params[:dashboard_widget]
    current_user.dashboard_widgets.destroy_all
    to_save.each do |k,v|
      unless v[:search_setup_id]=="none"
        ss = SearchSetup.find(v[:search_setup_id])
        if !ss.nil? && ss.user_id == current_user.id
          ss.dashboard_widgets.create(:rank=>v[:rank],:user_id=>current_user.id)
        end
      end
    end
    redirect_to root_path
  end

  def legacy_javascripts?
    false
  end
end
