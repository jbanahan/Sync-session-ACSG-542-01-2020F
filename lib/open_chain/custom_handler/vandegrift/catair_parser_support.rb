require 'open_chain/custom_handler/fixed_position_parser_support'

module OpenChain; module CustomHandler; module Vandegrift; module CatairParserSupport
  extend ActiveSupport::Concern
  include OpenChain::CustomHandler::FixedPositionParserSupport

  module ClassMethods
    # GPG params for decrypting catair files (if required)
    def gpg_secrets_key opts
      'open_chain'
    end
  end

  def send_email_notification shipments, catair_type
    notifications = {}

    shipments.each do |s|
      cust_no = s.customer
      next if cust_no.blank?

      if notifications[cust_no].nil?
        company = Company.with_customs_management_number(cust_no).first
        notifications[cust_no] = {company: company, entry_numbers: Set.new }
      end

      notifications[cust_no][:entry_numbers] << "#{s.entry_filer_code}-#{s.entry_number.to_s[0..-2]}-#{s.entry_number.to_s[-1]}"
    end

    notifications.each_pair do |cust_no, obj|
      mailing_list = MailingList.where(company: obj[:company], system_code: "#{cust_no} #{catair_type} EDI").first
      next unless mailing_list

      message = "EDI data was generated and sent to Customs Management for #{"Entry Number".pluralize(obj[:entry_numbers].length)}: #{obj[:entry_numbers].to_a.join(', ')}."
      OpenMailer.send_simple_html(mailing_list, "#{cust_no} #{catair_type} EDI File Receipt", message).deliver_now
    end
    nil
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

  def date_format
    "%m%d%y"
  end

end; end; end; end