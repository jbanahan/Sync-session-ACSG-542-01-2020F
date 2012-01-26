require 'open_chain/report'
class ReportsController < ApplicationController
  
  def index
    
  end
  
  def show_tariff_comparison
    @countries = Country.where("id in (select country_id from tariff_sets)").order("name ASC")
  end

  def run_tariff_comparison
    old_ts = TariffSet.find params['old_tariff_set_id']
    new_ts = TariffSet.find params['new_tariff_set_id']
    friendly_settings = []
    friendly_settings << "Country: #{old_ts.country.name}"
    friendly_settings << "Old Tariff File: #{old_ts.label}"
    friendly_settings << "New Tariff File: #{new_ts.label}"
    run_report "Tariff Comparison", OpenChain::Report::TariffComparison, params, friendly_settings
  end

  def show_stale_tariffs
    #nothing to do here, no report options
  end

  def run_stale_tariffs
    run_report "Stale Tariffs", OpenChain::Report::StaleTariffs, {}, []
  end

  def show_shoes_for_crews_entry_breakdown
    #nothing to do here
  end
  def run_shoes_for_crews_entry_breakdown
    run_report "Shoes For Crews", OpenChain::Report::ShoesForCrewsEntryBreakdown, {}, []
  end
  def show_poa_expirations
    if current_user.admin?
      render
    else
      error_redirect "You do not have permissions to view this report"
    end
  end

  def run_poa_expirations
    if current_user.admin?
      begin
        Date.parse(params[:poa_expiration_date])
        expire_later = PowerOfAttorney.where(["expiration_date > ?", params[:poa_expiration_date]]).select(:company_id).map(&:company_id)
        @poas = PowerOfAttorney.includes(:company).where(["expiration_date <= ?", params[:poa_expiration_date]]).order("companies.name ASC, expiration_date DESC").select do |poa|
          poa unless expire_later.include?(poa.company_id)
        end.uniq_by {|poa| poa.company_id}.paginate(:per_page => 20, :page => params[:page])
      rescue ArgumentError
        add_flash :errors, "Invalid date. Report will not be executed"
        redirect_to reports_show_poa_expirations_path
      rescue TypeError
        add_flash :errors, "Invalid date. Report will not be executed"
        redirect_to reports_show_poa_expirations_path
      end
    else
      error_redirect "You do not have permissions to view this report"
    end
  end

  private
  def run_report name, klass, settings, friendly_settings
    begin
      ReportResult.run_report! name, current_user, klass, {:settings=>settings,:friendly_settings=>friendly_settings}
      add_flash :notices, "Your report has been scheduled. You'll receive a system message when it finishes."
    rescue
      $!.log_me ["Running #{klass.to_s} report.","Params: #{params.to_s}"]
      add_flash :errors, "There was an error running your report: #{$!.message}"
    end
    redirect_to '/reports'
  end

end
