module Api; module V1; class CountriesController < ApiController

  def index
    render json: Country.select([:id, :name]), root:false
  end
end; end end