class OfficialTariffsController < ApplicationController
  def index
    advanced_search CoreModule::OFFICIAL_TARIFF
  end
  
  def show
    @official_tariff = OfficialTariff.find(params[:id])
  end
  
  def find
    hts = TariffRecord.clean_hts params[:hts]
    cid = params[:cid]
    ot = OfficialTariff.find_cached_by_hts_code_and_country_id hts, cid 
    if ot.nil?
      if OfficialTariff.where(:country_id=>cid).empty?
        render :json => "country not loaded".to_json
      else
        render :json => nil.to_json
      end
    else
      render :json => ot.to_json(:include =>{:country => {:only => [:name,:iso_code]},:official_quota=>{:only=>[:category,:unit_of_measure,:square_meter_equivalent_factor]}})
    end
  end

  def find_schedule_b
    hts = TariffRecord.clean_hts params[:hts]
    osb = OfficialScheduleBCode.where(:hts_code=>hts).first
    render :json => osb
  end
  
  def schedule_b_matches
    ot = OfficialTariff.find_cached_by_hts_code_and_country_id TariffRecord.clean_hts(params[:hts]), Country.where(:iso_code=>'US').first.id
    render :json => (ot.nil? ? nil.to_json : ot.find_schedule_b_matches)
  end

  def secure base_search
    base_search #no extra security
  end
end
