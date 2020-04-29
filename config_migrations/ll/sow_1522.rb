require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module ConfigMigrations; module LL; class Sow1522
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  def up
    create_carb_statements
    create_patent_statements
    create_carb_patent_custom_definitions
    update_vendor_products_search_config
    migrate_searches_to_new_carb_patent_fields
    deprecate_existing_carb_patent_fields
  end

  def down
    restore_existing_carb_patent_fields
    rollback_searches_to_old_carb_patent_fields
    restore_vendor_products_search_config
    destroy_carb_patent_custom_definitions
  end

  def create_carb_patent_custom_definitions
    cdefs = self.class.prep_custom_definitions([:prodven_carb_statements, :prodven_patent_statements, :ordln_carb_statement, :ordln_patent_statement])
    set_field_view_groups(cdefs[:prodven_carb_statements], ["ALL", "ORDERACCEPT", "CARBASSIGN"])
    set_field_view_groups(cdefs[:prodven_patent_statements], ["ALL", "ORDERACCEPT", "PATENTASSIGN"])
    nil
  end

  def set_field_view_groups cdef, group_codes
    return if cdef.nil?

    rule = ensure_rule(cdef)
    rule.can_view_groups = group_codes.join("\n")
    rule.read_only = true
    rule.save!
  end

  def destroy_carb_patent_custom_definitions
    [:prodven_carb_statements, :prodven_patent_statements, :ordln_carb_statement, :ordln_patent_statement].each do |uid|
      cd = CustomDefinition.where(cdef_uid: uid.to_s).first
      cd.try(:destroy)
    end

    nil
  end

  def deprecate_existing_carb_patent_fields
    create_read_only_rule(CustomDefinition.where(cdef_uid: "prodven_carb").first)
    create_read_only_rule(CustomDefinition.where(cdef_uid: "prodven_patent").first)
    nil
  end

  def restore_existing_carb_patent_fields
    remove_read_only_rule(CustomDefinition.where(cdef_uid: "prodven_carb").first)
    remove_read_only_rule(CustomDefinition.where(cdef_uid: "prodven_patent").first)
    nil
  end

  def create_read_only_rule cdef
    return if cdef.nil?

    rule = ensure_rule(cdef)

    rule.read_only = true
    rule.disabled = true
    rule.save!
  end

  def remove_read_only_rule cdef
    return if cdef.nil?

    rule = ensure_rule(cdef)

    rule.read_only = false
    rule.disabled = false
    rule.save!
  end

  def migrate_searches_to_new_carb_patent_fields
    cdefs = self.class.prep_custom_definitions([:prodven_carb, :prodven_patent, :ordln_carb_statement, :ordln_patent_statement])

    [[cdefs[:prodven_carb], cdefs[:ordln_carb_statement]], [cdefs[:prodven_patent], cdefs[:ordln_patent_statement]]].each do |fields|
      old_id = fields[0].id
      new_id = fields[1].id
      old_uid = "#{fields[0].model_field_uid}_order_lines"
      new_uid = fields[1].model_field_uid

      SearchCriterion.where(model_field_uid: old_uid, custom_definition_id: old_id).update_all(model_field_uid: new_uid, custom_definition_id: new_id)
      SearchColumn.where(model_field_uid: old_uid, custom_definition_id: old_id).update_all(model_field_uid: new_uid, custom_definition_id: new_id)
      SortCriterion.where(model_field_uid: old_uid, custom_definition_id: old_id).update_all(model_field_uid: new_uid, custom_definition_id: new_id)
    end
  end

  def rollback_searches_to_old_carb_patent_fields
    cdefs = self.class.prep_custom_definitions([:prodven_carb, :prodven_patent, :ordln_carb_statement, :ordln_patent_statement])

    [[cdefs[:prodven_carb], cdefs[:ordln_carb_statement]], [cdefs[:prodven_patent], cdefs[:ordln_patent_statement]]].each do |fields|
      old_id = fields[0].id
      new_id = fields[1].id
      old_uid = "#{fields[0].model_field_uid}_order_lines"

      SearchCriterion.where(custom_definition_id: new_id).update_all(model_field_uid: old_uid, custom_definition_id: old_id)
      SearchColumn.where(custom_definition_id: new_id).update_all(model_field_uid: old_uid, custom_definition_id: old_id)
      SortCriterion.where(custom_definition_id: new_id).update_all(model_field_uid: old_uid, custom_definition_id: old_id)
    end
  end

  def ensure_rule cdef
    rule = cdef.field_validator_rules.first
    if rule.nil?
      rule = cdef.field_validator_rules.build custom_definition_id: cdef.id, module_type: cdef.module_type, model_field_uid: cdef.model_field_uid
    end

    rule
  end

  def update_vendor_products_search_config
    cdefs = self.class.prep_custom_definitions([:prodven_carb_statements, :prodven_patent_statements])

    carb_uid = cdefs[:prodven_carb_statements].model_field_uid
    patent_uid = cdefs[:prodven_patent_statements].model_field_uid

    config = SearchTableConfig.where(page_uid: "vendor-product", name: "CARB/Patent").first
    config.config_json = carb_search_table_config(carb_uid, patent_uid)
    config.save!
    nil
  end

  def restore_vendor_products_search_config
    cdefs = self.class.prep_custom_definitions([:prodven_carb, :prodven_patent])

    carb_uid = CustomDefinition.where(cdef_uid: "prodven_carb").first.try(:model_field_uid)
    patent_uid = CustomDefinition.where(cdef_uid: "prodven_patent").first.try(:model_field_uid)

    config = SearchTableConfig.where(page_uid: "vendor-product", name: "CARB/Patent").first
    config.config_json = carb_search_table_config(carb_uid, patent_uid)
    config.save!
    nil
  end

  def carb_search_table_config carb_uid, patent_uid
    {
      "columns"=>["prodven_puid", "prodven_name", carb_uid, patent_uid],
      "sorts"=>[{"field"=>"prodven_puid", "order"=>"A"}]
    }.to_json
  end

  def create_carb_statements
    xrefs = {
      "A" => "COMPLIES WITH CA 93120 CARB PHASE 2",
      "B" => "CARB - NAF RESIN - CA 93120",
      "C" => "CARB - ULEF RESIN - CA 93120",
      "E" => "EPA TSCA Title VI / CARB Phase 2 Compliant",
      "Z" => "BACKER BOARD COMPLIES WITH TSCA TITLE VI AND CARB PHASE 2 FORMALDEHYDE EMISSION STANDARDS"
    }
    create_data_cross_references xrefs, DataCrossReference::LL_CARB_STATEMENTS
  end

  def create_patent_statements
    xrefs = {
      "J" => "SOLD UNDER LICENSE OF FLOORING INDUSTRIES, LTD.",
      "K" => "LOCKING SYSTEM PRODUCED UNDER LICENSE FROM VALINGE INNOVATION AB AN FLOORING INDUSTRIES"
    }
    create_data_cross_references xrefs, DataCrossReference::LL_PATENT_STATEMENTS
  end

  def create_data_cross_references xref_list, type
    xref_list.each_pair do |key, value|
      DataCrossReference.where(key: key, cross_reference_type: type).first_or_create! value: value
    end
  end

end; end; end