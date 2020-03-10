module OpenChain; module CustomHandler; module Vandegrift; module CatairParserSupport
  extend ActiveSupport::Concern

  module ClassMethods
    # GPG params for decrypting catair files (if required)
    def gpg_secrets_key opts
      'open_chain'
    end
  end

  def record_type line
    first_char = extract_string(line, 1)
    return first_char if ["A", "B", "Y", "Z"].include?(first_char)

    # While the 3461 has all segments that start like SE\d\d...the 7501 segments are all 2 digits (
    # and can technically also have SE\d\d mixed in too).  So, I'm going to assume that if the 
    # line starts with 2 digits, then the segment is identified just by the 2 digits, otherwise
    # it's identified by a 2 character + 2 digit identifier

    # This logic is tested for Catair Cargo Release and Entry Summary docs, but not other
    # catair types.
    first_four = extract_string(line, (1..4))
    first_four =~ /^\d\d/ ? first_four[0..1] : first_four
  end

  # The idea here is to be able to utilize the actual record input positions
  # from the actual Catair spec (which are not zero indexed positions).
  # Thus making it a little easier to key the positions we're going to be using.
  def extract_string line, catair_range, trim_whitespace: true
    start_pos = nil
    end_pos = nil
    if catair_range.is_a?(Range)
      start_pos = catair_range.begin - 1
      end_pos = catair_range.end - 1
    elsif catair_range.is_a?(Numeric)
      start_pos = catair_range.to_i - 1
      end_pos = catair_range.to_i - 1
    else
      raise "Invalid line position given #{catair_range}."
    end

    v = line[start_pos..end_pos].to_s
    trim_whitespace ? v.strip : v
  end

  def extract_integer line, catair_range
    v = extract_string(line, catair_range)
    return nil if v.blank?
    # For some fields, there's going to be leading zeros in the numeric value...this causes the Integer 
    # initializer to interpret the value as Octal, thus giving a completely unexpected number.
    # In order words, we need to strip leading zeros from the value
    while (v.starts_with?("0"))
      v = v[1..-1]
    end

    Integer(v) rescue nil
  end

  def extract_decimal line, catair_range, decimal_places: 2
    # This seems a little weird, but all the actual data we'll 
    # get in the Catair will have implied decimal places, so we
    # can parse the value as an integer (getting the benefit of 
    # the leading zero stripping) and then inject the 
    # decimal place in after the fact
    int = extract_integer(line, catair_range).to_s
    return nil if int.blank?

    # Inject the decimal back in
    if decimal_places > 0
      # add leading zeros back on until the length of the string is more than the decimal places
      while(int.length < decimal_places)
        int = "0" + int
      end

      int = int[0..(int.length - (decimal_places + 1))] + "." + int[(int.length - decimal_places)..-1]
    end

    BigDecimal(int)
  end

  def extract_date line, catair_range, date_format: "%m%d%y"
    v = extract_string(line, catair_range)
    return nil if v.blank?
    Date.strptime(v, date_format) rescue nil
  end

  def extract_boolean line, catair_range
    v = extract_string(line, catair_range)
    return nil if v.blank?

    v == "Y"
  end

  def find_customer_number ior_type, ior_identifier
    # At this point, EIN is the only value we support for looking up the account to utilize.
    # This is largely just because we don't have any of the other identifier types stored with the Company data
    # EIN Number SHOULD be what we get in the overwhelming majority of files anyway, as the other all our
    # importers are operating as a business entity and thus the EIN numbers is the appropriate entity
    # to identify that entity with CBP.
    inbound_file.reject_and_raise("Importer Record Types of '#{ior_type}' are not supported at this time.") unless ior_type == "EI"

    @customer_numbers ||= begin
      cache = Hash.new do |h, k|
        cust_no = nil
        Company.importers.where(irs_number: k).each do |c|
          cust_no = c.kewill_customer_number
          break if cust_no.present?        
        end
        h[k] = cust_no
      end
      cache
    end

    customer_number = nil
    if ior_identifier.present?
      customer_number = @customer_numbers[ior_identifier]
    end
    inbound_file.reject_and_raise("Failed to find any importer account associated with EIN # '#{ior_identifier}' that has a CMUS Customer Number.") if customer_number.nil?

    customer_number
  end

  # We're expecting the shipment to have entry filer code and entry_number fields present
  def compose_full_entry_number shipment
    entry_number = shipment.entry_number.to_s
    [shipment.entry_filer_code, entry_number[0..-2].rjust(7, "0"), entry_number[-1]]
  end

  def populate_edi_identifiers shipment
    # For these CATAIR 3461/7501 files that won't have Master Bills or House Bills, we need to put something into the XML
    # that will go into the MBOL/HBOL fields (as that's the primary key for the EDI_SHIPMENT_HEADER table)
    # We'll just use the full entry number for that (which we also use as the invoice # created)

    # This is kinda weird, but it's because the module can't directly reference the CI Load structs that are 
    # inherited by the including class...so we reference them via the class directly
    id = self.class::CiLoadEdiIdentifier.new
    # We need to remove the hyphens from the entry number otherwise the length is longer than the XML 
    # allows for the master bill
    id.master_bill = compose_full_entry_number(shipment).join("")
    shipment.edi_identifier = id
    # The file number is the value from the entry number between the hyphens (stripping all leading zeros)
    shipment.file_number = compose_full_entry_number(shipment)[1].to_s.gsub(/\A0+/, "")
    nil
  end

end; end; end; end