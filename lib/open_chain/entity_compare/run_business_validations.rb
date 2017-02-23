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
    # We don't have to actually run validations on the object that was snapshot'ed since validations on that object
    # are run as part of the snapshot'ing process...all that needs to be done here is the cascading.
    CASCADE_CLASSES.each {|c| c.compare(type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)}
  end
end; end; end