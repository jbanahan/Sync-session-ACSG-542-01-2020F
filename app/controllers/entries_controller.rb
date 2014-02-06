require 'open_chain/alliance_imaging_client'
require 'open_chain/activity_summary'
class EntriesController < ApplicationController
  helper ValidationResultsHelper
  def root_class
    Entry 
  end

  def index
    flash.keep
    redirect_to advanced_search CoreModule::ENTRY, params[:force_search]
  end
  def ca_activity_summary
    params[:importer_id] ||= current_user.company.master? ? Company.where('length(fenix_customer_number)>0').order(:fenix_customer_number).first.id : current_user.company_id
    @iso = 'ca'
    render :activity_summary
  end
  def ca_activity_summary_content
    activity_summary_content
  end
  def us_activity_summary
    params[:importer_id] ||= current_user.company.master? ? Company.where('length(alliance_customer_number)>0').order(:alliance_customer_number).first.id : current_user.company_id
    @iso = 'us'
    render :activity_summary
  end
  def us_activity_summary_content
    activity_summary_content
  end
  def by_entry_port
    @imp = Company.find params[:importer_id]
    action_secure(current_user.view_entries? && Entry.can_view_importer?(@imp,current_user),nil,{lock_check:false,verb:'view',module_name:'entry'}) {
      # We've already established the user can view the importer so we don't have to further secure the Entry query at the user level
      @entries = Entry.where(entry_port_code:params[:port_code]).where(Entry.search_where_by_company_id(@imp.id))
    }
  end
  def by_release_range
    @imp = Company.find params[:importer_id]
    action_secure(current_user.view_entries? && Entry.can_view_importer?(@imp,current_user),nil,{lock_check:false,verb:'view',module_name:'entry'}) {
      @range_descriptions = [
        ["Released In The Last 7 Days",'1w'],
        ["Released In The Last 28 Days",'4w'],
        ["Filed / Not Released",'op'],
        ["Released Year To Date",'ytd']
      ]

      begin
        @entries = OpenChain::ActivitySummary.create_by_release_range_query(@imp.id, params[:iso_code], params[:release_range])
      rescue ArgumentError => e
        error_redirect e.message
      end
    }
  end
  def show
    e = Entry.where(:id=>params[:id]).includes(:commercial_invoices,:entry_comments,:import_country).first
    unless e
      error_redirect "Entry with id #{params[:id]} not found."
      return
    end

    action_secure(e.can_view?(current_user),e,{:lock_check=>false,:verb=>"view",:module_name=>"entry"}) {
      current_user.update_attributes(:simple_entry_mode=>false) if params[:mode]=='detail' && current_user.simple_entry_mode?
      current_user.update_attributes(:simple_entry_mode=>true) if params[:mode]=='simple' && !current_user.simple_entry_mode?
      if current_user.simple_entry_mode.nil?
        add_flash :notices, "Try simple mode by clicking on the button at the bottom of this screen." 
        current_user.update_attributes(:simple_entry_mode=>false)
      end
      @entry = e
      if e.import_country && e.import_country.iso_code == 'CA'
        render :action=>'show_ca', :layout=>'one_col'
      else
        render :action=>(current_user.simple_entry_mode? ? 'show_us_simple' : 'show_us'), :layout=>'one_col'
      end
    }
  end

  def validation_results
    e = Entry.find params[:id]
    action_secure(e.can_view?(current_user),e,{:lock_check=>false,:verb=>"view",:module_name=>"entry"}) {
      @entry = e
    }
  end

  #request that the images be reloaded from alliance for the given entry
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

  #request that the images be reloaded form alliance for a set of entries
  def bulk_get_images
    action_secure(current_user.company.master? && current_user.view_entries?,Entry.new,{:verb=>'manage',:module_name=>"entries"}) {
      sr_id = params[:sr_id]
      primary_keys = params[:pk]
      OpenChain::AllianceImagingClient.delay.bulk_request_images sr_id, primary_keys
      add_flash :notices, "Updated images have been requested.  Please allow 10 minutes for them to appear."

      # Redirect back to main page if referrer is blank (this can be removed once we set referrer to never be nil)
      redirect_to request.referrer.nil? ? "/" : request.referrer
    }
  end

  # business intelligence view
  def bi_three_month
    if current_user.view_entries? 
      @filter_companies = companies_for_bi_filter
      @selected_search = "/entries/bi/three_month?country=#{params[:country]=="CA" ? "CA" : "US"}"
      date_field = params[:country]=="CA" ? "direct_shipment_date" : "arrival_date"
      country_iso = params[:country]=="CA" ? "CA" : "US"
      where_clause = "WHERE entries.#{date_field} >= CAST(DATE_FORMAT(DATE_ADD(NOW(),INTERVAL -3 MONTH),\"%Y-%m-01\") as DATE) AND entries.#{date_field} < CAST(DATE_FORMAT(NOW(),\"%Y-%m-01\") as DATE)"
      where_clause << " and entries.import_country_id = (select id from countries where iso_code = \"#{country_iso}\") and (#{Entry.search_where(current_user)})" 
      where_clause << "and #{build_bi_company_filter_clause params[:cids]}"
      qry = "SELECT entries.entry_port_code, DATE_FORMAT(entries.#{date_field},\"%Y-%m\") as \"Month\", count(*) as \"Entries\", sum(entries.entered_value) as \"Entered Value\", sum(entries.total_duty) as \"Total Duty\" FROM entries "+where_clause+" group by DATE_FORMAT(entries.#{date_field},\"%Y-%m\"), entries.entry_port_code;"
      @total_entries = Entry.connection.execute qry
      render :layout=>'one_col' 
    else
      error_redirect "You do not have permission to view entries."
    end
  end
  def bi_three_month_hts
    if current_user.view_entries? 
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
      render :layout=>'one_col' 
    else
      error_redirect "You do not have permission to view entries."
    end
  end

  def reprocess
    sys_admin_secure {
      imaging = params[:imaging]=='true'
      days = params[:days].to_i
      case params[:parser]
      when 'alliance'
        OpenChain::AllianceParser.delay.process_past_days days, {:imaging=>imaging, :user_id=>current_user.id}
        add_flash :notices, "Prcessing the past #{days} days for Alliance. (Imaging = #{imaging})"
      when 'fenix'
        OpenChain::FenixParser.delay.process_past_days days, {:user_id=>current_user.id}
        add_flash :notices, "Prcessing the past #{days} days for Fenix."
      end
      redirect_to root_path
    }
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
    unless Entry.can_view_importer?(@imp,current_user)
      render partial: 'shared/error_panel', locals:{message:"You do not have permission to view this page."}
      return 
    end
    @last_entry = Entry.where(Entry.search_where_by_company_id(@imp.id)).order('updated_at DESC').first
    unless @last_entry
      render partial: 'shared/error_panel', locals:{message:'This importer does not have any entries.'}
      return 
    end
    render layout: false
  end

end
