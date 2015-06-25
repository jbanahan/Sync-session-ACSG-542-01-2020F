module ISFSupport
  def self.included(base)
    base.instance_eval do
      belongs_to :manufacturer_address, class_name: 'Address'
      belongs_to :seller_address, class_name: 'Address'
      belongs_to :buyer_address, class_name: 'Address'
      belongs_to :ship_to_address, class_name: 'Address'
      belongs_to :container_stuffing_address, class_name: 'Address'
      belongs_to :consolidator_address, class_name: 'Address'
    end
  end
end

class ImporterSecurityFiling
  include ActiveModel::Validations
  attr_accessor :manufacturer_address, :seller_address, :buyer_address,
                :ship_to_address, :container_stuffing_address, :consolidator_address,
                :importer_of_record, :consignee_numbers, :country_of_origin, :hts_number

  validates :manufacturer_address, :seller_address, :buyer_address,
            :ship_to_address, :container_stuffing_address, :consolidator_address,
            :importer_of_record, :consignee_numbers, :country_of_origin, :hts_number, presence: true

  def self.from_shipment(shipment)
    assert(shipment.is_a? Shipment)
    new_filing = new
    new_filing.manufacturer_address = shipment.manufacturer_address
    new_filing.seller_address = shipment.seller_address
    new_filing.buyer_address = shipment.buyer_address
    new_filing.ship_to_address = shipment.ship_to_address
    new_filing.container_stuffing_address = shipment.container_stuffing_address
    new_filing.consolidator_address = shipment.consolidator_address
    new_filing.importer_of_record = shipment.importer
    new_filing.country_of_origin = shipment.shipment_lines.flat_map(&:order_lines).map(&:country_of_origin)
    new_filing
  end
end