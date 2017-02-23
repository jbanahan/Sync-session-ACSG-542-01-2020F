module OpenChain; module EntityCompare; class CascadeCompanyValidations
  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type=='Company'

    c = Company.where(id: id).first

    return unless c

    Order.where('importer_id = :cid OR vendor_id = :cid',cid:c.id).find_each do |o|
      BusinessValidationTemplate.create_results_for_object! o
    end

    Entry.where(importer_id:c.id).find_each do |e|
      BusinessValidationTemplate.create_results_for_object! e
    end
  end
end; end; end