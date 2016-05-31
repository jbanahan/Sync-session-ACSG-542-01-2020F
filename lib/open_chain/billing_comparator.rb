require 'open_chain/s3'
require 'open_chain/entity_compare/comparator_helper'

module OpenChain
  class BillingComparator
    def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
      return unless ['Product', 'Entry'].include? type
      new_snapshot_id = EntitySnapshot.where(bucket: new_bucket, doc_path: new_path, version: new_version).first.id
      args = {id: id, old_bucket: old_bucket, old_path: old_path, old_version: old_version, new_bucket: new_bucket, 
              new_path: new_path, new_version: new_version}.merge(new_snapshot_id: new_snapshot_id)
      ("OpenChain::BillingComparator::#{type}Comparer").constantize.go args
    end

    #abstract base class
    class Comparer
      include OpenChain::EntityCompare::ComparatorHelper
      def self.go args
        c = self.new
        instance_methods(false).each{ |meth| c.send(meth, args) }
      end
    end

    #For each core module type listed in BillingComparator.compare, implement a class ModuleNameComparer < Comparer. Each public instance method represents an event type.
    class ProductComparer < Comparer
      def check_new_classification args
        old_hsh, new_hsh = new_cl_get_hashes args
        new_cl_ids = new_cl_get_ids(old_hsh, new_hsh)
        BillableEvent.transaction do
          new_cl_ids.each do |id|
            BillableEvent.create!(eventable_type: "Classification", eventable_id: id, entity_snapshot_id: args[:new_snapshot_id], event_type: "Classification - New")
          end
        end
      end
      
      private

      def new_cl_get_hashes args
        old_hsh = get_json_hash(args[:old_bucket], args[:old_path], args[:old_version]) unless args[:old_bucket].nil?
        new_hsh = get_json_hash(args[:new_bucket], args[:new_path], args[:new_version])
        [old_hsh, new_hsh]
      end

      def new_cl_get_ids old_hsh, new_hsh
        new_hsh_ids = new_hsh["entity"]["children"].map { |cl| cl["entity"]["record_id"] }
        if old_hsh
          old_hsh_ids = old_hsh["entity"]["children"].map { |cl| cl["entity"]["record_id"] }
          new_hsh_ids - old_hsh_ids
        else
          new_hsh_ids
        end
      end
    end

    class EntryComparer < Comparer
      def check_new args
        return if args[:old_bucket]
        ent = Entry.find args[:id]
        BillableEvent.create!(eventable: ent, entity_snapshot_id: args[:new_snapshot_id], event_type: "Entry - New")
      end
    end

  end
end