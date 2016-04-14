require 'open_chain/entity_compare/cascade_product_validations'
require 'open_chain/entity_compare/cascade_company_validations'

module OpenChain; module EntityCompare; class RunBusinessValidations
  CASCADE_CLASSES ||= [
    OpenChain::EntityCompare::CascadeProductValidations,
    OpenChain::EntityCompare::CascadeCompanyValidations
  ]

  def self.accept? snapshot
    # Accept everything since the purpose of this thing is to run business validations for every object
    true
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    BusinessValidationTemplate.create_results_for_object! CoreModule.find_by_class_name(type).find(id)
    CASCADE_CLASSES.each {|c| c.compare(type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)}
  end
end; end; end