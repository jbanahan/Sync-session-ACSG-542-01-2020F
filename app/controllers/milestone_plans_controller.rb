class MilestonePlansController < ApplicationController

  def index
    respond_to do |format|
      format.json { render :json => MilestonePlan.all}
      format.html {}
    end
  end

end
