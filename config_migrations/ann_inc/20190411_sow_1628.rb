require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'
require 'open_chain/custom_handler/ann_inc/ann_validation_rule_product_class_type_set'
require 'open_chain/custom_handler/ann_inc/ann_validation_rule_product_tariff_percent_of_value_set'
require 'open_chain/custom_handler/ann_inc/ann_validation_rule_product_tariff_percents_add_to_100'
require 'open_chain/custom_handler/ann_inc/ann_validation_rule_product_tariff_key_description_set'
require 'open_chain/custom_handler/ann_inc/ann_validation_rule_product_one_tariff'

module ConfigMigrations; module AnnInc; class Sow1628
  include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport

  NEW_DEFS = [:classification_type, :percent_of_value, :key_description]
  DEFS = NEW_DEFS + [:manual_flag, :approved_date]
  RULE_STEM = OpenChain::CustomHandler::AnnInc

  def up
    generate_custom_fields
    generate_business_rules
    backfill_fields
  end

  # NOTE: if AnnClassificationDefaultComparator isn't disabled first, "Classification Type" cvals will be automatically replaced.
  def down
    drop_custom_fields
    drop_business_rules
  end

  def defs
    @defs ||= self.class.prep_custom_definitions DEFS
  end

  def new_defs
    @new_defs ||= self.class.prep_custom_definitions NEW_DEFS
  end

  def generate_custom_fields
    cd = defs[:classification_type]
    fvr = FieldValidatorRule.where(model_field_uid: cd.model_field_uid, module_type: cd.module_type).first_or_initialize
    fvr.update_attributes! one_of: "Multi\nDecision\nNot Applicable"

    cd = defs[:key_description]
    fvr = FieldValidatorRule.where(model_field_uid: cd.model_field_uid, module_type: cd.module_type).first_or_initialize
    fvr.update_attributes! maximum_length: 50

    cd = defs[:percent_of_value]
    fvr = FieldValidatorRule.where(model_field_uid: cd.model_field_uid, module_type: cd.module_type).first_or_initialize
    fvr.update_attributes! regex: "^[1-9][0-9]{0,1}$"
  end

  def generate_business_rules
    # start over if template already exists
    BusinessValidationTemplate.where(system_code: "FTZ").destroy_all
    bvt = BusinessValidationTemplate.new name: "FTZ", system_code: "FTZ", description: "Validate FTZ-specific fields", module_type: "Product", disabled: true
    bvt.search_criterions << SearchCriterion.new(model_field_uid: defs[:approved_date].model_field_uid, operator: "notnull", value: "")

    bvt.business_validation_rules << RULE_STEM::AnnValidationRuleProductClassTypeSet.new(fail_state: "Fail", name: "Classification Type set", description: "Fail if Manual Entry Processing is true and Classification Type is blank.")
    bvt.business_validation_rules << RULE_STEM::AnnValidationRuleProductTariffPercentOfValueSet.new(fail_state: "Fail", name: "Percent of Value set", description: "Fail if Classification Type is Multi and any tariff is missing a Percent of Value.")
    bvt.business_validation_rules << RULE_STEM::AnnValidationRuleProductTariffPercentsAddTo100.new(fail_state: "Fail", name: "Percent of Value adds to 100", description: "Fail if Classification Type is Multi and tariff Percent of Value fields don't add to 100.")
    bvt.business_validation_rules << RULE_STEM::AnnValidationRuleProductTariffKeyDescriptionSet.new(fail_state: "Fail", name: "Key Description set", description: "Fail if Classification Type is filled and any tariff is missing a Key Description.")
    bvt.business_validation_rules << RULE_STEM::AnnValidationRuleProductOneTariff.new(fail_state: "Fail", name: "Only one tariff", description: "Fail if Classification Type isn't set and more than one tariff exists.")
    bvt.save!
  end

  def backfill_fields
    cdef = defs[:classification_type]
    prods_to_update = Product.joins(:classifications)
                             .joins("LEFT OUTER JOIN custom_values cv ON cv.customizable_id = classifications.id AND cv.customizable_type = 'Classification' AND cv.custom_definition_id = #{cdef.id}")
                             .where("cv.id IS NULL")
                             .uniq

    prods_to_update.find_in_batches(batch_size:1000) do |batched_prods|
      batched_prods.each do |prod|
        # avoids read-only error associated with #joins
        prod = Product.find prod.id
        classis_to_update = prod.classifications.reject { |cl| cl.custom_value(cdef).present? }
        Product.transaction do
          classis_to_update.each { |cl| cl.find_and_set_custom_value cdef, "Not Applicable" }
          prod.save!
          prod.create_snapshot(User.integration, nil, "Ann SOW 1628 Config migration") if classis_to_update.present?
        end
      end
    end
  end

  def drop_custom_fields
    Product.joins(:classifications).find_in_batches(batch_size:1000) do |batched_prods|
      batched_prods.each do |prod|
        cvals_to_destroy = []
        prod.classifications.each do |cl|
          cvals_to_destroy.concat matching_cvals(cl, new_defs)
          cl.tariff_records.each do |tr|
            cvals_to_destroy.concat matching_cvals(tr, new_defs)
          end
        end
        Product.transaction do
          cvals_to_destroy.each(&:destroy)
          prod.reload.create_snapshot(User.integration, nil, "rollback Ann SOW 1628 Config migration")
        end
      end
    end
    # automatically destroys validator rules
    new_defs.values.each(&:destroy)
  end

  def matching_cvals entity, cdefs
    cdef_ids = new_defs.values.map(&:id)
    entity.custom_values.select { |cval| cdef_ids.include? cval.custom_definition_id }
  end

  def drop_business_rules
    BusinessValidationTemplate.where(system_code: "FTZ").destroy_all
  end

end; end; end
