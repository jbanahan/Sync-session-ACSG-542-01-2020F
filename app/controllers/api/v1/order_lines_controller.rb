module Api; module V1; class OrderLinesController < Api::V1::ApiCoreModuleControllerBase
  def core_module
    CoreModule::ORDER_LINE
  end
  # only here for state toggle button support at this time
end; end; end
