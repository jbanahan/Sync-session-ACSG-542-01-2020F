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
      @vfi_invoice = VfiInvoice.find params[:id]
      @invoice_total = ModelField.find_by_uid(:vi_invoice_total).process_export(@vfi_invoice, current_user)
    else
      error_redirect "You do not have permission to view VFI invoices."
    end
  end
end