require 'open_chain/report'
require 'open_chain/s3'

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
    settings['arrival_start_date'] = params[:arrival_start_date] unless params[:arrival_start_date].blank?
    settings['arrival_end_date'] = params[:arrival_end_date] unless params[:arrival_end_date].blank?
    customer_numbers = []
    params[:customer_numbers].lines {|l| customer_numbers << l.strip unless l.strip.blank?} unless params[:customer_numbers].blank?
    settings['customer_numbers'] = customer_numbers unless customer_numbers.blank?
    fs = ["Arrival date between #{settings['arrival_start_date'].blank? ? "ANY" : settings['arrival_start_date']} and #{settings['arrival_end_date'].blank? ? "ANY" : settings['arrival_end_date']}"]
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

  def show_j_jill_weekly_freight_summary
    if OpenChain::Report::JJillWeeklyFreightSummaryReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end
  def run_j_jill_weekly_freight_summary
    run_report "J Jill Weekly Freight Summary", OpenChain::Report::JJillWeeklyFreightSummaryReport, {}, []
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

  def show_hm_ok_log
    if OpenChain::Report::HmOkLog.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_hm_ok_log
    if OpenChain::Report::HmOkLog.permission?(current_user)
      run_report "H&M OK Log", OpenChain::Report::HmOkLog, {}, []
    else
      error_redirect "You do not have permission to view this report."
    end
  end

  def show_daily_first_sale_exception_report
    if OpenChain::Report::DailyFirstSaleExceptionReport.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_daily_first_sale_exception_report
    if OpenChain::Report::DailyFirstSaleExceptionReport.permission?(current_user)
      run_report "Daily First Sale Exception Report", OpenChain::Report::DailyFirstSaleExceptionReport, {}, []
    else
      error_redirect "You do not have permission to view this report."
    end
  end
  
  def show_duty_savings_report
    if OpenChain::Report::DutySavingsReport.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_duty_savings_report
    if OpenChain::Report::DutySavingsReport.permission?(current_user)
      settings = {"start_date" => params[:start_date], 
                  "end_date" => params[:end_date], 
                  "customer_numbers" => params[:customer_numbers].delete("\r\;, ").split("\n")}
      run_report "Duty Savings Report", OpenChain::Report::DutySavingsReport, settings, []
    else
      error_redirect "You do not have permission to view this report."
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

  def show_deferred_revenue
    if OpenChain::Report::AllianceDeferredRevenueReport.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_deferred_revenue
    if OpenChain::Report::AllianceDeferredRevenueReport.permission?(current_user)
      settings = {:start_date => params[:start_date].to_date,}
      run_report "Deferred Revenue Report", OpenChain::Report::AllianceDeferredRevenueReport, settings, ["On #{settings[:start_date]}"]
    else
      error_redirect "You do not have permission to view this report."
    end
  end

  def show_drawback_audit_report
    if OpenChain::Report::DrawbackAuditReport.permission?(current_user)
      @claims = DrawbackClaim.where(importer_id: current_user.company.id)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_drawback_audit_report
    if OpenChain::Report::DrawbackAuditReport.permission?(current_user)
      settings = {drawback_claim_id: params[:drawback_claim_id]}
      run_report "Drawback Audit Report", OpenChain::Report::DrawbackAuditReport, settings, []
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_rl_tariff_totals
    if OpenChain::Report::RlTariffTotals.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_rl_tariff_totals
    if OpenChain::Report::RlTariffTotals.permission?(current_user)
      settings = {time_zone: current_user.time_zone, start_date: params[:start_date], end_date: params[:end_date]}
      run_report "Ralph Lauren Monthly Tariff Totals", OpenChain::Report::RlTariffTotals, settings, []
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_pvh_billing_summary
    if OpenChain::Report::PvhBillingSummary.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_pvh_billing_summary
    if OpenChain::Report::PvhBillingSummary.permission?(current_user)
      settings = {invoice_numbers: params[:invoice_numbers].to_s.split(' ')}
      if settings[:invoice_numbers].empty?
        add_flash :errors, "Please enter at least one invoice number."
        redirect_to request.referrer
      else
        run_report "PVH Billing Summary", OpenChain::Report::PvhBillingSummary, settings, []
      end
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_pvh_container_log
    if OpenChain::Report::PvhContainerLogReport.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_pvh_container_log
    if OpenChain::Report::PvhContainerLogReport.permission?(current_user)
      settings = {:start_date => params[:start_date].to_date, :end_date => params[:end_date].to_date}
      run_report "PVH Container Log", OpenChain::Report::PvhContainerLogReport, settings, ["On or after #{settings[:start_date]} and prior to #{settings[:end_date]}."]
    else
      error_redirect "You do not have permission to view this report."
    end
  end

  def show_sg_duty_due_report
    if OpenChain::Report::SgDutyDueReport.permission?(current_user)
      @choices = ['sgi', 'sgold', 'rugged'].map{ |cust_num| Company.where(alliance_customer_number: cust_num).first }
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_sg_duty_due_report
    if OpenChain::Report::SgDutyDueReport.permission?(current_user)
      run_report "SG Duty Due Report", OpenChain::Report::SgDutyDueReport, {customer_number: params[:customer_number]}, []
    else
      error_redirect "You do not have permission to view this report."
      return
    end
  end

  def show_monthly_entry_summation
    if OpenChain::Report::MonthlyEntrySummation.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_ticket_tracking_report
    klass = OpenChain::Report::TicketTrackingReport
    if klass.permission? current_user
      @project_keys = klass.get_project_keys current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_ticket_tracking_report
    if OpenChain::Report::TicketTrackingReport.permission? current_user
      run_report "Ticket Tracking Report", OpenChain::Report::TicketTrackingReport, {start_date: params[:start_date], end_date: params[:end_date], project_keys: params[:project_keys]}, []
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_ascena_actual_vs_potential_first_sale_report
    if OpenChain::Report::AscenaActualVsPotentialFirstSaleReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_ascena_actual_vs_potential_first_sale_report
    klass = OpenChain::Report::AscenaActualVsPotentialFirstSaleReport
    if klass.permission? current_user
      run_report "Ascena Actual vs Potential First Sale Report", klass, {}, []
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_ascena_entry_audit_report
    if OpenChain::Report::AscenaEntryAuditReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_ascena_entry_audit_report
    klass = OpenChain::Report::AscenaEntryAuditReport
    if klass.permission? current_user
      run_report "Ascena Entry Audit Report", klass, {range_field: params[:range_field], start_release_date: params[:start_release_date],
                                                      end_release_date: params[:end_release_date], start_fiscal_year_month: params[:start_fiscal_year_month],
                                                      end_fiscal_year_month: params[:end_fiscal_year_month]}, []
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_ascena_vendor_scorecard_report
    if OpenChain::CustomHandler::Ascena::AscenaVendorScorecardReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_ascena_vendor_scorecard_report
    klass = OpenChain::CustomHandler::Ascena::AscenaVendorScorecardReport
    if klass.permission? current_user
      run_report "Ascena Vendor Scorecard Report", klass, {range_field: params[:range_field], start_release_date: params[:start_release_date],
                                                      end_release_date: params[:end_release_date], start_fiscal_year_month: params[:start_fiscal_year_month],
                                                      end_fiscal_year_month: params[:end_fiscal_year_month]}, []
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_ppq_by_po_report
    if OpenChain::Report::PpqByPoReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end
  def run_ppq_by_po_report
    klass = OpenChain::Report::PpqByPoReport
    if klass.permission? current_user
      run_report "PPQ By PO Report", klass, {customer_numbers: params[:customer_numbers], po_numbers: params[:po_numbers]}, []
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_monthly_entry_summation
    if OpenChain::Report::MonthlyEntrySummation.permission? current_user
      run_report "Monthly Entry Summation", OpenChain::Report::MonthlyEntrySummation, params.slice(:start_date, :end_date, :customer_number), []
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_container_cost_breakdown
    if OpenChain::Report::EntryContainerCostBreakdown.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end
  def run_container_cost_breakdown
    run_report "Container Cost Breakdown", OpenChain::Report::EntryContainerCostBreakdown, params.slice(:start_date, :end_date, :customer_number), []
  end

  def show_eddie_bauer_ca_k84_summary
    if OpenChain::Report::EddieBauerCaK84Summary.permission?(current_user)
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_eddie_bauer_ca_k84_summary
    if OpenChain::Report::EddieBauerCaK84Summary.permission?(current_user)
      if params[:date].blank?
        add_flash :errors, "Please enter a K84 due date."
        redirect_to request.referrer
        return
      end
      settings = {date: params[:date].to_date}
      run_report "Eddie Bauer CA K84 Summary", OpenChain::Report::EddieBauerCaK84Summary, settings, []
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_ll_prod_risk_report
    if OpenChain::Report::LlProdRiskReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_ll_prod_risk_report
    if OpenChain::Report::LlProdRiskReport.permission? current_user
      run_report "Lumber Liquidators Product Risk Report", OpenChain::Report::LlProdRiskReport, {}, []
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_ll_dhl_order_push_report
    if OpenChain::CustomHandler::LumberLiquidators::LumberDhlOrderPushReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_ll_dhl_order_push_report
    if OpenChain::CustomHandler::LumberLiquidators::LumberDhlOrderPushReport.permission? current_user
      run_report "Lumber Liquidators DHL PO Push Report", OpenChain::CustomHandler::LumberLiquidators::LumberDhlOrderPushReport, {}, []
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_j_crew_drawback_imports_report
    if OpenChain::CustomHandler::JCrew::JCrewDrawbackImportsReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_j_crew_drawback_imports_report
    if OpenChain::CustomHandler::JCrew::JCrewDrawbackImportsReport.permission? current_user
      # Validate the start / end dates are not more than a year apart.
      start_date = params[:start_date].to_s.to_date
      end_date = params[:end_date].to_s.to_date
      if start_date.nil? || end_date.nil? || (start_date + 1.year < end_date)
        add_flash :errors, "You must enter a start and end date that are no more than 1 year apart."
        redirect_to reports_show_j_crew_drawback_imports_report_path
      else
        run_report "J Crew Drawback Imports Report", OpenChain::CustomHandler::JCrew::JCrewDrawbackImportsReport, {start_date: start_date.to_s, end_date: end_date.to_s}, ["Arrival Date on or after #{start_date} and before #{end_date}"]
      end

    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_ua_duty_planning_report
    if OpenChain::Report::UaDutyPlanningReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report."
    end
  end
  def run_ua_duty_planning_report
    error_redirect "You do not have permission to view this report." unless OpenChain::Report::UaDutyPlanningReport.permission?(current_user)
    query_params = {}
    styles = params[:styles]
    if !styles.blank?
      path = "ua_duty_planning_report/#{Time.now.to_i}-#{current_user.id}.txt"
      OpenChain::S3.upload_data OpenChain::S3.bucket_name, path, styles
      query_params[:style_s3_path] = path
    elsif !params[:season].blank?
      query_params[:season] = params[:season]
    else
      error_redirect "You must include either styles or a season."
      return
    end
    run_report "UA Duty Planning", OpenChain::Report::UaDutyPlanningReport, query_params, []
  end

  def show_lumber_actualized_charges_report
    if OpenChain::CustomHandler::LumberLiquidators::LumberActualizedChargesReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_lumber_actualized_charges_report
    if OpenChain::CustomHandler::LumberLiquidators::LumberActualizedChargesReport.permission? current_user
      # Validate the start / end dates are not more than a year apart.
      start_date = params[:start_date].to_s.to_date
      end_date = params[:end_date].to_s.to_date
      if start_date.nil? || end_date.nil?
        add_flash :errors, "You must enter a start and end date."
        redirect_to show_lumber_actualized_charges_report_path
      else
        run_report "Lumber Actualized Charges Report", OpenChain::CustomHandler::LumberLiquidators::LumberActualizedChargesReport, {start_date: start_date.to_s, end_date: end_date.to_s}, ["Release Date on or after #{start_date} and before #{end_date}"]
      end

    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_entries_with_holds_report
    if OpenChain::Report::EntriesWithHoldsReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_entries_with_holds_report
    # Validate the start / end dates are not more than a year apart.
    start_date = params[:start_date].to_s.to_date
    end_date = params[:end_date].to_s.to_date
    customer_numbers = params[:customer_numbers].split(/[\s\n\r]+/)

    if start_date.nil? || end_date.nil?
      error_redirect "You must enter a start and end date."
    elsif customer_numbers.blank?
      error_redirect "You must enter at least one customer number."
    else
      run_report "Entries with Holds Report", OpenChain::Report::EntriesWithHoldsReport, {start_date: start_date.to_s, end_date: end_date.to_s, customer_numbers: params[:customer_numbers]}, ["Arrival Date on or after #{start_date} and before #{end_date} for customers #{customer_numbers}"]
    end
  end

  def show_rl_jira_report
    if OpenChain::CustomHandler::Polo::PoloJiraEntryReport.permission? current_user
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_rl_jira_report
    if OpenChain::CustomHandler::Polo::PoloJiraEntryReport.permission? current_user
      # Validate the start / end dates are not more than a year apart.
      start_date = params[:start_date].to_s.to_date
      end_date = params[:end_date].to_s.to_date
      if start_date.nil? || end_date.nil? || (start_date + 1.year < end_date)
        add_flash :errors, "You must enter a start and end date that are no more than 1 year apart."
        redirect_to reports_show_rl_jira_report_path
      else
        run_report "RL Jira Report", OpenChain::CustomHandler::Polo::PoloJiraEntryReport, {start_date: start_date.to_s, end_date: end_date.to_s}, ["Created on or after #{start_date} and before #{end_date}"]
      end

    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def show_ascena_duty_savings_report
    if OpenChain::CustomHandler::Ascena::AscenaDutySavingsReport.permission? current_user
      # create a dropdown of all the fiscal months available
      @fiscal_months = []
      FiscalMonth.where(company_id: OpenChain::CustomHandler::Ascena::AscenaDutySavingsReport.ascena.id).order("start_date ASC").each do |fm|
        @fiscal_months << fm.fiscal_descriptor
      end
      render
    else
      error_redirect "You do not have permission to view this report"
    end
  end

  def run_ascena_duty_savings_report
    klass = OpenChain::CustomHandler::Ascena::AscenaDutySavingsReport
    if klass.permission? current_user
      fm = klass.fiscal_month params
      if fm.nil?
        add_flash :errors, "You must select a valid fiscal month."
        redirect_to reports_show_ascena_duty_savings_report_path
      else
        run_report "Duty Savings Report", klass, {'fiscal_month' => params[:fiscal_month]}, ["Fiscal Month #{params[:fiscal_month]}"]
      end
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
