class BrokerInvoicesController < ApplicationController
  def root_class
    BrokerInvoice
  end
  def index
    advanced_search CoreModule::BROKER_INVOICE
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
      bi = ent.broker_invoices.create(params[:broker_invoice])
      if bi.broker_invoice_lines.empty?
        bi.destroy
        add_flash :errors, "Cannot create invoice without lines."
      elsif !bi.errors.empty?
        errors_to_flash bi
      else
        bi.update_attributes(:invoice_total=>bi.broker_invoice_lines.sum('charge_amount'))
      end
      redirect_to ent
    end
  end
end
