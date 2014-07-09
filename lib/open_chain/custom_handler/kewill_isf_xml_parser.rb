require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'set'

module OpenChain
  module CustomHandler
    class KewillIsfXmlParser
      extend OpenChain::IntegrationClientParser

      SYSTEM_NAME = "Kewill"
      NO_NOTES_EVENTS = [10,19,20,21]
      STATUS_XREF ||= {"ACCNOMATCH" => "Accepted No Bill Match", "DEL_ACCEPT" => "Delete Accepted", "ACCMATCH" => "Accepted And Matched",
                        "REPLACE" => "Replaced", "ACCEPTED" => "Accepted", "ACCWARNING" => "Accepted With Warnings", "DELETED" => "Deleted"}
  
      def self.integration_folder
        ["//opt/wftpserver/ftproot/www-vfitrack-net/_kewill_isf", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_kewill_isf"]
      end

      def self.parse data, opts={}
        self.new.process_file data, opts[:bucket], opts[:key]
      end

      # process REXML document
      def process_file data, s3_bucket=nil, s3_key=nil
        dom = REXML::Document.new data
        r = dom.root
        host_system_file_number = et r, 'ISF_SEQ_NBR'
        raise "ISF_SEQ_NBR is required." if host_system_file_number.blank?
        # Raises an error if there is no last event time (except for docs w/ only event types of 8 - these are advisory docs we can skip)
        last_event_time = last_event_time(r)

        return unless last_event_time

        # sf may be nil here if we're skipping this file (if data is out of date, for example)
        sf = find_security_filing SYSTEM_NAME, host_system_file_number, last_event_time
        
        if sf
          Lock.with_lock_retry(sf) do
            # Since the data is reloaded from the db by the lock call, make sure we're
            # still not dealing w/ outdated event time data
            if parse_file? sf, last_event_time
              start_time = Time.now

              sf = parse_dom dom, sf, s3_bucket, s3_key

              sf.save!
              sf.update_column(:time_to_process, ((Time.now - start_time) * 1000).to_i)
            end
          end
        end
      end

      def parse_dom dom, sf, s3_bucket = nil, s3_key = nil
        @po_numbers = Set.new 
        @countries_of_origin = Set.new
        @used_line_numbers = []
        @notes = []
        @dom = dom
        @sf = sf
        r = @dom.root
        
        tx_num = et r, 'ISF_TX_NBR'
        @sf.last_file_bucket = s3_bucket
        @sf.last_file_path = s3_key
        @sf.transaction_number = tx_num.gsub('-','') unless tx_num.nil?
        @sf.importer_account_code = et r, 'IMPORTER_ACCT_CD'
        @sf.broker_customer_number = et r, 'IMPORTER_BROKERAGE_ACCT_CD'
        @sf.importer_tax_id = et r, 'IRS_NBR'
        @sf.transport_mode_code = et r, 'MOT_CD'
        @sf.scac = et r, 'SCAC_CD'
        @sf.booking_number = et r, 'BOOKING_NBR'
        @sf.vessel = et r, 'VESSEL_NAME'
        @sf.voyage = et r, 'VOYAGE_NBR'
        @sf.lading_port_code = et r, 'PORT_LADING_CD'
        @sf.unlading_port_code = et r, 'PORT_UNLADING_CD'
        @sf.entry_port_code = et r, 'PORT_ENTRY_CD'
        @sf.status_code = et r, 'STATUS_CD'
        @sf.late_filing = (et(r,'IS_SUBMIT_LATE')=='Y')
        @sf.status_description = STATUS_XREF[@sf.status_code]
        process_bills_of_lading r
        process_container_numbers r
        process_broker_references r
        process_events r
        process_lines r
        @sf.manufacturer_names = process_manufacturer_names r
        @sf.po_numbers = @po_numbers.to_a.compact.join("\n")
        @sf.countries_of_origin = @countries_of_origin.to_a.compact.join("\n")
        @sf.security_filing_lines.each do |ln|
          ln.destroy unless @used_line_numbers.include?(ln.line_number)
        end
        @sf.notes = @notes.join("\n")
        if @sf.broker_customer_number
          importer = Company.find_by_alliance_customer_number @sf.broker_customer_number
          if importer.nil?
            cn = @sf.broker_customer_number
            importer = Company.create!(:name=>cn,:alliance_customer_number=>cn,:importer=>true)
          end
          @sf.importer = importer
        end

        @sf
      end

      private 
      def process_lines parent
        parent.each_element('lines') do |el|
          line_number = et(el,'ISF_LINE_NBR').to_i
          ln = @sf.security_filing_lines.find {|ln| ln.line_number == line_number}
          ln = @sf.security_filing_lines.build(:line_number=>line_number) unless ln
          @used_line_numbers << ln.line_number

          ln.po_number = et(el, 'PO_NBR')
          @po_numbers << ln.po_number
          ln.part_number = et(el, 'PART_CD')
          ln.quantity = 0
          ln.hts_code = et(el, 'TARIFF_NBR')
          ln.commercial_invoice_number = et(el, 'CI_NBR')
          ln.mid = et(el,'MID')
          ln.country_of_origin_code = et(el, 'COUNTRY_ORIGIN_CD')
          @countries_of_origin << ln.country_of_origin_code

          unless ln.mid.nil? || ln.mid.strip.length == 0
            name = REXML::XPath.first(parent, "entities[MID=$mid]/PARTY_NAME", nil, {"mid" => ln.mid})
            ln.manufacturer_name = name.text unless name.nil?
          end 
        end
      end
      def process_bills_of_lading parent
        hbols = []
        parent.each_element('bols') do |el|
          @sf.master_bill_of_lading = "#{et el, 'MASTER_SCAC_CD'}#{et el, 'MASTER_BILL_NBR'}"
          hbols << "#{et el, 'HOUSE_SCAC_CD'}#{et el, 'HOUSE_BILL_NBR'}"
        end
        @sf.house_bills_of_lading = hbols.join("\n")
      end
      def process_container_numbers parent
        containers = []
        parent.each_element('containers') do |el|
          containers << "#{et el, 'CONTAINER_NBR'}"
        end
        @sf.container_numbers = containers.join("\n")
      end
      def process_broker_references parent
        entry_nums = []
        file_nums = []
        parent.each_element('brokerrefs') do |el|
          entry_nums << "#{et el, 'BROKER_FILER_CD'}#{et el, 'ENTRY_NBR'}"
          file_nums << "#{et el, 'BROKER_REF_NO'}"
        end
        @sf.entry_numbers = entry_nums.join("\n")
        @sf.entry_reference_numbers = file_nums.join("\n")
      end
      def last_event_time root
        r = nil
        REXML::XPath.each(root, "events[EVENT_NBR = '21']") do |el|
          time_stamp = ed el, 'EVENT_DATE'
          r = pick_date(r,time_stamp,true)
        end

        if r.nil?
          # Don't raise anything if we have a document that only has event types of 8, we'll just skip these
          event_numbers = []
          REXML::XPath.each(root, "events/EVENT_NBR") {|el| event_numbers << el.text}
          event_numbers = event_numbers.uniq.compact

          raise "At least one 'events' element with an 'EVENT_DATE' child and EVENT_NBR 21 must be present in the XML." unless event_numbers.length == 1 && event_numbers[0] == "8"  
        end
        
        r
      end

      def process_manufacturer_names root
        s = Set.new REXML::XPath.each(root, "entities[PARTY_TYPE_CD = 'MF']/PARTY_NAME").map {|el| el.text.strip}
        return s.to_a.join(" \n")
      end

      def process_events parent
        first_sent_date = nil
        last_sent_date = nil
        first_accepted_date = nil
        last_accepted_date = nil
        parent.each_element('events') do |el|
          number = et el, 'EVENT_NBR'
          time_stamp = ed el, 'EVENT_DATE'
          case number
          when '1'
            @sf.file_logged_date = time_stamp
          when '3'
            first_sent_date = pick_date(first_sent_date,time_stamp,false)
            last_sent_date = pick_date(last_sent_date,time_stamp,true)
          when '4'
            first_accepted_date = pick_date(first_accepted_date,time_stamp,false)
            last_accepted_date = pick_date(last_accepted_date,time_stamp,true)
          when '8'
            # Events 8-12 we want to capture the last event element listed in the file based on the element ordering of the file, not necessarily
            # by the actual event time.
            @sf.cbp_updated_at = time_stamp
          when '10'
            @sf.estimated_vessel_load_date = time_stamp
          when '11'
            @sf.estimated_vessel_sailing_date = time_stamp
          when '12'
            @sf.estimated_vessel_arrival_date = time_stamp
          end
          unless NO_NOTES_EVENTS.include?(number.to_i)
            notes = get_notes_from_event(el,time_stamp)
            @notes += notes unless notes.empty? 
          end
        end
        @sf.first_sent_date = first_sent_date
        @sf.last_sent_date = last_sent_date
        @sf.first_accepted_date = first_accepted_date
        @sf.last_accepted_date = last_accepted_date
      end
      
      def get_notes_from_event evt, time_stamp
        notes = []
        evt.each_element("notes") do |nt|
          s = et(nt,'NOTE')
          notes << "#{est_time_str time_stamp}: #{s.strip}" unless s.blank?
        end
        if notes.empty?
          notes << "#{est_time_str time_stamp}: #{et evt, 'EVENT_DESCR'}"
        end
        notes
      end
      def est_time_str t
        ActiveSupport::TimeZone["Eastern Time (US & Canada)"].at(t.to_i).strftime("%Y-%m-%d %H:%M %Z")
      end
      def pick_date original, to_try, greater_than
        return to_try if original.nil?
        return original if to_try.nil?
        if greater_than
          return to_try if to_try > original
        else
          return to_try if to_try < original
        end
        original
      end

      #get element text 
      def et parent, element_name
        parent.text(element_name)
      end
      #get date from element
      def ed parent, element_name
        txt = et parent, element_name
        txt.blank? ? nil : Time.iso8601(txt)
      end

      def find_security_filing host_system, host_system_file_number, last_event_time
        # Use a DB lock so only a single ISF parser process is looking up security filings at a time
        # This way we can guarantee that we don't get duplicate records created and ensure the last event time
        # is set right away in an atomic manner as well.
        sf = nil
        Lock.acquire(Lock::ISF_PARSER_LOCK, times: 3) do
          local_sf = SecurityFiling.where(:host_system=>SYSTEM_NAME, :host_system_file_number=>host_system_file_number).first_or_create! :last_event => last_event_time

          if parse_file? local_sf, last_event_time

            # We only need to update the last event time if it's not equal (will be equal if we just created this isf record)
            if local_sf.last_event != last_event_time
              local_sf.update_column :last_event, last_event_time
            end

            sf = local_sf
          end
        end

        sf        
      end

      def parse_file? sf, last_event_time
        sf.last_event.nil? || sf.last_event <= last_event_time
      end
    end
  end
end
