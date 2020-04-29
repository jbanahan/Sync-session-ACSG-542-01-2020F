require 'open_chain/api/v1/official_tariff_api_json_generator'

module Api; module V1; class OfficialTariffsController < Api::V1::ApiCoreModuleControllerBase

  def core_module
    CoreModule::OFFICIAL_TARIFF
  end

  def find
    hts = params[:hts]
    hts ||= ''
    hts = hts.gsub(/\D/, '') # remove all non-numeric characters
    iso = params[:iso]
    iso ||= ''
    iso = iso.strip
    o = OfficialTariff.where(hts_code:hts).where("country_id = (SELECT id from countries WHERE iso_code = ? LIMIT 1)", iso).first
    render_obj o
  end

  def json_generator
    OpenChain::Api::V1::OfficialTariffApiJsonGenerator.new
  end

end; end; end

