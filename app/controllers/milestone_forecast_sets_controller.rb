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

  def show
    #not worrying about security here because milestones have no valuable info without surrounding context
    render :json => MilestoneForecastSet.find(params[:id])
  end

  def show_by_order_line_id
    render :json => MilestoneForecastSet.joins(:piece_set).where("piece_sets.order_line_id = ?",params[:line_id]).all
  end
end
