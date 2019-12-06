module OpenChain; module CustomHandler; module GtNexus; module GenericGtnParserSupport
  extend ActiveSupport::Concern

  # Extracts and parses the address information below a party element
  # For GTN, it's assumed were just going to have a single address for the company, as such 
  # the company's system code is used as well for the address' system code.
  def parse_address_info company, party_xml, party_address_type, address_system_code: nil
    address_system_code = company.system_code if address_system_code.nil?

    a = company.addresses.find {|a| a.system_code == address_system_code }

    if a.nil?
      a = company.addresses.build system_code: address_system_code
    end

    a.name = party_xml.text "name"
    a.address_type = party_address_type
    a.line_1 = party_xml.text "address/addressLine1"
    a.line_2 = party_xml.text "address/addressLine2"
    a.line_3 = party_xml.text "address/addressLine3"
    a.city = party_xml.text "address/city"
    a.state = party_xml.text "address/stateOrProvince"
    a.postal_code = party_xml.text "address/postalCodeNumber"

    country = party_xml.text "address/countryCode"
    if country
      a.country_id = Country.where(iso_code: country).first.try(:id)
    else
      a.country = nil
    end

    a
  end

  # By default, we'll want to prefix system codes, this method can be overridden to 
  # determine if codes are not needed.
  def prefix_identifiers_with_system_codes?
    true
  end

  # Parses and finds/creates all the party references returned by the party_map method's mapping.
  def parse_parties xml, user, filename
    # Create the vendor / factory prior to doing the order, otherwise we can run into duplicate key issues trying to 
    # create them inside the full order transaction.
    parties = {}
    party_map.each_pair do |party_type, xpath|
      party_xml = REXML::XPath.first(xml, xpath)
      next if party_xml.nil?

      if [:ship_to, :ship_from].include? party_type
        address = find_or_create_company_address(party_xml, user, filename, party_type, importer)
        parties[party_type] = address unless address.nil?
      else
        company = find_or_create_company(party_xml, user, filename, party_type)
        parties[party_type] = company unless company.nil?
      end
      
    end

    parties
  end

  # Looks up / creates a given party.
  def find_or_create_company party_xml, user, filename, party_type
    system_code = party_system_code(party_xml, party_type)
    return nil if system_code.blank?

    party_type_id = party_type.to_s.titleize
    company = nil
    name = party_company_name(party_xml, party_type)
    created = false
    system_id = nil
    Lock.acquire("Company-#{system_code}") do
      system_id = "GTN #{party_type_id}"
      if prefix_identifiers_with_system_codes?
        system_id = prefix_identifier_value(importer, system_id)
      end

      system_identifier = SystemIdentifier.where(system: system_id, code: system_code).first_or_create!
      company = system_identifier.company
      
      if company.nil?
        created = true
        company = Company.create!({party_type => true, name: name})
        company.system_identifiers << system_identifier
        importer.linked_companies << company
        created = true
      end
    end

    if !created
      return company unless update_party_information? company, party_xml, party_type
    end

    Lock.db_lock(company) do
      company.name = name
      address = parse_address_info(company, party_xml, party_type_id, address_system_code: "#{system_id}-#{system_code}")

      set_additional_party_information(company, party_xml, party_type)
      
      if company.changed? || address.changed?
        address.save! if address.changed?
        company.save! if company.changed?
        company.create_snapshot user, nil, filename
      end
    end

    company
  end

  def party_company_name party_xml, party_type
    party_xml.text "name"
  end

  # Callback that allows implementing class to determine if party information should be updated
  # or should just always be left as is.  Only called if the party already exists prior to the xml
  # being parsed, not for created parties.
  def update_party_information? party, party_xml, party_type
    true
  end

  def find_or_create_company_address party_xml, user, filename, party_type, company
    system_code = party_system_code(party_xml, party_type)
    return nil if system_code.blank?

    party_type_id = party_type.to_s.titleize

    if prefix_identifiers_with_system_codes?
      full_system_code = prefix_identifier_value(company, "GTN #{party_type_id}-#{system_code}")
    else
      full_system_code = "GTN #{party_type_id}-#{system_code}"
    end

    a = nil
    Lock.db_lock(company) do
      address = parse_address_info company, party_xml, party_type_id, address_system_code: full_system_code

      # If the address has been persisted already, check to see if we actually want to update it or not
      if address.persisted?
        return address unless update_party_information?(address, party_xml, party_type)
      end

      set_additional_company_address_information(address, party_xml)

      if address.changed?
        address.save!
        company.create_snapshot user, nil, filename
      end
      a = address
    end

    a
  end

  def set_additional_company_address_information address, party_xml
    # extension point...likely not really needed as basically all address information is already extracted and added to the record
    # already...but who know what might be needed at some point.
  end

  # Using the supplied party hash (key by symbol based on the party type), assigns the party
  # to the given object IFF the object responds to an assignment method of the party name.
  # ie. set_parties(obj, {party: some_party, party2: some_party}) would call 'obj.party = some_party' and 'obj.party2 = another_party'
  # if obj responded to 'party=' and 'party2='
  def set_parties obj, parties
    parties.each_pair do |party_type, party|
      method_name = "#{party_type}=".to_sym
      obj.public_send(method_name, party) if obj.respond_to?(method_name)
    end

    nil
  end

  # Retrieves a reference/value given a type code value
  def reference_value reference_parent, code
    reference_parent.text("reference[type = '#{code}']/value")
  end

  # Retrieves a itemIdentifier/itemIdentifierValue given a itemIdentifierTypeCode value
  def item_identifier_value identifier_parent, code
    identifier_parent.text("itemIdentifier[itemIdentifierTypeCode = '#{code}']/itemIdentifierValue")
  end

  # Retrieves a itemDescriptor/itemDescriptorValue given a itemDescriptorTypeCode value
  def item_descriptor_value descriptor_parent, code
    descriptor_parent.text("itemDescriptor[itemDescriptorTypeCode = '#{code}']/itemDescriptorValue")
  end

  # Retrieves an identification/value given a type code
  def identification_value parent, code
    parent.text "identification[type = '#{code}']/value"
  end

  # Prefixes the given value with the provided company's system code if the prefix_identifiers_with_system_codes
  # configuration option is set to true (default == true)
  def prefix_identifier_value company, value
    prefix_identifiers_with_system_codes? ? "#{company.system_code}-#{value}" : value
  end

  # Sets a custom value into the given object.  
  # obj - the object to update
  # value - the value to set
  # uid - either a CustomDefinition object or the setup cdef_uid value for the custom field
  # changed - if supplied, a MutableBoolean object that will be set to true if the value of the 
  # custom value was modified.
  # skip_nil_values - results in the mehtod being a no-op if the value is nil
  def set_custom_value obj, value, uid, changed: nil, skip_nil_values: false
    return if value.nil? && skip_nil_values

    cdef = uid.is_a?(Symbol) ? cdefs[uid] : uid

    cval = obj.custom_value(cdef)
    if cval != value
      obj.find_and_set_custom_value(cdef, value)
      changed.value = true if changed
    end

    nil
  end

  def set_importer_system_code xml
    @importer_system_code ||= importer_system_code(xml)
  end

  # The importer to utilize, value is cached on initial lookup.  Relies on the set_importer_system_code method being called
  # to find which importer account to lookup.  If no importer is found, raises an error.
  def importer
    @imp ||= begin
      inbound_file.error_and_raise("An importer system code must be set up.") if @importer_system_code.blank?
      imp = Company.where(system_code: @importer_system_code, importer: true).first
      inbound_file.error_and_raise("No importer found with system code '#{@importer_system_code}'.") if imp.nil?
      imp
    end
  
    @imp
  end

  def time_zone
    @tz ||= Time.zone
  end

  # Prep method for making custom definition data...to provide additional custom definition uids, implement
  # the method cdef_uids and return an array of cusotm definition setup uids to utilize.
  def cdefs
    @cdefs ||= begin
      defs = Set.new 
      if self.respond_to?(:generic_cdef_uids)
        self.generic_cdef_uids.each {|c| defs << c}
      end
      if self.respond_to?(:cdef_uids)
        self.cdef_uids.each {|c| defs << c}
      end

      self.class.prep_custom_definitions defs.to_a
    end

    @cdefs
  end

  def find_country iso_code
    @countries ||= Hash.new do |h, k|
      h[k] = Country.where(iso_code: k).first
    end

    @countries[iso_code]
  end

end; end; end; end