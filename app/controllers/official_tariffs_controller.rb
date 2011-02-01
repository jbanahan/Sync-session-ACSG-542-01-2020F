class OfficialTariffsController < ApplicationController
  before_filter :brian_only
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
  
  
  private
  def brian_only
    unless current_user.username=="bglick"
      error_redirect "You do not have permission"
      return false
    end
    return true
  end
end