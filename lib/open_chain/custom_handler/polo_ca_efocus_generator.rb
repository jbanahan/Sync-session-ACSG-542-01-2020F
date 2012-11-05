require 'rexml/document'
require 'open_chain/custom_handler/polo_ca_entry_parser'
module OpenChain
  module CustomHandler
    #write XML files to go to e-Focus (at OHL) for supply chain tracking
    class PoloCaEfocusGenerator

      # key is fenix code, value is ohl code
      TRANSPORT_MODE_MAP = {'1'=>'A','2'=>'L','3'=>'M','6'=>'R','7'=>'F','9'=>'O'}
      PORT_MAP = {'9'=>'CAHAL','351'=>'CALCO','395'=>'CAMTR','396'=>'CADOR','399'=>'CAYMX','427'=>'CANIA',
        '440'=>'CASNI','453'=>'CAWND','480'=>'CABRP','485'=>'CAYOW','495'=>'CATOR',
        '496'=>'CATOR','497'=>'CAYYZ','809'=>'CAVAN','821'=>'CAYVR'}
      SYNC_CODE = 'polo_ca_efocus'
      
      #This is the master method that does all of the work
      def generate
        ftp_xml_files sync_xml
      end

      def sync_xml
        files = []
        entries = Entry.
          where("importer_tax_id IN (?)",OpenChain::CustomHandler::PoloCaEntryParser::POLO_IMPORTER_TAX_IDS).
          where("length(master_bills_of_lading) > 0").
          where("length(house_bills_of_lading) > 0 OR length(container_numbers) > 0").
          need_sync(SYNC_CODE).uniq
        entries.each do |ent|
          t = Tempfile.new(["PoloCaEfocus",".xml"])  
          if !ent.entry_port_code.blank? && !PORT_MAP.keys.include?(ent.entry_port_code.strip)
            body = <<endbody
Port code #{ent.entry_port_code.strip} is not set in the Ralph Lauren e-Focus XML Generator.

If this port is invalid, please correct it in Fenix.  If it is valid, please email this message to edisupport@vandegriftinc.com and we'll add it to the program.

The program currently has the following Port Code - UN/LOCODE mappings:

endbody
            PORT_MAP.each do |k,v|
              body << "#{k} - #{v}\n"
            end
            OpenMailer.send_simple_text('ralphlauren-ca@vandegriftinc.com','INVALID RALPH LAUREN CA PORT CODE',body).deliver!
          else
            generate_xml_file ent, t
            files << t
          end
          sr = ent.sync_records.find_by_trading_partner(SYNC_CODE)
          sr = ent.sync_records.build(:trading_partner=>SYNC_CODE) unless sr
          sr.update_attributes(:sent_at=>2.seconds.ago,:confirmed_at=>1.second.ago,:confirmation_file_name=>'n/a')
        end
        files
      end

      def generate_xml_file entry, output_file
        doc = REXML::Document.new("<?xml version=\"1.0\" encoding=\"UTF-8\"?><entry-transmission></entry-transmission>")
        et = doc.root
        ent = et.add_element 'entry'
        add_element ent, 'entry-number', entry.entry_number
        add_element ent, 'broker-reference', entry.broker_reference
        add_element ent, 'broker-importer-id', 'RALPLA'
        add_element ent, 'broker-id', 'VFI'
        add_element ent, 'import-date', entry.arrival_date
        add_element ent, 'documents-received-date', entry.docs_received_date
        add_element ent, 'in-customs-date', entry.across_sent_date
        add_element ent, 'out-customs-date', entry.release_date
        add_element ent, 'available-to-carrier-date', entry.release_date
        add_element ent, 'vessel-name', entry.vessel
        add_element ent, 'voyage', entry.voyage
        add_element ent, 'country-destination', 'CA'
        add_element ent, 'total-duty', entry.total_duty
        add_element ent, 'total-tax', entry.total_gst
        add_element ent, 'total-invoice-value', entry.total_invoiced_value
        add_country_origin ent, entry
        add_country_export ent, entry
        add_unlading_port ent, entry.entry_port_code
        add_element ent, 'mode-of-transportation', TRANSPORT_MODE_MAP[entry.transport_mode_code]
        unless entry.container_numbers.blank?
          entry.container_numbers.split(' ').each do |cn|
            add_element ent, 'container', cn
          end
        end
        unless entry.master_bills_of_lading.blank?
          entry.master_bills_of_lading.split(' ').each do |mb|
            el = ent.add_element('master-bill')
            el.add_element('number').text = mb
            add_house_bills el, entry.house_bills_of_lading
          end
        end
        output_file << doc.to_s
        output_file.flush
        output_file
      end

      def ftp_xml_files file_array
        environ = Rails.env=='production' ? 'prod' : 'dev'
        file_array.each do |f|
          sleep 1 #force unique file names
          FtpSender.send_file('ftp2.vandegriftinc.com','VFITRack','RL2VFftp',f,{:folder=>"to_ecs/Ralph_Lauren/efocus_ca_#{environ}",:remote_file_name=>remote_file_name})
        end
      end
      def remote_file_name
        "VFITRACK#{Time.now.strftime("%Y%m%d%H%M%S")}.xml" 
      end

      private
      def add_element parent, name, content
        return nil if content.blank?
        c = content.respond_to?(:strftime) ? content.strftime("%Y%m%d") : content.to_s
        r = parent.add_element(name)
        r.text = c 
        r
      end
      def add_country_origin parent, entry
        return nil if entry.origin_country_codes.blank?
        coo = entry.origin_country_codes.split(' ')
        add_element parent, 'country-origin', (coo.size>1 ? 'VAR' : coo.first)
      end
      def add_country_export parent, entry
        return nil if entry.export_country_codes.blank?
        coo = entry.export_country_codes.split(' ')
        add_element parent, 'country-export', coo.first
      end
      def add_unlading_port parent, fenix_port_code
        return nil if fenix_port_code.blank?
        r = PORT_MAP[fenix_port_code].blank? ? 'ZZZZZ' : PORT_MAP[fenix_port_code]
        add_element parent, 'port-unlading', r
      end
      def add_house_bills parent, hbol_numbers
        #since we don't have the right structure on the inbound, writing all house
        #bills under each master bill
        unless hbol_numbers.blank?
          hbol_numbers.split(' ').each do |hb|
            h = hb.size > 16 ? hb[0,16] : hb
            add_element parent, 'house-bill', h
          end
        end
      end
    end
  end
end
