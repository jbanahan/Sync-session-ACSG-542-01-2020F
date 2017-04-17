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

  def sync_records
    @base_object = BrokerInvoice.find(params[:id])
    # We use the same method for the entry/:entry_id/broker_invoice/:id/sync_records route as the /broker_invoice/:id/sync_records one
    # when coming from the entry screen...we want to go back to the entry screen, not the broker invoices
    if params[:entry_id]
      @back_url = url_for(Entry.find(params[:entry_id]))
    else
      @back_url = url_for(@base_object)
    end
    
    render template: "shared/sync_records"
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
