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
    hts = params[:hts]
    cid = params[:cid]
    ot = OfficialTariff.where(:hts_code=>hts,:country_id=>cid).first
    render :json => ot.to_json(:include =>{:country => {:only => :name},:official_quota=>{:only=>[:category,:unit_of_measure,:square_meter_equivalent_factor]}})
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
