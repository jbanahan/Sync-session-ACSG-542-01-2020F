# -*- SkipSchemaAnnotations

# Checks that every order line has an HTS with a corresponding OfficialTariff for the specified country
# required JSON: {"iso_code": <string>}

class ValidationRuleOrderLineHtsValid < BusinessValidationRule
  include ValidatesOrderLine
  attr_accessor :valid_tariffs_for_order

  def run_child_validation order_line
    self.valid_tariffs_for_order ||= lookup_valid_tariffs(order_line.order)
    if order_line.hts.blank?
      "Missing HTS code found on line #{order_line.line_number}."
    elsif !valid_tariffs_for_order.include? order_line.hts
      "Invalid HTS code found on line #{order_line.line_number}: #{order_line.hts}"
    end
  end

  def lookup_valid_tariffs order
    ord_hts_list = order.order_lines.map(&:hts)
    official_hts_list = OfficialTariff.where(country_id: country.id, hts_code: ord_hts_list).pluck(:hts_code)
    ord_hts_list & official_hts_list
  end

  def country
    co = Country.where(iso_code: rule_attributes["iso_code"]).first
    co || raise("Rule '#{self.name}' on '#{self.business_validation_template.name}' is missing 'iso_code' attribute.")
  end
end
