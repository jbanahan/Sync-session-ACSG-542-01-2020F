class SummaryStatementsController < ApplicationController
  include SummaryStatementsHelper

  def set_page_title
    @page_title = "Statement"
  end

  def index
    if current_user.view_summary_statements?
      flash.keep
      redirect_to advanced_search CoreModule::SUMMARY_STATEMENT, params[:force_search]
    else
      error_redirect "You do not have permission to view summary statements."
    end
  end

  def show
    if current_user.view_summary_statements?
      @summary_statement = SummaryStatement.where(id: params[:id]).includes(:broker_invoices).first
      @us_invoices, @ca_invoices = separate_invoices(@summary_statement)
      respond_to do |format|
        format.html {}
        format.xls { send_excel_workbook render_summary_xls(@summary_statement), "#{@summary_statement.statement_number}.xls" }
      end
    else
      error_redirect "You do not have permission to view summary statements."
    end
  end

  def new
    unless current_user.edit_summary_statements?
      error_redirect "You do not have permission to create summary statements."
    end
    @companies = Company.connection.exec_query("SELECT c.id, c.name, COUNT(e.id) FROM companies c INNER JOIN entries e ON e.importer_id = c.id GROUP BY c.id ORDER BY c.name")
  end

  def create
    unless current_user.edit_summary_statements?
      error_redirect "You do not have permission to create summary statements." 
      return
    end
    
    co = Company.find(params[:company])
    unless co.importer?
      error_redirect "This company cannot be assigned summary statements."
      return
    end
    ss = SummaryStatement.new(customer: co, statement_number: params[:stat_num])
    if ss.save
      redirect_to edit_summary_statement_path(ss)
      return
    else 
      errors_to_flash ss
      redirect_to request.referrer
    end
  end

  def edit
    if current_user.edit_summary_statements?
      @summary_statement = SummaryStatement.where(id: params[:id]).includes(:broker_invoices).first
      @us_invoices, @ca_invoices = separate_invoices(@summary_statement)
    else
      error_redirect "You do not have permission to edit summary statements."
    end
  end

  def update
    unless current_user.edit_summary_statements? && params[:selected]
      redirect_to request.referrer 
      return
    end
    ss = SummaryStatement.find(params[:id])
    to_remove = params[:selected][:to_remove]
    to_remove = to_remove.reject(&:blank?) if to_remove
    to_add = params[:selected][:to_add]
    to_add = check_invoices(to_add.split(' ')) if to_add
    begin
      BrokerInvoice.transaction do
        to_remove.each{ |id| ss.remove! id.to_i } if to_remove
        if to_add  
          to_add[:invoice_ids].each{ |id| ss.add! id.to_i } if to_add[:invoice_ids]
          raise "Invoice #{to_add[:bad_invoice_num]} does not exist." if to_add[:bad_invoice_num]
        end
      end
    rescue => e
      add_flash :errors, e.to_s
      redirect_to request.referrer
      return
    end
    redirect_to edit_summary_statement_path(ss)
  end

  private

  def check_invoices invoice_number_arr
    valid = []
    invoice_number_arr.each do |num| 
      bi = BrokerInvoice.where("invoice_number = ?", num).first
      if bi
        valid << bi.id 
      else
        return {bad_invoice_num: num}
      end
    end
    {invoice_ids: valid}
  end

  def separate_invoices summary_statement
    us_invoices, ca_invoices = [], []
    summary_statement.broker_invoices.each{ |bi| (bi.entry.canadian? ? ca_invoices : us_invoices) << bi }
    [us_invoices, ca_invoices]
  end

end