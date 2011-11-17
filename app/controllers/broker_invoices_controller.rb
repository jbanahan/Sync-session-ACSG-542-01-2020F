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
end
