class OfficialTariffsController < ApplicationController
  skip_before_filter :require_user, :set_user_time_zone, :log_request, :log_run_as_request, :only=>[:auto_classify, :auto_complete]

  def auto_complete
    ot = OfficialTariff.limit(10)
    if !params[:country].blank?
      ot = ot.where(:country_id=>params[:country])
    else
      ot = ot.where('country_id = (select id from countries where iso_code = ?)', params[:country_iso])
    end
    tariffs = ot.where("hts_code LIKE ?", "#{TariffRecord.clean_hts(params[:hts])}%")
                .map { |t| {label: t.hts_code, desc: t.remaining_description} }
    render :json => params[:description] ? tariffs : tariffs.map { |t| t[:label] }
  end
  def auto_classify
    h = params[:hts].blank? ? '' : params[:hts].strip.gsub('.', '')
    found = OfficialTariff.auto_classify h
    r = []
    found.each do |k, v|
      hts = []
      v.each {|ot| hts << {'lacey_act'=>ot.lacey_act?, 'code'=>ot.hts_code, 'desc'=>ot.remaining_description, 'rate'=>ot.common_rate, 'use_count'=>ot.use_count}}
      r << {'iso'=>k.iso_code, 'country_id'=>k.id, 'hts'=>hts}
    end
    render :json => r
  end
  def index
    flash.keep
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
    ot = OfficialTariff.joins(:country).where(:hts_code=>hts).where("countries.iso_code = ?", c_iso).first unless !ot.nil? || c_iso.blank?
    if ot.nil?
      if OfficialTariff.where(:country_id=>cid).empty?
        render :json => "country not loaded".to_json
      else
        render :json => nil.to_json
      end
    else
      render :json => ot.to_json(methods: :lacey_act, :include=>{:country=>{:only=>[:name]}, :official_quota=>{:only=>[:category, :unit_of_measure, :square_meter_equivalent_factor]}})
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
