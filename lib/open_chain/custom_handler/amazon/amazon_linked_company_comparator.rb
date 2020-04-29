require 'open_chain/entity_compare/entry_comparator'

module OpenChain; module CustomHandler; module Amazon; class AmazonLinkedCompanyComparator
  extend OpenChain::EntityCompare::EntryComparator

  def self.amazon
    amz = Company.where(system_code: "AMZN").first
    raise "No company found with 'AMZN' system code." unless amz
    amz
  end

  # accept only if entry's customer belongs to Amazon but is not yet linked
  def self.accept? snapshot
    if super
      cust_num = snapshot.recordable.customer_number.to_s.upcase
      if cust_num.match?(/^AMZN/)
        return !amazon.linked_companies.map(&:system_code).include?(cust_num)
      end
    end
    false
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    ent = Entry.find id
    customer = ent.importer
    begin
      amazon.linked_companies << customer
    rescue ActiveRecord::RecordNotUnique
      # If the company has already been added then no harm done
    end
  end

end; end; end; end
