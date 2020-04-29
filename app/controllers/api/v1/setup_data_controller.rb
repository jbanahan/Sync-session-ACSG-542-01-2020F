# provides general info on system setup that users may need
module Api; module V1; class SetupDataController < ApiController
  def index
    render json: {'import_countries'=>import_countries, 'regions'=>regions}
  end

  def import_countries
    Country.import_locations.sort_classification_rank.sort_name.collect do |c|
      {
        id: c.id,
        iso_code: c.iso_code,
        name: c.name,
        classification_rank: c.classification_rank
      }
    end
  end
  private :import_countries

  def regions
    Region.order(:name).includes(:countries).collect do |r|
      {
        id: r.id,
        name: r.name,
        countries: r.countries.collect {|c| c.iso_code}
      }
    end
  end

end; end; end