class ImporterSecurityFiling
  include ActiveModel::Validations
  attr_accessor :manufacturer_address, :seller_address, :buyer_address,
                :ship_to_address, :container_stuffing_address, :consolidator_address,
                :importer_of_record, :consignee_numbers, :country_of_origin, :hts_number

  validates :manufacturer_address, :seller_address, :buyer_address,
            :ship_to_address, :container_stuffing_address, :consolidator_address,
            :importer_of_record, :consignee_numbers, :country_of_origin, :hts_number, presence: true

  def self.from_shipment(shipment)
    raise 'Not a shipment!' unless shipment.is_a? Shipment
    country_of_origin_query = OrderLine.joins(:piece_sets)
                                  .where(piece_sets: {shipment_line_id: shipment.shipment_lines.pluck(:id)})
                                  .uniq.pluck(:country_of_origin)

    all_product_ids = ShipmentLine.where(shipment_id: shipment.id).uniq.pluck(:product_id)
    all_classification_ids = Classification.where(product_id: all_product_ids).pluck(:id)
    hts_numbers = TariffRecord.where(classification_id: all_classification_ids).uniq.pluck(:hts_1)

    new_filing = new
    new_filing.manufacturer_address = shipment.manufacturer_address
    new_filing.seller_address = shipment.seller_address
    new_filing.buyer_address = shipment.buyer_address
    new_filing.ship_to_address = shipment.ship_to_address
    new_filing.container_stuffing_address = shipment.container_stuffing_address
    new_filing.consolidator_address = shipment.consolidator_address
    new_filing.importer_of_record = shipment.importer
    new_filing.country_of_origin = country_of_origin_query
    new_filing.hts_number = hts_numbers
    new_filing
  end
end