require 'open_chain/report'
class ReportsController < ApplicationController
  
  def index
    
  end
  
  def show_tariff_comparison
    @countries = Country.where("id in (select country_id from tariff_sets)").order("name ASC")
  end

  def run_tariff_comparison
    begin
      old_ts = TariffSet.find params['old_tariff_set_id']
      new_ts = TariffSet.find params['new_tariff_set_id']
      friendly_settings = []
      friendly_settings << "Country: #{old_ts.country.name}"
      friendly_settings << "Old Tariff File: #{old_ts.label}"
      friendly_settings << "New Tariff File: #{new_ts.label}"
      ReportResult.run_report! "Tariff Comparison", current_user, OpenChain::Report::TariffComparison, {:settings=>params,:friendly_settings=>friendly_settings}
      add_flash :notices, "Your report has been scheduled. You'll receive a system message when it finishes."
    rescue
      $!.log_me ["Running tariff comparison report.","Params: #{params.to_s}"]
      add_flash :errors, "There was an error running your report: #{$!.message}"
    end
    redirect_to '/reports'
  end

end
