module Api; module V1; class PlantsController < Api::V1::ApiCoreModuleControllerBase
  def core_module
    CoreModule::PLANT
  end

  #currently just here for state button support, delete this comment if you add methods
end; end; end
