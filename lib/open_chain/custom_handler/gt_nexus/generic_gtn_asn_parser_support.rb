module OpenChain; module CustomHandler; module GtNexus; module GenericGtnAsnParserSupport

  def find_port port_xml, lookup_type_order: [:schedule_d_code, :schedule_k_code, :unlocode, :iata_code]
    return nil if port_xml.nil?
    
    # The port may have Locode, Schedule D or K codes..look for D, then K, then fall back to locode
    port = nil
    Array.wrap(lookup_type_order).each do |lookup_type|
      case(lookup_type)
      when :schedule_d_code
        code = port_xml.text "CityCode[@Qualifier='D']"
      when :schedule_k_code
        code = port_xml.text "CityCode[@Qualifier='K']"
      when :unlocode
        code = port_xml.text "CityCode[@Qualifier='UN']"
      when :iata_code
        code = port_xml.text "CityCode[@Qualifier='IA']"
      end

      if !code.blank?
        port = Port.where(lookup_type => code).first
        break if port
      end
    end

    port
  end

  def find_port_country port_xml
    iso_code = port_xml&.text("CountryCode")
    return nil if iso_code.blank?
    
    @port ||= Hash.new do |h, k|
      h[k] = Country.where(iso_code: k).first
    end


    iso_code.blank? ? nil : @port[iso_code]
  end

  def parse_date date
    d = parse_datetime(date)
    d.nil? ? nil : d.to_date
  end

  def parse_datetime date
    return nil if date.nil?

    Time.zone.parse(date)
  end

  def parse_decimal v
    return nil if v.nil?

    BigDecimal(v)
  end

  def parse_weight xml
    val = parse_decimal(xml.try(:text))
    return nil unless val
    
    code = xml.attributes["ANSICode"]
    # I'm assuming LB and KG are the only values that are going to get sent here.
    if code == "KG"
      return val
    else
      return BigDecimal("0.453592") * val
    end
  end

  def parse_volume xml
    val = parse_decimal(xml.try(:text))
    return nil unless val

    code = xml.attributes["ANSICode"]
    # I'm assuming CR (cubic Meters) and Cubic Feet are the only values that are going to get sent here.
    if code == "CR"
      return val
    else
      return BigDecimal("0.0283168") * val
    end
  end

  def parse_reference_date xml, reference_date_type, datatype: :datetime
    date = xml.text "ReferenceDates[ReferenceDateType = '#{reference_date_type}']/ReferenceDate"
    if datatype && datatype == :date
      return parse_date(date)
    else
      return parse_datetime(date)
    end
  end

end; end; end; end