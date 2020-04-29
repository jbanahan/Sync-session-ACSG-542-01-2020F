# -*- SkipSchemaAnnotations
module ISFSupport
  def self.included(base)
    base.instance_eval do
      belongs_to :seller_address, class_name: 'Address'
      belongs_to :buyer_address, class_name: 'Address'
      belongs_to :ship_to_address, class_name: 'Address'
      belongs_to :container_stuffing_address, class_name: 'Address'
      belongs_to :consolidator_address, class_name: 'Address'
    end
  end

  def valid_isf?
    validate_isf
    errors.none?
  end

  def validate_isf
    validate_isf_address_fields
    validate_parties_irs_numbers
    validate_importer_alliance_number
    validate_bill_numbers
    validate_isf_lines
    validate_shipment_line_parties
  end

  private

  def validate_isf_address_fields
    [:seller_address, :buyer_address,
     :ship_to_address, :container_stuffing_address,
     :consolidator_address].each do |address_symbol|
      address = self.send(address_symbol)
      required_fields = required_address_fields
      if address
        missing_fields = required_fields.keys.select { |field| address[field].blank? }.map {|field| required_fields[field]}
        errors[address_symbol] << "is missing required fields: #{missing_fields.join(', ')}" if missing_fields.any?
      else
        errors[address_symbol] << "must be present"
      end
    end
  end

  def validate_parties_irs_numbers
    errors[:importer] << "Importer IRS Number can't be blank" unless importer_id && importer.irs_number.present?
    errors[:consignee] << "Consignee IRS Number can't be blank" unless consignee_id && consignee.irs_number.present?
  end

  def validate_importer_alliance_number
    errors[:importer] << "must have an Alliance Customer Number" unless importer_id && importer.kewill_customer_number.present?
  end

  def validate_bill_numbers
    errors[:base] << "Shipment must have either a Master or House Bill of Lading number" unless master_bill_of_lading.present? || house_bill_of_lading.present?
  end

  def validate_isf_lines
    errors[:base] << "All shipment lines must have a Country of Origin and HTS Number" unless shipment_lines.all? {|line| line.us_hts_number && line.country_of_origin }
  end

  def validate_shipment_line_parties
    required_fields = required_address_fields
    shipment_lines.each do |line|
      address = line.manufacturer_address
      if address
        missing_fields = required_fields.keys.select { |field| address[field].blank? }.map {|field| required_fields[field]}
        errors[:base] << "Shipment Line #{line.line_number} Manufacturer address is missing required fields: #{missing_fields.join(', ')}"  if missing_fields.any?
      else
        errors[:base] << "Shipment Line #{line.line_number} Manufacturer address is missing"
      end
    end
  end

  def required_address_fields
    {name: "Name", line_1: "Address 1", city: "City", state: "State", postal_code: "Postal Code", country_id: "Country"}
  end
end