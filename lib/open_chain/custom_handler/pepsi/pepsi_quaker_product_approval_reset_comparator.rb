require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/product_comparator'
require 'open_chain/custom_handler/pepsi/pepsi_custom_definition_support'


module OpenChain; module CustomHandler; module Pepsi; class PepsiQuakerProductApprovalResetComparator
  include OpenChain::CustomHandler::Pepsi::PepsiCustomDefinitionSupport
  extend OpenChain::EntityCompare::ComparatorHelper
  extend OpenChain::EntityCompare::ProductComparator

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return if old_bucket.blank?
    self.new.compare_hashes(id, get_json_hash(old_bucket, old_path, old_version), get_json_hash(new_bucket, new_path, new_version))
  end

  def compare_hashes id, old_hash, new_hash
    old_fingerprint = fingerprint(old_hash)
    new_fingerprint = fingerprint(new_hash)
    reset(id) if old_fingerprint!=new_fingerprint
  end

  def reset id
    p = Product.find_by_id id
    return unless p # must have been deleted
    reset_cdefs.each do |k, v|
      p.update_custom_value!(v, nil)
    end
    p.create_snapshot(User.integration, nil, "Product Approval Reset")
  end

  def fingerprint hash
    pmf = hash['entity']['model_fields']
    r = {
      'prod_uid' => pmf['prod_uid'],
      'classifications' => {}
    }
    cdefs.each do |k, cd|
      next unless cd.module_type=='Product'
      r[k.to_s] = pmf[cd.model_field_uid]
    end

    classifications = hash['entity']['children']
    if classifications
      classifications.each do |cls|
        cls_mf = cls['entity']['model_fields']
        iso = cls_mf['class_cntry_iso']
        r['classifications'][iso] = {}
        h = r['classifications'][iso]
        cdefs.each do |k, cd|
          next unless cd.module_type=='Classification'
          h[k.to_s] = cls_mf[cd.model_field_uid]
        end
        h['tariff_records'] = {}
        tr_h = h['tariff_records']
        cls_children = cls['entity']['children']
        if cls_children
          cls_children.each do |tr|
            tr_mf = tr['entity']['model_fields']
            tr_h[tr_mf['hts_line_number']] = {}
            tr_h[tr_mf['hts_line_number']]['hts_hts_1'] = tr_mf['hts_hts_1']
          end
        end
      end
    end

    r.to_json
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([
    :prod_shipper_name, :prod_prod_code, :prod_us_broker, :prod_us_alt_broker, :prod_alt_prod_code,
    :prod_coo, :prod_tcsa, :prod_recod, :prod_first_sale, :prod_related, :prod_fda_pn, :prod_fda_uom_1, :prod_fda_uom_2,
    :prod_fda_fce, :prod_fda_sid, :prod_fda_dims, :prod_oga_1, :prod_oga_2, :prod_prog_code, :prod_proc_code, :prod_indented_use,
    :prod_trade_name, :prod_cbp_mid, :prod_fda_mid, :prod_base_customs_description, :prod_fda_code, :prod_fda_reg, :prod_fdc, :prod_fda_desc,
    :class_add_cvd, :class_fta_end, :class_fta_start, :class_fta_notes, :class_fta_name,
    :class_ior, :class_tariff_shift, :class_val_content, :class_ruling_number, :class_customs_desc_override
  ])
  end

  def reset_cdefs
    @reset_cdefs ||= self.class.prep_custom_definitions([
      :prod_quaker_validated_by, :prod_quaker_validated_date
    ])
  end

end; end; end; end
