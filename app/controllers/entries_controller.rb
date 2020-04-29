require 'open_chain/alliance_imaging_client'
require 'open_chain/activity_summary'
require 'open_chain/kewill_sql_proxy_client'
require 'open_chain/business_rule_validation_results_support'
require 'open_chain/custom_handler/delivery_order_spreadsheet_generator'

class EntriesController < ApplicationController
  include EntriesHelper
  include ValidationResultsHelper
  include OpenChain::BusinessRuleValidationResultsSupport
  include BulkSendToTestSupport

  def set_page_title
    @page_title = "Entry"
  end

  def root_class
    Entry
  end

  def index
    flash.keep
    redirect_to advanced_search CoreModule::ENTRY, params[:force_search]
  end
  def ca_activity_summary
    distribute_reads do
      importers = Company.for_system("Fenix").order("system_identifiers.code")
      activity_summary_select importers, 'ca'
    end
  end
  def ca_activity_summary_content
    distribute_reads do
      activity_summary_content
    end
  end
  def us_activity_summary
    distribute_reads do
      importers = Company.for_system(["Customs Management", "Cargowise"]).order("system_identifiers.code")
      activity_summary_select importers, 'us'
    end
  end
  def us_activity_summary_content
    distribute_reads do
      activity_summary_content
    end
  end
  def by_entry_port
    @imp = Company.find params[:importer_id]
    action_secure(current_user.view_entries? && Entry.can_view_importer?(@imp, current_user), nil, {lock_check:false, verb:'view', module_name:'entry'}) {
      # We've already established the user can view the importer so we don't have to further secure the Entry query at the user level
      @entries = Entry.where(entry_port_code:params[:port_code]).where(Entry.search_where_by_company_id(@imp.id))
      @date_uid = OpenChain::ActivitySummary.generator_for_country(params[:iso_code]).release_date_mf.uid
    }
  end
  def by_release_range
    @imp = Company.find params[:importer_id]
    action_secure(current_user.view_entries? && Entry.can_view_importer?(@imp, current_user), nil, {lock_check:false, verb:'view', module_name:'entry'}) {
      @range_descriptions = OpenChain::ActivitySummary::DETAILS.map { |k, v| [v, k] }

      begin
        generator = OpenChain::ActivitySummary.generator_for_country(params[:iso_code])
        @entries = generator.create_by_release_range_query(@imp.id, params[:release_range])
        @date_uid = (params[:release_range] == "holds") ? :ent_hold_date : generator.release_date_mf.uid
      rescue ArgumentError => e
        error_redirect e.message
      end
    }
  end
  def by_release_range_download
    imp = Company.find params[:importer_id]
    action_secure(current_user.view_entries? && Entry.can_view_importer?(imp, current_user), nil, {lock_check:false, verb:'download', module_name:'file'}) {
      xls = nil
      distribute_reads do
        generator = OpenChain::ActivitySummary.generator_for_country(params[:iso_code])
        xls = generator.create_by_release_range_download params[:importer_id], params[:release_range]
      end

      send_file xls.path, filename: xls.original_filename, type: :xls, disposition: "attachment"
    }
  end
  def show
    e = Entry.where(:id=>params[:id]).includes(:commercial_invoices => [:commercial_invoice_lines=>[:commercial_invoice_tariffs]], :entry_comments=>[:entry], :import_country=>[]).first
    unless e
      error_redirect "Entry with id #{params[:id]} not found."
      return
    end

    action_secure(e.can_view?(current_user), e, {:lock_check=>false, :verb=>"view", :module_name=>"entry"}) {
      current_user.update_attributes(:simple_entry_mode=>false) if params[:mode]=='detail' && current_user.simple_entry_mode?
      current_user.update_attributes(:simple_entry_mode=>true) if params[:mode]=='simple' && !current_user.simple_entry_mode?
      if current_user.simple_entry_mode.nil?
        add_flash :notices, "Try simple mode by clicking on the button at the bottom of this screen."
        current_user.update_attributes(:simple_entry_mode=>false)
      end
      respond_to do |format|
        format.html {
          @entry = e
          if e.canadian?
            render :action=>'show_ca', :layout=>'one_col'
          else
            render :action=>(current_user.simple_entry_mode? ? 'show_us_simple' : 'show_us'), :layout=>'one_col'
          end
        }
        format.xls {
          send_excel_workbook render_xls(e, current_user), "#{e.broker_reference}.xls"
        }
        format.xlsx {
          send_excel_workbook render_xlsx(e, current_user), "#{e.broker_reference}.xlsx"
        }
      end
    }
  end

  def validation_results
    generic_validation_results(Entry.find params[:id])
  end

  # request that the images be reloaded from alliance for the given entry
  def get_images
    ent = Entry.find_by_id params[:id]
    if ent.nil?
      error_redirect "Entry with id #{params[:id]} not found."
    elsif ent.source_system != 'Alliance'
      error_redirect "Images cannot be requested for entries that are not from Alliance."
    else
      OpenChain::AllianceImagingClient.request_images ent.broker_reference
      add_flash :notices, "Updated images for file #{ent.broker_reference} have been requested.  Please allow 10 minutes for them to appear."
      redirect_to ent
    end
  end

  # request that the images be reloaded form alliance for a set of entries
  def bulk_get_images
    action_secure(current_user.company.master? && current_user.view_entries?, Entry.new, {:verb=>'manage', :module_name=>"entries"}) {
      OpenChain::AllianceImagingClient.delayed_bulk_request_images params[:sr_id], params[:pk]
      add_flash :notices, "Updated images have been requested.  Please allow 10 minutes for them to appear."

      # Redirect back to main page if referrer is blank (this can be removed once we set referrer to never be nil)
      redirect_to request.referrer.nil? ? "/" : request.referrer
    }
  end

  # business intelligence view
  def bi_three_month
    if current_user.view_entries?
      distribute_reads do
        @filter_companies = companies_for_bi_filter
        @selected_search = "/entries/bi/three_month?country=#{params[:country]=="CA" ? "CA" : "US"}"
        date_field = params[:country]=="CA" ? "direct_shipment_date" : "arrival_date"
        country_iso = params[:country]=="CA" ? "CA" : "US"
        where_clause = "WHERE entries.#{date_field} >= CAST(DATE_FORMAT(DATE_ADD(NOW(),INTERVAL -3 MONTH),\"%Y-%m-01\") as DATE) AND entries.#{date_field} < CAST(DATE_FORMAT(NOW(),\"%Y-%m-01\") as DATE)"
        where_clause << " and entries.import_country_id = (select id from countries where iso_code = \"#{country_iso}\") and (#{Entry.search_where(current_user)})"
        where_clause << "and #{build_bi_company_filter_clause params[:cids]}"
        qry = "SELECT entries.entry_port_code, DATE_FORMAT(entries.#{date_field},\"%Y-%m\") as \"Month\", count(*) as \"Entries\", sum(entries.entered_value) as \"Entered Value\", sum(entries.total_duty) as \"Total Duty\" FROM entries "+where_clause+" group by DATE_FORMAT(entries.#{date_field},\"%Y-%m\"), entries.entry_port_code;"
        @total_entries = Entry.connection.execute qry
      end
      render :layout=>'one_col'
    else
      error_redirect "You do not have permission to view entries."
    end
  end
  def bi_three_month_hts
    if current_user.view_entries?
      distribute_reads do
        @filter_companies = companies_for_bi_filter
        @selected_search = "/entries/bi/three_month_hts?country=#{params[:country]=="CA" ? "CA" : "US"}"
        date_field = params[:country]=="CA" ? "direct_shipment_date" : "arrival_date"
        country_iso = params[:country]=="CA" ? "CA" : "US"
        qry = "select commercial_invoice_tariffs.hts_code, DATE_FORMAT(entries.#{date_field},\"%Y-%m\") as \"Month\", count(*) as \"Lines\", sum(commercial_invoice_tariffs.entered_value), sum(commercial_invoice_tariffs.duty_amount) from entries inner join commercial_invoices on entries.id = commercial_invoices.entry_id inner join commercial_invoice_lines on commercial_invoice_lines.commercial_invoice_id = commercial_invoices.id inner join commercial_invoice_tariffs on commercial_invoice_tariffs.commercial_invoice_line_id = commercial_invoice_lines.id "
        qry << "WHERE entries.#{date_field} >= CAST(DATE_FORMAT(DATE_ADD(NOW(),INTERVAL -3 MONTH),\"%Y-%m-01\") as DATE) AND entries.#{date_field} < CAST(DATE_FORMAT(NOW(),\"%Y-%m-01\") as DATE)"
        qry << " and entries.import_country_id = (select id from countries where iso_code = \"#{country_iso}\") and (#{Entry.search_where(current_user)})"
        qry << "and #{build_bi_company_filter_clause params[:cids]}"
        qry << " GROUP BY DATE_FORMAT(entries.#{date_field},\"%Y-%m\"), commercial_invoice_tariffs.hts_code"
        @total_entries = Entry.connection.execute qry
      end
      render :layout=>'one_col'
    else
      error_redirect "You do not have permission to view entries."
    end
  end

  def sync_records
    @base_object = Entry.find(params[:id])
    @back_url = url_for(@base_object)
    render template: "shared/sync_records"
  end

  def request_entry_data
    @entry = Entry.find params[:id]
    if current_user.company.master? && @entry.can_view?(current_user)
      OpenChain::KewillSqlProxyClient.delayed_bulk_entry_data nil, [@entry.id]
      add_flash :notices, "Updated entry has been requested.  Please allow 10 minutes for it to appear."
    end
    redirect_to @entry
  end

  def bulk_request_entry_data
    if current_user.sys_admin?
      OpenChain::KewillSqlProxyClient.delayed_bulk_entry_data params[:sr_id], params[:pk]
      add_flash :notices, "Updated entries have been requested.  Please allow 10 minutes for them to appear."
    end

    # Redirect back to main page if referrer is blank (this can be removed once we set referrer to never be nil)
    redirect_to request.referrer || "/"
  end

  def purge
    group_secure("Entry Purge") do
      Entry.find(params[:id]).purge!
      add_flash :notices, "Entry purged"
      redirect_to entries_path
    end
  end

  def us_duty_detail
    @imp = Company.find params[:importer_id]
    unless Entry.can_view_importer?(@imp, current_user) && @imp.can_view?(current_user)
      error_redirect "You do not have permission to view this report."
      return
    end

    generator = OpenChain::ActivitySummary.generator_for_country "US"
    @reports = [generator.create_digest(current_user, @imp)]
    @reports.push(*generator.create_linked_digests(current_user, @imp))
    @reports.compact!
  end

  def generate_delivery_order
    entry = Entry.find params[:id]
    if current_user.company.master? && entry.can_view?(current_user) && !entry.canadian?
      OpenChain::CustomHandler::DeliveryOrderSpreadsheetGenerator.delay.generate_and_send_delivery_orders current_user.id, entry.id
      add_flash :notices, "The Delivery Order will be generated shortly and emailed to #{current_user.email}."
    else
      add_flash :errors, "You do not have permission to view this report."
    end
    redirect_to entry
  end

  private
  def build_bi_company_filter_clause companies
    r = "(1=1)"
    unless companies.blank?
      cids = companies.split(',')
      cids.delete_if {|x| /^[0-9 ]*$/.match(x).nil?}
      r = "(entries.importer_id IN (#{cids.join(",")}))" unless cids.empty?
    end
    r
  end
  def companies_for_bi_filter
    r = []
    if current_user.company.master?
      r = Company.where(:importer=>true).order("companies.name ASC")
    else
      r << current_user.company if current_user.company.importer?
      current_user.company.linked_companies.order("companies.name ASC").each {|c| r << c if c.importer}
    end
    r
  end

  def activity_summary_content
    @imp = Company.find params[:importer_id]
    unless Entry.can_view_importer?(@imp, current_user)
      render partial: 'shared/error_panel', locals:{message:"You do not have permission to view this page."}
      return
    end
    @last_entry = Entry.where(Entry.search_where_by_company_id(@imp.id)).order('updated_at DESC').first
    render layout: false
  end

  def activity_summary_select importer_list, iso
    @iso = iso
    if params[:importer_id]
      render :activity_summary
    else
      @importers = current_user.company.master? ? importer_list : []
      if @importers.count > 1
        render :act_summary_portal
      else
        importer_id = (@importers.count == 1) ? @importers.first.id : current_user.company.id
        redirect_to "/entries/importer/#{importer_id}/activity_summary/#{@iso}"
      end
    end
  end

end
