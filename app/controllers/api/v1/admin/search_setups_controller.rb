module Api; module V1; module Admin; class SearchSetupsController < Api::V1::Admin::AdminApiController

  # Create a new template based on this search
  # POST /api/v1/admin/search_setups/:id/create_template
  def create_template
    ss = SearchSetup.find params[:id]
    SearchTemplate.create_from_search_setup! ss
    render json: {message:'OK'}
  end
end; end; end; end