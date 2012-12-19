require 'rexml/document'
require 'open_chain/integration_client_parser'
module OpenChain
  module CustomHandler
    class KewillIsfXmlParser
      extend OpenChain::IntegrationClientParser
      SYSTEM_NAME = "Kewill"
      NO_NOTES_EVENTS = [10,19,20,21]
  
      def self.integration_folder
        "/opt/wftpserver/ftproot/www-vfitrack-net/_kewill_isf"
      end

      def self.parse data, opts={}
        self.new(REXML::Document.new data).parse_dom opts[:bucket], opts[:key]
      end

      def initialize dom
        @dom = dom
      end
      # process REXML document
      def parse_dom s3_bucket=nil, s3_key=nil
        @po_numbers = Set.new 
        @used_line_numbers = []
        @notes = []
        r = @dom.root
        host_system_file_number = et r, 'ISF_SEQ_NBR'
        raise "ISF_SEQ_NBR is required." if host_system_file_number.blank?
        @sf = SecurityFiling.find_by_host_system_and_host_system_file_number SYSTEM_NAME, host_system_file_number
        @sf = SecurityFiling.create!(:host_system=>SYSTEM_NAME,:host_system_file_number=>host_system_file_number) unless @sf
        SecurityFiling.transaction do
          new_last_event = last_event_time(r)
          if @sf.last_event && (new_last_event < @sf.last_event)
            return
          else
            @sf.last_event = new_last_event
          end
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
          process_bills_of_lading r
          process_container_numbers r
          process_broker_references r
          process_events r
          process_lines r
          @sf.po_numbers = @po_numbers.to_a.compact.join("\n")
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
          @sf.save!
        end
      end

      private 
      def process_lines parent
        parent.each_element('lines') do |el|
          line_number = et(el,'ISF_LINE_NBR')
          ln = @sf.security_filing_lines.find_by_line_number(line_number)
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
        root.each_element('events') do |el|
          next if et(el,'EVENT_NBR')=='10'
          time_stamp = ed el, 'EVENT_DATE'
          r = pick_date(r,time_stamp,true)
        end
        r
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
          when '10'
            @sf.estimated_vessel_load_date = time_stamp
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
        txt.blank? ? nil : Time.iso8601(txt) #DateTime.strptime(txt,DATE_FORMAT)
      end
    end
  end
end
