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

  def valid_isf?
    validate_isf!
    errors.none?
  end

  def validate_isf!
    validate_isf_address_fields
    validate_parties_irs_numbers
    validate_importer_alliance_number
    validate_bill_numbers
    validate_isf_lines
  end

  def make_isf
    ImporterSecurityFiling.from_shipment(self)
  end

  private

  def validate_isf_address_fields
    [:seller_address, :buyer_address,
     :ship_to_address, :container_stuffing_address,
     :consolidator_address].each do |address_symbol|
      address = self.send(address_symbol)
      required_fields = [:name, :line_1, :city, :state, :postal_code, :country_id]
      errors[address_symbol] << "can't be blank" unless address
      address && required_fields.each do |field|
        errors[address_symbol] << "#{field.to_s.titleize} can't be blank" unless address[field].present?
      end
    end
  end

  def validate_parties_irs_numbers
    errors[:importer] << "IRS Number can't be blank" unless importer_id && importer.irs_number.present?
    errors[:consignee] << "IRS Number can't be blank" unless consignee_id && consignee.irs_number.present?
  end

  def validate_importer_alliance_number
    errors[:importer] << "must have an Alliance Customer Number" unless importer_id && importer.alliance_customer_number.present?
  end

  def validate_bill_numbers
    errors[:base] << "Shipment must have either a Master or House Bill of Lading number" unless master_bill_of_lading.present? || house_bill_of_lading.present?
  end

  def validate_isf_lines
    errors[:base] << "All shipment lines must have a Country of Origin and HTS Number" unless shipment_lines.all? {|line| line.us_hts_number && line.country_of_origin }
  end
end