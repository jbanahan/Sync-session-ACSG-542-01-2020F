module OpenChain; module EntityCompare; class RunBusinessValidations
  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    BusinessValidationTemplate.create_results_for_object! CoreModule.find_by_class_name(type).find(id)
  end
end; end; end