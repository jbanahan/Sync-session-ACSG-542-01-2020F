class OfficialTariffMetaDatumController < ApplicationController

  def update
    otmd = OfficialTariffMetaData.find params[:id]
    action_secure(current_user.edit_classifications?,otmd,{:lock_check=>false,:verb=>"update",:module_name=>"HTS record"}) {
      if otmd.update_attributes params[:official_tariff_meta_data]
        add_flash :notices, "Record saved successfully."
      else
        errors_to_flash otmd
      end
      redirect_to otmd.official_tariff
    }
  end

  def create
    otmd = OfficialTariffMetaData.new(params[:official_tariff_meta_data])
    action_secure(current_user.edit_classifications?,otmd,{:lock_check=>false,:verb=>"update",:module_name=>"HTS record"}) {
      if otmd.save
        add_flash :notices, "Record saved successfully."
        redirect_to otmd.official_tariff
      else
        errors_to_flash otmd
        error_redirect ""
      end
    }
  end

end
