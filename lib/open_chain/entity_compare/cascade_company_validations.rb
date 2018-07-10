module OpenChain; module EntityCompare; class CascadeCompanyValidations

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type=='Company'

    c = Company.where(id: id).first
    # Never validate everything if the company that was updated was teh master company, this is going to 
    # literally validate every order and/or entry in the system.
    return if c.master?

    return unless c

    validate_connected_orders(c) unless MasterSetup.get.custom_feature?("Disable Cascading Company to Order Validations")
    validate_connected_entries(c) unless MasterSetup.get.custom_feature?("Disable Cascading Company to Entry Validations")
  end

  def self.validate_connected_orders c
    Order.where('importer_id = :cid OR vendor_id = :cid',cid:c.id).where(closed_at: nil).find_each do |o|
      BusinessValidationTemplate.create_results_for_object! o
    end
  end

  def self.validate_connected_entries c
    Entry.where(importer_id:c.id).find_each do |e|
      BusinessValidationTemplate.create_results_for_object! e
    end
  end
  
end; end; end