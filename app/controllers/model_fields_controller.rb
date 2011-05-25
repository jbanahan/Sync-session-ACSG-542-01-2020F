class ModelFieldsController < ApplicationController
  def find_by_module_type
    if ["Product","SalesOrder","SalesOrderLine","Delivery","Shipment","Order","OrderLine","OfficialTariff"].include? params[:module_type]
      model_fields = ModelField.sort_by_label(CoreModule.find_by_class_name(params[:module_type]).model_fields_including_children.values)
      mfs = custom_hash_for_json model_fields
      respond_to do |format|
        format.json { render :json => mfs.to_json }
      end
    else
      error_redirect "Module #{params[:module_type]} not supported by find_by_module_type"
    end
  end
  
  private
  def custom_hash_for_json(mfs)
    r = []
    mfs.each do |m|
      r << {:uid => m.uid, :label => m.label}
    end
    r
  end
end
