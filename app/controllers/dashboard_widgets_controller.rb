class DashboardWidgetsController < ApplicationController
  def index
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
end
