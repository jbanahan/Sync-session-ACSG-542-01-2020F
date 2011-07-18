class MilestoneForecastSetsController < ApplicationController

  def replan
    admin_secure {
      mfs = MilestoneForecastSet.find(params[:id])
      mfs.milestone_forecasts.destroy_all
      mfs.piece_set.create_forecasts
      mfs.reload
      render :json => mfs 
    }
  end

  def change_plan 
    mfs = MilestoneForecastSet.find params[:id]
    ps = mfs.piece_set
    action_secure(ps.change_milestone_plan?(current_user),nil,{:lock_check=>false,:verb=>"change plan for",:module_name=>"item"}) {
      mfs.milestone_forecasts.destroy_all
      ps.update_attributes(:milestone_plan_id=>params[:plan_id])
      ps.create_forecasts
      ps.reload
      render :json => ps.milestone_forecast_set
    }
  end

  def show
    #not worrying about security here because milestones have no valuable info without surrounding context
    render :json => MilestoneForecastSet.find(params[:id])
  end

  def show_by_order_line_id
    render :json => MilestoneForecastSet.joins(:piece_set).where("piece_sets.order_line_id = ?",params[:line_id]).all
  end
end
