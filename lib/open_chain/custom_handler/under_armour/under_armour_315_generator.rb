require 'rexml/document'
require 'set'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module UnderArmour
  class UnderArmour315Generator
    include OpenChain::FtpFileSupport

    UNDER_ARMOUR_TAX_ID ||= "874548506RM0001"

    def accepts? event, entry
      return entry.importer_tax_id == UNDER_ARMOUR_TAX_ID && entry.commercial_invoice_lines.length > 0
    end

    def receive event, entry
      # Extract all the unique invoice line level customer reference values, we will have to send individual XML files for each of these
      # that have not already been sent before.

      ids = extract_underarmour_shipment_identifiers entry
      dates = extract_underarmour_315_dates entry

      dates.each do |event_code, date|
        ids.each do |shipment_identifier|
          milestone = DataCrossReference.find_ua_315_milestone shipment_identifier, event_code
          date_string = xml_date_value(date)
          if milestone.nil? || milestone != date_string
            DataCrossReference.transaction do 
              DataCrossReference.add_xref! DataCrossReference::UA_315_MILESTONE_EVENT,  DataCrossReference.make_compound_key(shipment_identifier, event_code), date_string
              self.delay.generate_and_send event_code: event_code, shipment_identifier: shipment_identifier, date: date
            end
          end
        end
      end
      
      entry
    end

    def generate_and_send data
     generate_file(data) {|f| ftp_file f, {keep_local:true}}     
    end

    # Generates data to a tempfile, yielding the file to any
    # given block.  Returns the closed tempfile.  
    # (you can read from the closed file via IO.read(f.path) if you need the data).
    def generate_file data
      # Create a hash of the data values to send as the unique event id
      data_hash = Digest::SHA1.hexdigest(data.values.join)

      # We need to look up the UA shipment that links to the shipment_identifier (UA's ASN#)...then pull in the booking number (UA's IBD #)
      shipment = Shipment.where(reference: "UNDAR-#{data[:shipment_identifier]}").first
      ibd_number = shipment.try(:booking_number)

      # We could use REXML, but this is just easier to read and understand.  Plus, the only
      # possible value that might need escape handling is the shipment identifier, and it's super easy to just do that inline.
      xml = <<XML
<?xml version="1.0" encoding="UTF-8"?>
<tXML>
  <Message>
    <MANH_TPM_Shipment_IBD DocSource="Vande" DocSourceType="2" Timestamp="#{xml_date_value(Time.zone.now)}" Version="8.1.0" Id=#{data[:shipment_identifier].encode(:xml=>:attr)}>
      <Shipment Id="#{data[:shipment_identifier]}">
        <IBDNumber>#{ibd_number}</IBDNumber>
        <Event Id="#{data_hash}" Code="#{data[:event_code]}" DateTime="#{xml_date_value(data[:date])}" Action="1">
          <EventLocation InternalId="VFICA" />
        </Event>
      </Shipment>
    </MANH_TPM_Shipment_IBD>
  </Message>
</tXML>
XML

      Tempfile.open(["Vandegrift_Event_#{Attachment.get_sanitized_filename(data[:shipment_identifier])}", ".xml"]) do |f|
        f.binmode
        f << xml
        f.flush

        filename = Attachment.get_sanitized_filename "LSPEVT_#{data[:shipment_identifier]}_#{data[:event_code]}_#{Time.zone.now.strftime "%Y%m%d%H%M%S%L"}.xml"
        Attachment.add_original_filename_method f, filename

        yield(f) if block_given?
        f
      end
    end

    def ftp_credentials
      folder = MasterSetup.get.custom_feature?("Production") ? "to_ua/events" : "to_ua/events/test"

      {server: 'connect.vfitrack.net', username: 'underarmour', password: 'xkcoeit', folder: folder}
    end

    private 

      def extract_underarmour_shipment_identifiers entry
        shipment_id = Set.new 
        entry.commercial_invoices.each do |inv|
          inv.commercial_invoice_lines.each do |line|
            next if line.customer_reference.blank?

            id = line.customer_reference.strip
            shipment_id << ((id =~ /\A([^-]+)-.+\z/) ? $1 : id)
          end
        end
        
        shipment_id
      end

      def extract_underarmour_315_dates entry
        dates = {}
        dates['2315'] = entry.cadex_sent_date if entry.cadex_sent_date
        dates['2326'] = entry.release_date if entry.release_date
        dates['2902'] = entry.first_do_issued_date if entry.first_do_issued_date

        dates
      end

      def xml_date_value date
        # UA wants the dates sent in GMT sans timezone indicator, so we shall obligue
        # Technically, this is ISO8601 format, but there's no way in rails, short of substringing the 
        # iso8601 date method's string value of making a date like this.
        date.in_time_zone("GMT").strftime("%Y-%m-%dT%H:%M:%S")
      end

  end
end; end; end;