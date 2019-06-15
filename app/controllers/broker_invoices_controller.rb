class BrokerInvoicesController < ApplicationController
  include BulkSendToTestSupport

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

end
