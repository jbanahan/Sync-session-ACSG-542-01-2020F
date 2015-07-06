class ImporterSecurityFiling
  include ActiveModel::Validations
  attr_accessor :manufacturer_address, :seller_address, :buyer_address,
                :ship_to_address, :container_stuffing_address, :consolidator_address,
                :importer_number, :consignee_number, :country_of_origin, :hts_number

  validates :manufacturer_address, :seller_address, :buyer_address,
            :ship_to_address, :container_stuffing_address, :consolidator_address,
            :importer_number, :consignee_number, :country_of_origin, :hts_number, presence: true

  validate :addresses_have_all_required_fields, :importer_has_alliance_number

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
    new_filing.importer_number = shipment.importer.try :irs_number
    new_filing.consignee_number = shipment.consignee.try :irs_number
    new_filing.country_of_origin = country_of_origin_query
    new_filing.hts_number = hts_numbers
    new_filing
  end

  def addresses_have_all_required_fields
    [:seller_address, :buyer_address,
     :ship_to_address, :container_stuffing_address,
     :consolidator_address].each do |address_symbol|
      address = self.send(address_symbol)
      required_fields = [:name, :line_1, :city, :state, :postal_code, :country]
      address && required_fields.each do |field|
        errors[address_symbol] << "#{field.to_s.titleize} cannot be blank" unless address[field].present?
      end
    end
  end

  def importer_has_alliance_number

  end
end