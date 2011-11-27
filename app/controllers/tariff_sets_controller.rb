class TariffSetsController < ApplicationController

  def index 
    t = params[:country_id] ? TariffSet.where(:country_id=>params[:country_id]) : TariffSet.where(true)
    t = t.includes(:country).order("countries.name ASC, tariff_sets.label DESC").to_a
    respond_to do |format|
      format.json {render :json => t.to_json}
      format.html {@tariff_sets = t}#index.html.erb
    end 
  end

end
