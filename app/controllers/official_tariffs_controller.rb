class OfficialTariffsController < ApplicationController
  before_filter :brian_only, :except=>:find
  def index
    @official_tariffs = OfficialTariff.all
  end
  
  def create
    OfficialTariff.create!(params[:official_tariff])
    redirect_to OfficialTariff
  end
  
  def update
    OfficialTariff.find(params[:id]).update_attributes(params[:official_tariff])
    redirect_to OfficialTariff
  end    
  
  def show
    @official_tariff = OfficialTariff.find(params[:id])
    @official_tariffs = OfficialTariff.all
    render 'index'
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
  
  private
  def brian_only
    unless current_user.username=="bglick"
      error_redirect "You do not have permission to view this page."
      return false
    end
    return true
  end
end
