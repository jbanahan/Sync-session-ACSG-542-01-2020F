require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class OfficialTariffApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::OFFICIAL_TARIFF, jsonizer: jsonizer)
  end

  def obj_to_json_hash obj
    to_entity_hash(obj, limit_fields(
      [:ot_hts_code, :ot_full_desc, :ot_spec_rates, :ot_gen_rate, :ot_chapter, :ot_heading, :ot_sub_heading,
        :ot_remaining, :ot_ad_v, :ot_per_u, :ot_calc_meth, :ot_mfn,
        :ot_gpt, :ot_erga_omnes_rate, :ot_uom, :ot_col_2, :ot_import_regs, :ot_export_regs, :ot_common_rate,
        :ot_binding_ruling_url, :ot_taric_url] +
      custom_field_keys(CoreModule::OFFICIAL_TARIFF)
    ))
  end

end; end; end; end;