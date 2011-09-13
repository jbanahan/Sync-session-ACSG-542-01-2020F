class ReportResultsController < ApplicationController
  def download
    r = ReportResult.find(params[:id])
    action_secure(r.can_view?(current_user),r,{:verb=>"download",:module_name=>"report",:lock_check=>false}) {
      redirect_to r.secure_url
    }
  end
  
  def index
    r = (current_user.admin? && params[:show_all] && params[:show_all]=='true') ? ReportResult.where(true) : ReportResult.where(:run_by_id=>current_user.id)
    @report_results = r.order("run_at DESC").paginate(:per_page=>20,:page => params[:page])
  end

  def show
    r = ReportResult.find(params[:id])
    action_secure(r.can_view?(current_user),r,{:verb=>"view",:module_name=>"report",:lock_check=>false}) {
      @report_result = r
    }
  end
end
