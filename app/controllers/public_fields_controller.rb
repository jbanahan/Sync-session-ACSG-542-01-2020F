class PublicFieldsController < ApplicationController

  def save
    admin_secure {
      PublicField.destroy_all #start over every time
      field_hash = params[:public_fields]
      field_hash.each do |k,v|
        pf = PublicField.create(v) if v[:model_field_uid]
      end
      redirect_to '/public_fields'
    }
  end

  def index
    admin_secure {
      @model_fields = CoreModule::SHIPMENT.model_fields.values
    } 
  end

end
