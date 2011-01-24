class ModelFieldsController < ApplicationController
  def find_by_module_type
    if ["Product","SalesOrder","SalesOrderLine","Delivery","Shipment","Order","OrderLine"].include? params[:module_type]
      model_fields = ModelField.sort_by_label(ModelField.find_by_module_type(params[:module_type].to_sym))
      respond_to do |format|
        format.json { render :json => model_fields.to_json }
      end
    else
      error_redirect "Module #{params[:module_type]} not supported by find_by_module_type"
    end
  end
end