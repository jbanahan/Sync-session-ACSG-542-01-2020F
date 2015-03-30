module Api; module V1; class PlantProductGroupAssignmentsController < Api::V1::ApiCoreModuleControllerBase
  def core_module
    CoreModule::PLANT_PRODUCT_GROUP_ASSIGNMENT
  end

  #currently just here for state button support, delete this comment if you add methods
end; end; end
