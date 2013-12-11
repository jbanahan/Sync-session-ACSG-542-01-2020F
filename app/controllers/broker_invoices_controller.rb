class BrokerInvoicesController < ApplicationController
  def root_class
    BrokerInvoice
  end
  def index
    flash.keep
    redirect_to advanced_search CoreModule::BROKER_INVOICE, params[:force_search]
  end
  def show
    i = BrokerInvoice.find params[:id]
    action_secure(i.can_view?(current_user),i,{:lock_check=>false,:verb=>"view",:module_name=>"invoice"}) {
      @invoice = i
    }
  end
  def create
    ent = Entry.find params[:entry_id]
    if !ent.can_view? current_user
      error_redirect "You do not have permission to view this entry."
    elsif !current_user.edit_broker_invoices?
      error_redirect "You do not have permission to edit invoices."
    else
      bi = ent.broker_invoices.build(params[:broker_invoice])
      bi.invoice_number = "#{ent.broker_reference}#{bi.suffix}" if bi.invoice_number.blank?
      bi.source_system = "Screen (#{current_user.full_name})"
      if bi.broker_invoice_lines.empty?
        add_flash :errors, "Cannot create invoice without lines."
      else
        begin
          bi.complete!
          add_flash :notices, "Invoice created successfully."
        rescue
          errors_to_flash bi
        end
      end
      redirect_to ent
    end
  end
end
