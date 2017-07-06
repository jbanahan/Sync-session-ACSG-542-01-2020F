require 'open_chain/custom_handler/polo/polo_custom_definition_support'
module ConfigMigrations; module Polo; class RlSow1139
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  NEEDED_FIELDS = [
      :fish_wildlife_source_1,
      :country_of_origin,
      :fish_wildlife_origin_1,
      :origin_wildlife,
      :knit_woven,
      :common_name_1,
      :scientific_name_1,
      :fish_wildlife
  ]

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions(NEEDED_FIELDS)
  end

  def up
    add_field_validations
    add_business_validation_rules
  end

  def down
    remove_field_validations
    remove_business_validation_rules
  end


  def add_business_validation_rules
    bvt = BusinessValidationTemplate.where(module_type: 'Product', name: 'Style Number Validation').first_or_create!
    bvt.search_criterions.create!(operator: "notnull", model_field_uid:"prod_uid")
    bvt.search_criterions.create!(operator: "gt", model_field_uid: "prod_created_at", value: Time.zone.now.to_date.to_s)

    # Style number must be 12 digits
    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name: 'Style Number must be 12 characters').first_or_create!
    rule_attributes_hash = {
        "prod_uid"=>{"regex"=>"^.{12}$"}
    }
    bvr.update_attributes(
        fail_state: "Fail",
        rule_attributes_json: rule_attributes_hash.to_json
    )

    bvt = BusinessValidationTemplate.where(module_type: 'Product', name: 'Product Validations').first_or_create!
    bvt.search_criterions.create!(operator:"regexp",model_field_uid:'prod_uid', value: "^[[:alnum:]]{12}$")

    # Fish and wildlife check
    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name: 'Fish and Wildlife indicator must be selected').first_or_create!
    bvr.search_criterions.create!(operator:"notnull",model_field_uid:"#{cdefs[:scientific_name_1].model_field_uid}")
    bvr.search_criterions.create!(operator:"notnull",model_field_uid:"#{cdefs[:fish_wildlife_origin_1].model_field_uid}")
    rule_attributes_hash = {
        "#{cdefs[:fish_wildlife].model_field_uid}"=>{"regex"=>"^true$"}
    }
    bvr.update_attributes(
        fail_state: "Fail",
        rule_attributes_json: rule_attributes_hash.to_json
    )


    # Knit/Woven rules
    country_uids = {
        us_uid: "*fhts_1_#{Country.where(iso_code: "US").first.id}",
        ca_uid: "*fhts_1_#{Country.where(iso_code: "CA").first.id}",
        eu_uid: "*fhts_1_#{Country.where(iso_code: "IT").first.id}",
        no_uid: "*fhts_1_#{Country.where(iso_code: "NO").first.id}"
    }

    create_chapter_61_rule(country_uids, bvt)
    create_chapter_62_rule(country_uids, bvt)

    rule_attributes_hash = {
        "model_field_uid" => cdefs[:knit_woven].model_field_uid,
        "regex"=>"(?i)^knit|woven$"
    }

    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name:'Chapter 63 Knit/Woven must be Knit or Woven.').first_or_create!
    bvr.search_criterions.create!(operator:"sw", value: "63", model_field_uid:country_uids[:us_uid])

    bvr.update_attributes(
        fail_state: "Fail",
        rule_attributes_json: rule_attributes_hash.to_json
    )

    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name:'Chapter 65 Knit/Woven must be Knit or Woven.').first_or_create!
    bvr.search_criterions.create!(operator:"sw", value: "65", model_field_uid:country_uids[:us_uid])
    bvr.update_attributes(
        fail_state: "Fail",
        rule_attributes_json: rule_attributes_hash.to_json
    )
  end

  def create_chapter_62_rule(uids, bvt)
    bvrs = []

    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name:'Chapter 62 US Knit/Woven must be Woven.').first_or_create!
    bvr.search_criterions.create!(operator:"sw", value: "62", model_field_uid:uids[:us_uid])
    bvrs << bvr

    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name:'Chapter 62 CA Knit/Woven must be Woven.').first_or_create!
    bvr.search_criterions.create!(operator:"sw", value: "62", model_field_uid:uids[:ca_uid])
    bvrs << bvr

    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name:'Chapter 62 EU Knit/Woven must be Woven.').first_or_create!
    bvr.search_criterions.create!(operator:"sw", value: "62", model_field_uid:uids[:eu_uid])
    bvrs << bvr

    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name:'Chapter 62 NO Knit/Woven must be Woven.').first_or_create!
    bvr.search_criterions.create!(operator:"sw", value: "62", model_field_uid:uids[:no_uid])
    bvrs << bvr

    rule_attributes_hash = {
        "model_field_uid" => cdefs[:knit_woven].model_field_uid,
        "regex"=>"(?i)^woven$"
    }

    bvrs.each do |bvr|
      bvr.update_attributes(
          fail_state: "Fail",
          rule_attributes_json: rule_attributes_hash.to_json
      )
    end
  end

  def create_chapter_61_rule(uids, bvt)
    bvrs = []

    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name:'Chapter 61 US Knit/Woven must be Knit.').first_or_create!
    bvr.search_criterions.create!(operator:"sw", value: "61", model_field_uid:uids[:us_uid])
    bvrs << bvr

    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name:'Chapter 61 CA Knit/Woven must be Knit.').first_or_create!
    bvr.search_criterions.create!(operator:"sw", value: "61", model_field_uid:uids[:ca_uid])
    bvrs << bvr

    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name:'Chapter 61 EU Knit/Woven must be Knit.').first_or_create!
    bvr.search_criterions.create!(operator:"sw", value: "61", model_field_uid:uids[:eu_uid])
    bvrs << bvr

    bvr = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name:'Chapter 61 NO Knit/Woven must be Knit.').first_or_create!
    bvr.search_criterions.create!(operator:"sw", value: "61", model_field_uid:uids[:no_uid])
    bvrs << bvr

    rule_attributes_hash = {
        "model_field_uid" => cdefs[:knit_woven].model_field_uid,
        "regex"=>"(?i)^knit$"
    }

    bvrs.each do |bvr|
      bvr.update_attributes(
          fail_state: "Fail",
          rule_attributes_json: rule_attributes_hash.to_json
      )
    end
  end

  def add_field_validations
    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:fish_wildlife_source_1].model_field_uid).first_or_create!
    fvr.one_of = "\nRanched\nCaptive\nFarmed\nWild"
    fvr.save!
    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:country_of_origin].model_field_uid).first_or_create!
    fvr.regex = "^.{2}$"
    fvr.save!
    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:fish_wildlife_origin_1].model_field_uid).first_or_create!
    fvr.regex = "^.{2}$"
    fvr.save!
    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:origin_wildlife].model_field_uid).first_or_create!
    fvr.regex = "^.{2}$"
    fvr.save!
  end

  def remove_field_validations
    NEEDED_FIELDS.each do |field|
      fvr = FieldValidatorRule.where(model_field_uid:cdefs[field].model_field_uid).first
      fvr.destroy if fvr.present?
    end
  end

  def drop_business_validation_rules
    bvt = BusinessValidationTemplate.where(module_type: 'Product', name: 'Product Validations').first
    bvt.destroy if bvt
  end


end; end; end