require 'open_chain/business_rule_validation_results_support'
require 'open_chain/activity_summary'
require 'open_chain/email_validation_support'

module Api; module V1; class EntriesController < Api::V1::ApiCoreModuleControllerBase
  include OpenChain::BusinessRuleValidationResultsSupport
  include OpenChain::EmailValidationSupport

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

  def email_us_activity_summary_download
    email_activity_summary_download params[:importer_id], "US", params[:addresses], params[:subject], params[:body]
  end

  def email_ca_activity_summary_download
    email_activity_summary_download params[:importer_id], "CA", params[:addresses], params[:subject], params[:body]
  end

  private

  def email_activity_summary_download importer_id, iso_code, _addresses, _subject, _body
    klass = OpenChain::ActivitySummary::EntrySummaryDownload
    email_blank_or_valid = nil
    action_secure(klass.permission?(current_user, params[:importer_id]), nil) do
      begin
        email_blank_or_valid = params[:addresses].blank? || email_list_valid?(params[:addresses])
        if email_blank_or_valid
          klass.delay.email_report importer_id, iso_code, params[:addresses], params[:subject], params[:body], current_user.id, params[:mailing_list]
        end
      rescue StandardError => e
        e.log_me ["Running/emailing #{klass} report. Params: {params.to_s}"]
        render_error "There was an error running your report: #{e.message}"
        return
      end
      email_blank_or_valid ? render_ok : render_error("Invalid email address")
    end
  end

  def store_activity_summary_download name, iso_code
    klass = OpenChain::ActivitySummary::EntrySummaryDownload
    action_secure(klass.permission?(current_user, params[:importer_id]), nil) do
      begin
        ReportResult.run_report! name, current_user, klass, {settings: {iso_code: iso_code, importer_id: params[:importer_id]}}
      rescue StandardError => e
        e.log_me ["Running #{klass} report.", "Params: #{params}"]
        render_error "There was an error running your report: #{e.message}"
        return
      end
      render_ok
    end
  end

end; end; end
