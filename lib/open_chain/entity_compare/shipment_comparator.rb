module OpenChain; module EntityCompare; module ShipmentComparator
  extend ActiveSupport::Concern

  def accept? snapshot
    return snapshot.recordable_type == "Shipment"
  end

end; end; end