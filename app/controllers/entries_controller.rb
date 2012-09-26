class EntriesController < ApplicationController
  def root_class
    Entry 
  end

  def index
    advanced_search CoreModule::ENTRY
  end
  def show
    e = Entry.where(:id=>params[:id]).includes(:commercial_invoices,:entry_comments,:import_country).first
    action_secure(e.can_view?(current_user),e,{:lock_check=>false,:verb=>"view",:module_name=>"entry"}) {
      @entry = e
      if e.import_country && e.import_country.iso_code == 'CA'
        render :action=>'show_ca', :layout=>'one_col'
      else
        render :action=>'show_us', :layout=>'one_col'
      end
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
end
