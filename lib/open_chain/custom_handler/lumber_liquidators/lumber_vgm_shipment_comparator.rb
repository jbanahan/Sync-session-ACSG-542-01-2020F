require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/uncancelled_shipment_comparator'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberVgmShipmentComparator
  extend OpenChain::EntityCompare::UncancelledShipmentComparator
  include OpenChain::EntityCompare::ComparatorHelper

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    # If shipment.packing_list_sent_at changes or if Custom Field shp_vgm_resent_date changes a new VGM file should
    # be generated, and a sync record for it created/updated.
  end

end; end; end; end;