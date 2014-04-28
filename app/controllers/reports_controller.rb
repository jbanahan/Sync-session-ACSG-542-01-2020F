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

  def show_drawback_exports_without_imports
    error_redirect "You do not have permission to view this report." unless OpenChain::Report::DrawbackExportsWithoutImports.permission?(current_user)
  end

  def run_drawback_exports_without_imports
    run_report "Drawback Exports Without Imports", OpenChain::Report::DrawbackExportsWithoutImports, {'start_date'=>params[:start_date],'end_date'=>params[:end_date]}, ["Starting Date: #{params[:start_date]}","Ending Date: #{params[:end_date]}"]
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

  def show_foot_locker_billing_summary
    if OpenChain::Report::FootLockerBillingSummary.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_foot_locker_billing_summary
    if OpenChain::Report::FootLockerBillingSummary.permission? current_user
      settings = {'start_date'=>params[:start_date],'end_date'=>params['end_date']}
      run_report "Foot Locker US Billing Summary", OpenChain::Report::FootLockerBillingSummary, settings, ["Invoice date between #{params[:start_date]} and #{params[:end_date]}."]
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_foot_locker_ca_billing_summary
    if OpenChain::Report::FootLockerCaBillingSummary.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_foot_locker_ca_billing_summary
    if OpenChain::Report::FootLockerCaBillingSummary.permission? current_user
      settings = {'start_date'=>params[:start_date],'end_date'=>params['end_date']}
      run_report "Foot Locker CA Billing Summary", OpenChain::Report::FootLockerCaBillingSummary, settings, ["Invoice date between #{params[:start_date]} and #{params[:end_date]}."]
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_das_billing_summary
    if OpenChain::Report::DasBillingSummary.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_das_billing_summary
    if OpenChain::Report::DasBillingSummary.permission? current_user
      settings = {'start_date'=>params[:start_date],'end_date'=>params['end_date']}
      run_report "DAS Canada Billing Summary", OpenChain::Report::DasBillingSummary, settings, ["CADEX sent between #{params[:start_date]} and #{params[:end_date]}."]
    else
      error_redirect "You do not have permission to view this report"
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
      settings = {:mode=>params[:mode], :month=>params[:date][:month], :year=>params[:date][:year], :customer_number => params[:customer_number]}
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

  def show_kitchencraft_billing
    if OpenChain::Report::KitchenCraftBillingReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_kitchencraft_billing
    if OpenChain::Report::KitchenCraftBillingReport.permission? current_user
      settings = {:start_date=>params[:start_date],:end_date=>params[:end_date]}  
      run_report "KitchenCraft Billing", OpenChain::Report::KitchenCraftBillingReport, settings, ["Release Date between #{settings[:start_date]} and #{settings[:end_date]}."]
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_landed_cost
    if OpenChain::Report::LandedCostReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_landed_cost
    if OpenChain::Report::LandedCostReport.permission? current_user
      customer = Company.where(:alliance_customer_number => params[:customer_number]).first
      if customer && customer.can_view?(current_user)
        settings = {:start_date=>params[:start_date],:end_date=>params[:end_date], :customer_number => params[:customer_number]}  
        run_report "Landed Cost Report", OpenChain::Report::LandedCostReport, settings, ["Release Date on or after #{settings[:start_date]} and prior to #{settings[:end_date]}."]
      else
        error_redirect "You do not have permission to view this company"
      end
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_jcrew_billing
    if OpenChain::Report::JCrewBillingReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_jcrew_billing
    if OpenChain::Report::JCrewBillingReport.permission? current_user
      settings = {:start_date => params[:start_date].to_date, :end_date => params[:end_date].to_date}
      run_report "J Crew Billing Report", OpenChain::Report::JCrewBillingReport, settings, ["Invoice Date on or after #{settings[:start_date]} thru #{settings[:end_date]}."]
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_eddie_bauer_ca_statement_summary
    if OpenChain::Report::EddieBauerCaStatementSummary.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_eddie_bauer_ca_statement_summary
    if OpenChain::Report::EddieBauerCaStatementSummary.permission?(current_user)
      settings = {:start_date => params[:start_date].to_date, :end_date => params[:end_date].to_date}
      run_report "Eddie Bauer CA Statement Summary", OpenChain::Report::EddieBauerCaStatementSummary, settings, ["Invoice Date on or after #{settings[:start_date]} and prior to #{settings[:end_date]}."]
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_hm_statistics
    if OpenChain::Report::HmStatisticsReport.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_hm_statistics
    if OpenChain::Report::HmStatisticsReport.permission?(current_user)
      settings = {:start_date => params[:start_date].to_date, :end_date => params[:end_date].to_date}
      run_report "H&M Statistics Report", OpenChain::Report::HmStatisticsReport, settings, ["On or after #{settings[:start_date]} and prior to #{settings[:end_date]}."]
    else
      error_redirect "You do not have permission to view this report."
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
