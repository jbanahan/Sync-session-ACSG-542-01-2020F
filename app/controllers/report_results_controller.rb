require 'open_chain/report'

class ReportResultsController < ApplicationController
  include DownloadS3ObjectSupport

  def set_page_title
    @page_title ||= 'Report'
  end

  def download
    r = ReportResult.find(params[:id])
    action_secure(r.can_view?(current_user),r,{:verb=>"download",:module_name=>"report",:lock_check=>false}) {
      data = r.report_data
      type = Mime::Type.lookup_by_extension(File.extname(data.original_filename.to_s)[1..-1]).to_s.presence
      download_s3_object data.options[:bucket], data.path, disposition: "attachment", content_type: type
    }
  end
  
  def index
    @show_basic = current_user.company.master? || current_user.view_entries?
    @customizable_reports = []
    [
      CustomReportEntryInvoiceBreakdown, CustomReportTieredEntryInvoiceBreakdown, CustomReportBillingAllocationByValue, 
      CustomReportBillingStatementByPo, CustomReportEntryBilling, CustomReportContainerListing, CustomReportEntryBillingBreakdownByPo, 
      CustomReportAnnSapChanges, CustomReportIsfStatus, CustomReportEntryTariffBreakdown
    ].each do |rpt|
      @customizable_reports << rpt if rpt.can_view?(current_user)
    end
    @current_custom_reports = current_user.custom_reports.order("name ASC").all
    r = (current_user.admin? && params[:show_all] && params[:show_all]=='true') ? ReportResult.all : ReportResult.where(:run_by_id=>current_user.id)
    @report_results = r.order("run_at DESC").paginate(:per_page=>20,:page => params[:page])
  end

  def show
    r = ReportResult.find(params[:id])
    action_secure(r.can_view?(current_user),r,{:verb=>"view",:module_name=>"report",:lock_check=>false}) {
      @report_result = r
    }
  end
end
