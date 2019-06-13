require 'open_chain/api/v1/api_json_controller_adapter'
require 'open_chain/registries/customized_api_response_registry'

module OpenChain; module Api; module V1; class ProductApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::PRODUCT, jsonizer: jsonizer)
  end

  def obj_to_json_hash obj
    product_fields = limit_fields(
      [:prod_uid, :prod_ent_type, :prod_name, :prod_uom, :prod_changed_at, :prod_last_changed_by, :prod_created_at,
       :prod_div_name, :prod_imp_name, :prod_imp_syscode, :prod_inactive] +
      custom_field_keys(CoreModule::PRODUCT)
    )

    class_fields = limit_fields (
      [:class_cntry_name, :class_cntry_iso] + custom_field_keys(CoreModule::CLASSIFICATION)
    )

    tariff_fields = limit_fields(
      [:hts_line_number, :hts_hts_1, :hts_hts_1_schedb, :hts_hts_2, :hts_hts_2_schedb, :hts_hts_3, :hts_hts_3_schedb] +
      custom_field_keys(CoreModule::TARIFF)
    )

    field_list = product_fields + class_fields + tariff_fields

    if MasterSetup.get.variant_enabled?
      variant_fields = limit_fields(
        [:var_identifier] + custom_field_keys(CoreModule::VARIANT)
      )
      field_list = field_list + variant_fields
    end

    h = to_entity_hash(obj, field_list)
    h[:permissions] = render_permissions(obj)
    if render_attachments?
      render_attachments(obj,h)
    end

    OpenChain::Registries::CustomizedApiResponseRegistry.customize_product_response(obj, current_user, h, params)

    return h
  end

  private
    def render_permissions product
      cu = current_user #current_user is method, so saving as variable to prevent multiple calls
      {
        can_view: product.can_view?(cu),
        can_edit: product.can_edit?(cu),
        can_classify: product.can_classify?(cu),
        can_comment: product.can_comment?(cu),
        can_attach: product.can_attach?(cu),
        can_manage_variants: product.can_manage_variants?(cu)
      }
    end
end; end; end; end;
