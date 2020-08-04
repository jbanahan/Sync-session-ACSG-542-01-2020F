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

  def find_customer_number ior_type, ior_identifier, log_customer_to_inbound_file: false
    # At this point, EIN is the only value we support for looking up the account to utilize.
    # This is largely just because we don't have any of the other identifier types stored with the Company data
    # EIN Number SHOULD be what we get in the overwhelming majority of files anyway, as the other all our
    # importers are operating as a business entity and thus the EIN numbers is the appropriate entity
    # to identify that entity with CBP.
    inbound_file.reject_and_raise("Importer Record Types of '#{ior_type}' are not supported at this time.") unless ior_type == "EI"

    @customers ||= begin
      cache = Hash.new do |h, k|
        customer = nil
        Company.importers.where(irs_number: k).each do |c|
          if c.kewill_customer_number.present?
            customer = c
            break
          end
        end
        h[k] = customer
      end
      cache
    end

    customer_number = nil
    if ior_identifier.present?
      customer = @customers[ior_identifier]
      inbound_file.company = customer if log_customer_to_inbound_file
      customer_number = customer&.kewill_customer_number
    end
    inbound_file.reject_and_raise("Failed to find any importer account associated with EIN # '#{ior_identifier}' that has a CMUS Customer Number.") if customer_number.nil?

    customer_number
  end

  # We're expecting the shipment to have entry filer code and entry_number fields present
  def compose_full_entry_number shipment
    entry_number = shipment.entry_number.to_s
    [shipment.entry_filer_code, entry_number[0..-2].rjust(7, "0"), entry_number[-1]]
  end

  def populate_edi_identifiers shipment, document_type
    # For these CATAIR 3461/7501 files that won't have Master Bills or House Bills, we need to put something into the XML
    # that will go into the MBOL/HBOL fields (as that's the primary key for the EDI_SHIPMENT_HEADER table)
    # We'll just use the full entry number for that (which we also use as the invoice # created)

    # This is kinda weird, but it's because the module can't directly reference the CI Load structs that are
    # inherited by the including class...so we reference them via the class directly
    id = self.class::CiLoadEdiIdentifier.new
    # We need to remove the hyphens from the entry number otherwise the length is longer than the XML
    # allows for the master bill
    id.master_bill = compose_full_entry_number(shipment).join("")

    # Only do this suffix adding if we're dealing w/ an FTZ shipment.
    # This is because we get the same # for 2 sets of data we may need to load.
    # The masterbill will be on the zone estimate (3461) and then the following week for
    # the actual zone movement (7501).  So we need a way to distinguish between the two,
    # otherwise CM won't accept the 7501 data because the same master bill was already loaded
    # on a shipment when the 3461 was utilized.
    if shipment.entry_type == "06"
      if document_type == "3461"
        id.master_bill += "P"
      elsif document_type == "7501"
        id.master_bill += "F"
      end
    end

    shipment.edi_identifier = id
    # The file number is the value from the entry number between the hyphens (stripping all leading zeros)
    shipment.file_number = compose_full_entry_number(shipment)[1].to_s.gsub(/\A0+/, "")
    nil
  end

  def date_format
    "%m%d%y"
  end

  def strip_entry_number shipment
    # Rip out the filer code and entry number from the shipment
    # These values tend to cause problems on the EDI loads if they're pulled onto
    # an open shipment...which is how we do things, rather than create the shipment
    # from scratch directly from the EDI.  When you pull onto an open shipment from EDI
    # and there's file number / entry numbers listed then it's possible those will overwrite
    # the entry number already on the shipment, which then causes all sorts of problems.
    # We also use predefined entry numbers
    # so we don't generally even want to use the file numbers from the catair files.
    shipment.entry_filer_code = nil
    shipment.entry_number = nil
    shipment.file_number = nil
    nil
  end

end; end; end; end