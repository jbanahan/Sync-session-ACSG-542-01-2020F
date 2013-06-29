class OfficialTariffsController < ApplicationController
  skip_before_filter :require_user, :set_user_time_zone, :log_request, :only=>[:auto_classify,:auto_complete]

  def auto_complete
    render :json=>OfficialTariff.where(:country_id=>params[:country]).where("hts_code LIKE ?","#{params[:hts]}%").pluck(:hts_code)
  end
  def auto_classify
    h = params[:hts].blank? ? '' : params[:hts].strip.gsub('.','')
    found = OfficialTariff.auto_classify h
    r = []
    found.each do |k,v|
      hts = []
      v.each {|ot| hts << {'code'=>ot.hts_code,'desc'=>ot.remaining_description,'rate'=>ot.common_rate}}
      r << {'iso'=>k.iso_code,'country_id'=>k.id,'hts'=>hts}
    end
    r
    render :json => r
  end
  def index
    redirect_to advanced_search CoreModule::OFFICIAL_TARIFF, params[:force_search]
  end
  
  def show
    @official_tariff = OfficialTariff.find(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless @official_tariff && @official_tariff.can_view?(current_user)
  end
  
  def find
    hts = TariffRecord.clean_hts params[:hts]
    cid = params[:cid]
    ot = nil
    ot = OfficialTariff.find_cached_by_hts_code_and_country_id hts, cid unless cid.blank?
    c_iso = params[:ciso]
    ot = OfficialTariff.joins(:country).where(:hts_code=>hts).where("countries.iso_code = ?",c_iso).first unless !ot.nil? || c_iso.blank?
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
    OfficalTariff.search_secure current_user, base_search
  end
end
