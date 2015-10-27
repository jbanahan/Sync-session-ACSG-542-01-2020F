module OpenChain; module EntityCompare; class CascadeCompanyValidations
  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type=='Company'

    c = Company.find id

    return unless c

    Order.where('importer_id = :cid OR vendor_id = :cid',cid:c.id).each do |o|
      BusinessValidationTemplate.create_results_for_object! o
    end

    Entry.where(importer_id:c.id).each do |e|
      BusinessValidationTemplate.create_results_for_object! e
    end
  end
end; end; end