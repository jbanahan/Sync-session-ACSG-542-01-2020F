require 'open_chain/entity_compare/product_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'

module OpenChain; module CustomHandler; module AnnInc; class AnnClassificationDefaultComparator
  extend OpenChain::EntityCompare::ProductComparator
  include OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport

  def self.accept?(snapshot)
    super
  end

  # Set 'Classification Type' to "Not Applicable" whenever it's blank
  # This is partly to enforce a default value, partly to prevent users from assigning a blank value in the drop-down.
  def self.compare(type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
    instance = self.new
    snap = instance.get_json_hash(new_bucket, new_path, new_version)
    instance.compare_product(id, snap) do |prod|
      prod&.create_snapshot User.integration, nil, "AnnClassificationDefaultComparator"
    end
  end

  # yields product if an update is made, otherwise nil
  def compare_product id, snapshot
    prod = update = nil
    json_child_entities(snapshot, "Classification").each do |classi_hsh|
      type = mf(classi_hsh, cdef)
      if type.blank?
        prod ||= Product.where(id: id).includes(:classifications).first
        Lock.db_lock(prod) do
          classi = prod.classifications.find{ |cl| cl.id == classi_hsh["record_id"] }
          if classi
            classi.update_custom_value! cdef, "Not Applicable"
            update = true
          end
        end
      end
    end
    yield (update ? prod : nil)
  end

  def cdef
    @cdef ||= self.class.prep_custom_definitions([:classification_type])[:classification_type]
  end

end; end; end; end
