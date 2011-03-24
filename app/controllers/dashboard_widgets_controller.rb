class DashboardWidgetsController < ApplicationController
  def index
    @widgets = current_user.dashboard_widgets
  end
end
