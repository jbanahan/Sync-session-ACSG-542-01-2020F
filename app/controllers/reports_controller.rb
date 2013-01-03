require 'open_chain/report'
class ReportsController < ApplicationController
  
  def index
    redirect_to report_results_path
  end

  def show_product_sync_problems

  end
  def run_product_sync_problems
    run_report "Product Sync Problems", OpenChain::Report::ProductSyncProblems, {}, []
  end
  # show the user a message if their report download has been delayed
  def show_big_search_message
    
  end

  def show_products_without_attachments
  end
  def run_products_without_attachments
    run_report "Products Without Attachments", OpenChain::Report::ProductsWithoutAttachments, {}, []
  end

  def show_attachments_not_matched
  end
  def run_attachments_not_matched
    run_report "Attachments Not Matched", OpenChain::Report::AttachmentsNotMatched, {}, []
  end

  def show_containers_released
  end
  def run_containers_released
    settings = {}
    settings['arrival_date_start'] = params[:arrival_date_start] unless params[:arrival_date_start].blank?
    settings['arrival_date_end'] = params[:arrival_date_end] unless params[:arrival_date_end].blank?
    customer_numbers = []
    params[:customer_numbers].lines {|l| customer_numbers << l.strip unless l.strip.blank?} unless params[:customer_numbers].blank?
    settings['customer_numbers'] = customer_numbers unless customer_numbers.blank?
    fs = ["Arrival date between #{settings['arrival_date_start'].blank? ? "ANY" : settings['arrival_date_start']} and #{settings['arrival_date_end'].blank? ? "ANY" : settings['arrival_date_end']}"]
    fs << "Only customer numbers #{customer_numbers.join(", ")}" unless customer_numbers.blank?
    run_report "Container Release Status", OpenChain::Report::ContainersReleased, settings, fs
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
      run_report "POA Expirations", OpenChain::Report::POAExpiration, { "poa_expiration_date" => params[:poa_expiration_date] }, []
    else
      error_redirect "You do not have permissions to view this report"
    end
  end

  def show_eddie_bauer_statement_summary
    if OpenChain::Report::EddieBauerStatementSummary.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_eddie_bauer_statement_summary
    if OpenChain::Report::EddieBauerStatementSummary.permission?(current_user)
      settings = {:mode=>params[:mode]}
      run_report "Eddie Bauer Statement Summary", OpenChain::Report::EddieBauerStatementSummary, settings, ["Mode: #{settings[:mode=>'previous_month'] ? "All Entries From Previous Month" : "All Entries Not Paid"}"]
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_marc_jacobs_freight_budget
    if OpenChain::Report::MarcJacobsFreightBudget.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_marc_jacobs_freight_budget
    if OpenChain::Report::MarcJacobsFreightBudget.permission? current_user
      year = params[:year]
      month = params[:month]
      run_report "Marc Jacobs Freight Budget - #{year}-#{month}", OpenChain::Report::MarcJacobsFreightBudget, {:year=>year,:month=>month}, ["Month: #{year}-#{month}"] 
    else
      error_redirect "You do not have permission to view this report"
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
    redirect_to report_results_path
  end

end
