class InvoicesController < ApplicationController
  def set_page_title
    @page_title ||= "Customer Invoices"
  end

  def root_class
    Invoice
  end

  def index
    redirect_to advanced_search CoreModule::INVOICE, params[:force_search]
  end

  def show
    @invoice = Invoice.find(params[:id])
  end
end