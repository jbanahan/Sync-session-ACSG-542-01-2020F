class MilestoneDefinitionsController < ApplicationController

  def index
    respond_to do |format|
      format.json {render :json => MilestonePlan.find(params[:milestone_plan_id]).milestone_definitions.all}
      format.html {error_redirect "This page is not visable in a web browser."}
    end
  end

end
