class TariffSetsController < ApplicationController

  def index 
    t = params[:country_id] ? TariffSet.where(:country_id=>params[:country_id]) : TariffSet.where(true)
    t = t.order("tariff_sets.label DESC").to_a
    render :json => t.to_json
  end

end
