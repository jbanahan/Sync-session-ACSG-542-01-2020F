require 'rexml/document'
require 'digest/sha1'

module OpenChain
  module CustomHandler

    class PortMissingError < ::RuntimeError
      attr_accessor :port_code
    end
    # write XML files to go to e-Focus (at OHL) for supply chain tracking
    class PoloCaEfocusGenerator
      include OpenChain::XmlBuilder
      include OpenChain::FtpFileSupport

      # key is fenix code, value is ohl code
      TRANSPORT_MODE_MAP ||= {'1'=>'A', '2'=>'L', '3'=>'M', '6'=>'R', '7'=>'F', '9'=>'O'}
      SYNC_CODE ||= 'polo_ca_efocus'
      POLO_IMPORTER_TAX_IDS ||= ['806167003RM0001', '871349163RM0001', '866806458RM0001']

      def self.run_schedulable
        self.new.generate
      end

      # This is the master method that does all of the work
      def generate
        sync_xml do |t, sync|
          ftp_sync_file t, sync
          # Save the sync record now that it has an ftp session
          sync.save!
        end
      end

      def sync_xml
        files = []
        entries = Entry.
          where("importer_tax_id IN (?)", POLO_IMPORTER_TAX_IDS).
          where("length(master_bills_of_lading) > 0").
          where("length(house_bills_of_lading) > 0 OR length(container_numbers) > 0").
          need_sync(SYNC_CODE).uniq
        entries.each do |ent|
          sr = nil
          fingerprint = nil
          begin
            sr = ent.sync_records.find_by_trading_partner(SYNC_CODE)
            sr = ent.sync_records.build(:trading_partner=>SYNC_CODE) unless sr
            output = StringIO.new
            generate_xml_file ent, output
            output.rewind
            fingerprint = Digest::SHA1.hexdigest output.read

            if sr.fingerprint != fingerprint
              output.rewind
              if block_given?
                Tempfile.open(["PoloCaEfocus", ".xml"]) do |t|
                  t << output.read
                  t.rewind
                  yield t, sr if block_given?
                end
              else
                t = Tempfile.new ["PoloCaEfocus", ".xml"]
                t << output.read
                t.rewind
                files << t
              end
            end
          rescue OpenChain::CustomHandler::PortMissingError => e
            body = <<~BODY
              Error for file #{ent.broker_reference}.

              Port code #{e.port_code} is not set in the Ralph Lauren e-Focus XML Generator.

              If this port is invalid, please correct it in Fenix.  If it is valid, please email this message to edisupport@vandegriftinc.com and we'll add it to the program.
            BODY

            OpenMailer.send_simple_text('ralphlauren-ca@vandegriftinc.com', 'INVALID RALPH LAUREN CA PORT CODE', body).deliver_now
          end
          sr.update_attributes(:sent_at=>2.seconds.ago, :confirmed_at=>1.second.ago, :confirmation_file_name=>'n/a', fingerprint: fingerprint) unless sr.nil?
        end
        block_given? ? nil : files
      end

      def generate_xml_file entry, output_file
        doc, et = build_xml_document "entry-transmission"
        ent = add_element et, 'entry'

        add_el ent, 'entry-number', entry.entry_number
        add_el ent, 'broker-reference', entry.broker_reference
        add_el ent, 'broker-importer-id', 'RALPLA'
        add_el ent, 'broker-id', 'VFI'
        # This used to be arrival_date, which for about a year was literally an exact copy of the release date in Fenix
        # Prior to that it was an independent field populated from KPIETA activity...which is what we've gone back to doing.
        # To retain the current function (where this would be the release date (masquerading as arrival date)), we're
        # changing this to use the release date field.
        add_el ent, 'import-date', entry.release_date
        add_el ent, 'documents-received-date', entry.docs_received_date
        add_el ent, 'in-customs-date', entry.across_sent_date
        add_el ent, 'out-customs-date', entry.release_date
        add_el ent, 'available-to-carrier-date', entry.release_date
        add_el ent, 'vessel-name', entry.vessel
        add_el ent, 'voyage', entry.voyage
        add_el ent, 'country-destination', 'CA'
        add_el ent, 'total-duty', entry.total_duty
        add_el ent, 'total-tax', entry.total_gst
        add_el ent, 'total-invoice-value', entry.total_invoiced_value
        add_el ent, 'do-issued-date', entry.first_do_issued_date
        add_country_origin ent, entry
        add_country_export ent, entry
        add_unlading_port ent, entry.entry_port_code
        add_el ent, 'mode-of-transportation', TRANSPORT_MODE_MAP[entry.transport_mode_code]
        unless entry.container_numbers.blank?
          entry.container_numbers.split(' ').each do |cn|
            add_el ent, 'container', cn
          end
        end
        unless entry.master_bills_of_lading.blank?
          entry.master_bills_of_lading.split(' ').each do |mb|
            el = add_element ent, 'master-bill'
            add_element el, 'number', mb
            add_house_bills el, entry.house_bills_of_lading
          end
        end
        output_file << doc.to_s
        output_file.flush
        output_file
      end

      def ftp_credentials
        environ = (Rails.env.production? ? 'prod' : 'dev')
        ftp2_vandegrift_inc "to_ecs/Ralph_Lauren/efocus_ca_#{environ}", remote_file_name
      end

      def remote_file_name
        n = nil
        Tempfile.open(['VFITRACK', '.xml']) do |t|
          n = File.basename t.path
        end
        n
      end

      private
      def add_el parent, name, content
        return nil if content.blank?
        add_element parent, name, (content.respond_to?(:strftime) ? content.strftime("%Y%m%d") : content.to_s)
      end
      def add_country_origin parent, entry
        return nil if entry.origin_country_codes.blank?
        coo = entry.origin_country_codes.split(' ')
        add_el parent, 'country-origin', (coo.size>1 ? 'VAR' : coo.first)
      end
      def add_country_export parent, entry
        return nil if entry.export_country_codes.blank?
        coo = entry.export_country_codes.split(' ')
        add_el parent, 'country-export', coo.first
      end
      def add_unlading_port parent, fenix_port_code
        return nil if fenix_port_code.blank?
        pc = fenix_port_code
        while pc.size < 4
          pc = '0'+pc
        end
        port = Port.where(:cbsa_port=>pc).where("length(unlocode) > 0").first
        if port
          add_el parent, 'port-unlading', port.unlocode if port
        else
          pme = PortMissingError.new
          pme.port_code = pc
          raise pme
        end
        nil
      end
      def add_house_bills parent, hbol_numbers
        # since we don't have the right structure on the inbound, writing all house
        # bills under each master bill
        unless hbol_numbers.blank?
          hbol_numbers.split(' ').each do |hb|
            h = hb.size > 16 ? hb[0, 16] : hb
            add_el parent, 'house-bill', h
          end
        end
      end
    end
  end
end
