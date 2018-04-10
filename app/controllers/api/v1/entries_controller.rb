require 'open_chain/business_rule_validation_results_support'
require 'open_chain/activity_summary'

module Api; module V1; class EntriesController < Api::V1::ApiCoreModuleControllerBase
  include OpenChain::BusinessRuleValidationResultsSupport

  def validate 
    ent = Entry.find params[:id]
    run_validations ent
  end

  def store_us_activity_summary_download
    store_activity_summary_download "US Activity Summary", "US"
  end

  def store_ca_activity_summary_download
    store_activity_summary_download "CA Activity Summary", "CA"
  end

  private

  def store_activity_summary_download name, iso_code
    klass = OpenChain::ActivitySummary::EntrySummaryDownload
    action_secure(klass.permission?(current_user, params[:importer_id]), nil) {
      begin
        ReportResult.run_report! name, current_user, klass, {:settings=>{iso_code: iso_code, importer_id: params[:importer_id]}}
      rescue => e
        e.log_me ["Running #{klass.to_s} report.","Params: #{params.to_s}"]
        render_error "There was an error running your report: #{e.message}"
        return
      end
      render_ok
    }
  end

end; end; end    
