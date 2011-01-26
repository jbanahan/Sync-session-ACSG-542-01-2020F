class SearchSetupsController < ApplicationController
  
  def show
    search_setup = SearchSetup.for_user(current_user).find(params[:id])
    respond_to do |format|
      format.json { render :json => search_setup.to_json(:include => :search_columns) }
    end 
  end
end