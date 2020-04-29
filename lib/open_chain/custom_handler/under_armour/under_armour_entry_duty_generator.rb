require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module UnderArmour; class UnderArmourEntryDutyGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport

  UnderArmourDutyData = Struct.new(:article, :hts_code, :duty, :currency, :exchange_rate, :prepack, :part_number)
  SYNC_CODE ||= "UA Duty"

  def self.run_schedulable opts={}
    raise "A start date must be set." if opts['start_date'].nil?
    self.new.generate_and_send(Time.zone.parse(opts['start_date']), opts['last_start_time'])
  end

  def generate_and_send start_date, end_date
    # UA wants this file sent as a batch operation nightly.  They also want the top level element
    # to be the PO Number.  Since it's possible we'll have the same PO number on mulitple entries
    # we need to first aggregate the data we're sending together and then build the xml document from that.
    xml, entries = generate_xml(start_date, end_date)
    send_xml(xml, entries)
    nil
  end

  def generate_xml start_date, end_date
    xml_data, entries = build_xml_data(ua_importer, start_date, end_date)
    xml = build_xml(xml_data) if entries.length > 0

    [xml, entries]
  end

  private

    def send_xml xml, entries
      sync_records = generate_sync_records(entries)
      # XML could technically be nil here, but we still want to mark the entries involved as being sent
      # This is due to the fact that we're skipping commercial invoices that don't have an invoice number
      # that starts with "ASN".  These are primarily truck shipments.  We still want to mark them as sent
      # so we don't continue to pull them back in the query, though.
      ActiveRecord::Base.transaction do
        if !xml.nil?
          timestamp = Time.zone.now.strftime("%Y%m%d%H%M%S%L")
          Tempfile.open(["LSPDUT_#{timestamp}", ".xml"]) do |file|
            Attachment.add_original_filename_method(file, "LSPDUT_#{timestamp}.xml")
            write_xml(xml, file)
            file.rewind
            ftp_sync_file file, sync_records, ftp_info
          end
        end

        now = Time.zone.now
        confirmed = now + 1.minute
        sync_records.each do |sr|
          sr.sent_at = now
          sr.confirmed_at = confirmed
          sr.save!
        end
      end

      nil
    end

    def ftp_info
      path = MasterSetup.get.production? ? "ua_duty" : "ua_duty_test"
      ftp = connect_vfitrack_net("to_ecs/#{path}")
    end

    def generate_sync_records entries
      sync_records = []
      entries.each do |e|
        sr = e.sync_records.find {|r| r.trading_partner == SYNC_CODE }
        sr = e.sync_records.build(trading_partner: SYNC_CODE) if sr.nil?

        sync_records << sr
      end

      sync_records
    end

    def build_xml xml_data
      doc, root = build_xml_document("UA_PODuty")
      asns_added = 0

      xml_data.each_pair do |po_number, po_data|
        # Don't add the Header / PONum until we know we'll actually
        # have ASN content to add to the document
        po_element = nil

        po_data.each_pair do |asn_number, asn_detail_data|
          next unless asn_number =~ /\AASN/i

          if po_element.nil?
            po_element = add_element(root, "Header")
            add_element(po_element, "PONum", po_number)
          end

          asns_added += 1
          asn_element = add_element(po_element, "Details")
          add_element(asn_element, "BrokerRefNum", asn_number)
          add_element(asn_element, "BrokerRefNumType", "ASN")

          asn_detail_data.each_value do |duty_data|
            item_element = add_element(asn_element, "ItemInfo")

            add_element(item_element, "Article", duty_data.article)
            add_element(item_element, "HTSCode", duty_data.hts_code)
            add_element(item_element, "Duty", duty_data.duty)
            add_element(item_element, "Currency", duty_data.currency)
            add_element(item_element, "ExchRate", duty_data.exchange_rate)

            next unless duty_data.prepack
            customer_field_element = add_element(item_element, "CustomerField")
            customer_field_value_element = add_element(customer_field_element, "CustomerFieldValue", duty_data.part_number)
            customer_field_value_element.add_attribute("CustomerFieldName", "PREPACK")
          end
        end
      end

      # If we didn't add any asns, then don't return a virtually blank XML document, just return nil
      asns_added > 0 ? doc : nil
    end

    def build_xml_data importer, start_date, end_date
      po_data = Hash.new do |h, k|
        # The internal "asn_data" is simply a hash of UnderArmourDutyData structs, keyed on a 2-value array
        # containing article and HTS code.  The goal is to wind up with one data element for each unique
        # article/HTS combination associated with this PO / ASN combination, with data from multiple
        # lines/tariffs sharing article/HTS rolled up together.
        h[k] = Hash.new do |hash, key|
          hash[key] = {}
        end
      end

      entries = Set.new

      find_entries(importer, start_date, end_date) do |entry|
        preload_entry(entry)

        entry.commercial_invoices.each do |inv|
          next if inv.invoice_number.blank?

          inv.commercial_invoice_lines.each do |line|
            next if line.po_number.blank?

            # If we found an ASN / PO...then record the entry that was found..because we'll have to give it a sync record when the XML is finally built.
            entries << entry

            asn_data = po_data[line.po_number]

            product = Product.where(unique_identifier: "UAPARTS-#{line.part_number}").first

            # Roll up lines with the same PO, article and HTS code.  Duty is the only value that would change
            # between lines.  It needs to be summed in the rolled up duty_data object.
            line.commercial_invoice_tariffs.each do |tariff|
              key = [line.part_number, tariff.hts_code]
              duty_data = asn_data[inv.invoice_number][key]
              if duty_data.nil?
                duty_data = UnderArmourDutyData.new
                duty_data.article = line.part_number
                duty_data.hts_code = tariff.hts_code
                # The duty is ALWAYS Canadian dollars..
                duty_data.currency = "CAD"
                duty_data.exchange_rate = inv.exchange_rate
                duty_data.prepack = product&.custom_value(cdefs[:prod_prepack])
                duty_data.part_number = product&.custom_value(cdefs[:prod_part_number])
                asn_data[inv.invoice_number][key] = duty_data
              end
              duty_data.duty = (duty_data.duty || BigDecimal(0)) + tariff.duty_amount
            end
          end
        end
      end

      [po_data, entries]
    end

    def find_entries importer, start_date, end_date
      Entry.joins(Entry.join_clause_for_need_sync("UA DUTY")).
        where(Entry.has_never_been_synced_where_clause).
        where(importer: importer).
        where("cadex_accept_date >= ? AND cadex_accept_date < ?", start_date, end_date).find_each do |entry|
          yield entry
        end
    end

    def ua_importer
      @ua ||= Company.with_fenix_number("874548506RM0001").first
      raise "Failed to locate Under Armour Canadian importer account." if @ua.nil?
      @ua
    end

    def preload_entry entry
      ActiveRecord::Associations::Preloader.new.preload(entry, [{commercial_invoices: {commercial_invoice_lines: :commercial_invoice_tariffs}}, :sync_records])
    end

    def cdefs
      @cd ||= self.class.prep_custom_definitions([:prod_prepack, :prod_part_number])
    end

end; end; end; end;