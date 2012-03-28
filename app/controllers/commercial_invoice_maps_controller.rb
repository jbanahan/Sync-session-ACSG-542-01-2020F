class CommercialInvoiceMapsController < ApplicationController
  def index
    action_secure(current_user.admin?,nil,{:lock_check=>false,:verb => "view",:module_name=>"invoice mappings"}) {
      @maps = CommercialInvoiceMap.all
    }
  end
  def update_all
    action_secure(current_user.admin?,nil,{:lock_check=>false,:verb => "edit",:module_name=>"invoice mappings"}) {
      CommercialInvoiceMap.transaction {
        r_count = 0
        CommercialInvoiceMap.destroy_all
        params[:map].values.each do |mp|
          next if mp[:src].blank? || mp[:dest].blank?
          CommercialInvoiceMap.create!(:source_mfid=>mp[:src],:destination_mfid=>mp[:dest])
          r_count += 1
        end
        add_flash :notices, "#{r_count} mapping records saved."
        redirect_to commercial_invoice_maps_path
      }
    }
  end
end
