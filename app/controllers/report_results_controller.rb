class ReportResultsController < ApplicationController
  def download
    r = ReportResult.find(params[:id])
    action_secure(r.can_view?(current_user),r,{:verb=>"download",:module_name=>"report",:lock_check=>false}) {
      redirect_to r.secure_url
    }
  end
  
  def index
    @show_basic = current_user.company.master? || current_user.view_entries?
    @customizable_reports = []
    [
      CustomReportEntryInvoiceBreakdown, CustomReportBillingAllocationByValue, CustomReportBillingStatementByPo, 
      CustomReportContainerListing, CustomReportEntryBillingBreakdownByPo, CustomReportAnnSapChanges
    ].each do |rpt|
      @customizable_reports << rpt if rpt.can_view?(current_user)
    end
    @current_custom_reports = current_user.custom_reports.order("name ASC").all
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
