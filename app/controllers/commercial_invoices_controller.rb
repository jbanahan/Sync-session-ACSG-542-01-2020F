class CommercialInvoicesController < ApplicationController
  def show
    ci = CommercialInvoice.find params[:id]
    action_secure(ci.can_view?(current_user),ci,{:lock_check=>false,:verb => "view",:module_name=>"commercial invoice"}) {
      @ci = ci
      first_line = @ci.commercial_invoice_lines.first
      if !first_line.blank? && !first_line.shipment_lines.blank?
        @shipment = first_line.shipment_lines.first.shipment
      end
      render :layout=>'one_col'
    }
  end
end
