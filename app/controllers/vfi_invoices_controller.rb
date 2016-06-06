class VfiInvoicesController < ApplicationController
  def index
    if current_user.view_vfi_invoices?
      flash.keep
      redirect_to advanced_search CoreModule::VFI_INVOICE, params[:force_search]
    else
      error_redirect "You do not have permission to view VFI invoices."
    end
  end

  def show
    if current_user.view_vfi_invoices?
      inv = VfiInvoice.find params[:id]
      action_secure(inv.can_view?(current_user), inv, {:lock_check=>false,:verb=>"view",:module_name=>"invoice"}) {
        @vfi_invoice = inv
      }
    else
      error_redirect "You do not have permission to view VFI invoices."
    end
  end
end