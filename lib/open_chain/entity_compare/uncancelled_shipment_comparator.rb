require 'open_chain/entity_compare/shipment_comparator'

module OpenChain; module EntityCompare; module UncancelledShipmentComparator
  include OpenChain::EntityCompare::ShipmentComparator
  extend ActiveSupport::Concern

  def accept? snapshot
    super(snapshot) && snapshot.recordable.try(:canceled_date).nil?
  end

end; end; end