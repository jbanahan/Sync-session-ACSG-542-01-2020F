module Api; module V1; class FieldsController < Api::V1::ApiController
  def index
    mt = params[:module_types]
    raise StatusableError("You must specify module_types.",400) if mt.blank?
    r = {}
    mt.split(',').each do |m|
      cm = CoreModule.find_by_class_name m.camelize
      raise StatusableError.new("Module #{m} not found.",400) if cm.nil?
      raise StatusableError.new("You do not have permission to view the #{m} module.",401) unless cm.view? current_user
      r["#{m}_fields"] = cm.model_fields.values.collect { |mf|
        {'uid'=>mf.uid,'label'=>mf.label,'data_type'=>mf.data_type}
      }
    end
    render json: r
  end
end; end; end