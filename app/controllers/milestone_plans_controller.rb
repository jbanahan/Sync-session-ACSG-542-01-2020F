class MilestonePlansController < ApplicationController

  def index
    respond_to do |format|
      format.json { render :json => MilestonePlan.all}
      format.html {}
    end
  end

  def edit
    admin_secure {
      @available_fields = CoreModule.grouped_options({:core_modules=>[CoreModule::ORDER,CoreModule::ORDER_LINE,CoreModule::SHIPMENT,CoreModule::SHIPMENT_LINE,CoreModule::SALE,CoreModule::SALE_LINE,CoreModule::DELIVERY,CoreModule::DELIVERY_LINE],
          :filter=>lambda {|f| [:date,:datetime].include?(f.data_type)}})
      @mp = MilestonePlan.find params[:id]
    }
  end

  def update
    admin_secure {
      mp = MilestonePlan.find params[:id]
      mp.update_attributes params[:milestone_plan]
      add_flash :notices, "Plan updated successfully."
      redirect_to milestone_plans_path
    }
  end
end
