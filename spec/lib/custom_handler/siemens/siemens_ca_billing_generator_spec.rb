require 'spec_helper'

describe OpenChain::CustomHandler::Siemens::SiemensCaBillingGenerator do
  subject {OpenChain::CustomHandler::Siemens::SiemensCaBillingGenerator.new('spec/fixtures/files/vfitrack-passphraseless.gpg.key')}

  describe "find_entries" do
    context "with siemens tax ids" do
      before :each do 
        @tax_ids = ["868220450RM0001", "836496125RM0001", "868220450RM0007", "120933510RM0001", "867103616RM0001", "845825561RM0001", "843722927RM0001", 
        "868220450RM0022", "102753761RM0001", "897545661RM0001", "868220450RM0009", "892415472RM0001", "867647588RM0001", "871432977RM0001", 
        "809756851RM0001", "868220450RM0004", "894214311RM0001", "868220450RM0003", "868220450RM0005", "815627641RM0001"]

        @entries = []
        @tax_ids.each do |id|
          @entries << Factory(:entry, importer: Factory(:importer, fenix_customer_number: id), entry_number: id, k84_receive_date: Time.zone.now)
        end
      end

      it "finds siemens entries that do not have sync records" do
        expect(subject.find_entries.size).to eq @entries.size
      end

      it "excludes entries with sync records" do
        @entries.first.sync_records.create! trading_partner: "Siemens Billing"
        expect(subject.find_entries.size).to eq (@entries.size - 1)
      end

      it "excludes entries without k84 receive dates" do
        @entries.first.update_attributes! k84_receive_date: nil
        expect(subject.find_entries.size).to eq (@entries.size - 1)
      end
    end

    it "only returns siemens entries" do
      Factory(:entry, importer: Factory(:importer, fenix_customer_number: "another_id"), entry_number: "entry_number", k84_receive_date: Time.zone.now)
      expect(subject.find_entries.size).to eq 0
    end
  end

  describe "run_schedulable" do
    before :each do
      KeyJsonItem.siemens_billing('counter').create! json_data: '{"counter": 0}'
    end

    it "should find entries and generate and send them" do
      t = Factory(:commercial_invoice_tariff)
      e = t.commercial_invoice_line.entry
      e.update_attributes! importer: Factory(:importer, fenix_customer_number: "868220450RM0001"), k84_receive_date: Time.zone.now, entry_number: "11981234566789"

      file_data = nil

      # capture the data that supposedly would be encrypted (we'll test the encryption later)
      described_class.any_instance.should_receive(:encrypt_file) do |f, &blk|
        file_data = f.read
        blk.call f
      end

      described_class.any_instance.should_receive(:ftp_file).and_return true

      described_class.run_schedulable({'public_key' => 'spec/fixtures/files/vfitrack.gpg.key'})
      # All that we care about here is ultimately 1 line of something was encrypted
      # the rest is tested below.
      expect(file_data.lines.size).to eq 1
    end
  end

  context "with entry data" do
    before :each do 
      @entry = Entry.new entry_port_code: "1234", entry_number: "1234567890", broker_reference: "123456", release_date: Time.zone.parse("2015-04-01 00:00"), cargo_control_number: "CCN# 98765", transport_mode_code: "1", direct_shipment_date: Date.new(2015, 5, 1), 
                us_exit_port_code: "4567", k84_receive_date: Date.new(2015, 6, 1), importer_tax_id: "TAXID", customer_number: "CUSTNO", customer_name: "NAME", entry_type: "AB"
      @inv = CommercialInvoice.new vendor_name: "VENDOR", mfid: "12345", currency: "USD", exchange_rate: BigDecimal("1.2345")
      @entry.commercial_invoices << @inv
      @line = CommercialInvoiceLine.new line_number: "2", customs_line_number: "1", po_number: "PO123", part_number: "PART2", quantity: BigDecimal("1"), value: BigDecimal("2"),
                                          country_origin_code: "CN", country_export_code: "VN", subheader_number: "0"
      @inv.commercial_invoice_lines << @line                                          
      @tariff = CommercialInvoiceTariff.new hts_code: "12.34.56", tariff_provision: "9", spi_primary: "6", duty_rate: BigDecimal("0.25"), duty_amount: BigDecimal("9.25"), entered_value: BigDecimal("10.50"), special_authority: "6", tariff_description: "Description",
                                             sima_code: "1", value_for_duty_code: "11", sima_amount: BigDecimal("1.50"), classification_uom_1: "UOM", gst_rate_code: "5", gst_amount: BigDecimal("5.50"), excise_rate_code: "9",
                                             excise_amount: BigDecimal("9.45")
      @line.commercial_invoice_tariffs << @tariff

      # Puposely use the same customs line number so that we ensure the data roll-up for duty value is done correctly.
      @line2 = CommercialInvoiceLine.new line_number: "1", customs_line_number: "1", po_number: "PO123", part_number: "PART1", quantity: BigDecimal("1"), value: BigDecimal("2"),
                                          country_origin_code: "US", country_export_code: "US", state_origin_code: "PA", state_export_code: "IL", subheader_number: "0"
      @inv.commercial_invoice_lines << @line2                                        
      @tariff2 = CommercialInvoiceTariff.new hts_code: "12.34.56", tariff_provision: "9", spi_primary: "6", duty_rate: BigDecimal("0.25"), duty_amount: BigDecimal("9.25"), entered_value: BigDecimal("10.50"), special_authority: "6", tariff_description: "Description",
                                             sima_code: "1", value_for_duty_code: "11", sima_amount: BigDecimal("1.50"), classification_uom_1: "UOM", gst_rate_code: "5", gst_amount: BigDecimal("5.50"), excise_rate_code: "9",
                                             excise_amount: BigDecimal("9.45")
      @line2.commercial_invoice_tariffs << @tariff2
    end

    describe "generate_entry_data" do
      it "creates data objects for entry" do
        data = subject.generate_entry_data @entry
        expect(data).not_to be_nil

        expect(data.entry_port).to eq "1234"
        expect(data.entry_number).to eq "1234567890"
        expect(data.broker_reference).to eq "123456"
        expect(data.release_date).to eq Time.zone.parse("2015-04-01 00:00")
        expect(data.cargo_control_number).to eq "CCN# 98765"
        expect(data.ship_mode).to eq "1"
        expect(data.direct_shipment_date).to eq Date.new(2015, 5, 1)
        expect(data.port_exit).to eq "4567"
        expect(data.accounting_date).to eq Date.new(2015, 6, 1)
        expect(data.importer_tax_id).to eq "TAXID"
        expect(data.customer_number).to eq "CUSTNO"
        expect(data.customer_name).to eq "NAME"
        expect(data.entry_type).to eq "AB"
        expect(data.total_duty).to eq BigDecimal("18.50")
        expect(data.total_sima).to eq BigDecimal("3.00")
        expect(data.total_excise).to eq BigDecimal("18.90")
        expect(data.total_gst).to eq BigDecimal("11.00")
        expect(data.total_amount).to eq BigDecimal("51.40")

        expect(data.commercial_invoice_lines.length).to eq 2

        l = data.commercial_invoice_lines.first
        expect(l.line_number).to eq 1
        expect(l.customs_line_number).to eq 1
        expect(l.subheader_number).to eq 0
        expect(l.vendor_name).to eq "VENDOR"
        expect(l.vendor_number).to eq "12345"
        expect(l.currency).to eq "USD"
        expect(l.exchange_rate).to eq BigDecimal("1.2345")
        expect(l.po_number).to eq "PO123"
        expect(l.part_number).to eq "PART1"
        expect(l.quantity).to eq BigDecimal("1")
        expect(l.value).to eq BigDecimal("2")
        expect(l.b3_line_duty_value).to eq BigDecimal("4")
        expect(l.hts).to eq "123456"
        expect(l.tariff_provision).to eq "9"
        expect(l.country_origin).to eq "UPA"
        expect(l.spi).to eq "6"
        expect(l.country_export).to eq "UIL"
        expect(l.duty_rate).to eq BigDecimal("25.00")
        expect(l.sequence_number).to eq "7034567890000001"
        expect(l.sima_code).to eq "1"
        expect(l.sima_value).to eq BigDecimal("1.50")
        expect(l.uom).to eq "UOM"
        expect(l.gst_rate_code).to eq "5"
        expect(l.gst_amount).to eq BigDecimal("5.50")
        expect(l.excise_rate_code).to eq "9"
        expect(l.excise_amount).to eq BigDecimal("9.45")
        expect(l.description).to eq "Description"
        expect(l.value_for_tax).to eq BigDecimal("19.75")
        expect(l.duty).to eq BigDecimal("9.25")
        expect(l.entered_value).to eq BigDecimal("10.50")
        expect(l.special_authority).to eq "6"
        expect(l.description).to eq "Description"
        expect(l.value_for_duty_code).to eq "11"

        l = data.commercial_invoice_lines.second
        # These are the only values that should differ between the lines as setup in the test
        expect(l.line_number).to eq 2
        expect(l.part_number).to eq "PART2"
        expect(l.b3_line_duty_value).to eq BigDecimal("0")
        expect(l.country_origin).to eq "CN"
        expect(l.country_export).to eq "VN"
        expect(l.sequence_number).to eq "7034567890000002"

        # From here data should be the same between lines
        expect(l.customs_line_number).to eq 1
        expect(l.subheader_number).to eq 0
        expect(l.vendor_name).to eq "VENDOR"
        expect(l.vendor_number).to eq "12345"
        expect(l.currency).to eq "USD"
        expect(l.exchange_rate).to eq BigDecimal("1.2345")
        expect(l.po_number).to eq "PO123"
        expect(l.quantity).to eq BigDecimal("1")
        expect(l.value).to eq BigDecimal("2")
        expect(l.hts).to eq "123456"
        expect(l.tariff_provision).to eq "9"
        expect(l.spi).to eq "6"
        expect(l.duty_rate).to eq BigDecimal("25.00")
        expect(l.sima_code).to eq "1"
        expect(l.sima_value).to eq BigDecimal("1.50")
        expect(l.uom).to eq "UOM"
        expect(l.gst_rate_code).to eq "5"
        expect(l.gst_amount).to eq BigDecimal("5.50")
        expect(l.excise_rate_code).to eq "9"
        expect(l.excise_amount).to eq BigDecimal("9.45")
        expect(l.description).to eq "Description"
        expect(l.value_for_tax).to eq BigDecimal("19.75")
        expect(l.duty).to eq BigDecimal("9.25")
        expect(l.entered_value).to eq BigDecimal("10.50")
        expect(l.special_authority).to eq "6"
        expect(l.description).to eq "Description"
        expect(l.value_for_duty_code).to eq "11"
      end

      it "uses last 9 digits of entry number when 8th digit from the end is a zero" do
        @entry.entry_number = "1204567890"
        data = subject.generate_entry_data @entry
        expect(data).not_to be_nil

        l = data.commercial_invoice_lines.first
        expect(l.sequence_number).to eq "7204567890000001"
      end
    end

    describe "write_entry_data" do
      before :each do 
        @ed = subject.generate_entry_data @entry
      end

      it "writes out formatted entry data to an IO source" do
        io = StringIO.new
        subject.write_entry_data io, @ed

        io.rewind
        lines = io.readlines("\r\n")
        expect(lines.length).to eq 2

        l = lines.first
        expect(l[0..19]).to eq "PO123".ljust(20)
        expect(l[20..39]).to eq "PART1".ljust(20)
        expect(l[40..48]).to eq "1.00".rjust(9)
        expect(l[49..62]).to eq "2.00".rjust(14)
        expect(l[63..73]).to eq "400".rjust(11)
        expect(l[74..83]).to eq "123456".ljust(10)
        expect(l[84..87]).to eq "0009"
        expect(l[88..91]).to eq "1234"
        expect(l[92..105]).to eq "1234567890".ljust(14)
        expect(l[106..113]).to eq "20150331" # The date rolls because of the translation to Eastern timezone
        expect(l[114..116]).to eq "UPA"
        expect(l[117..119]).to eq "  6"
        expect(l[120..122]).to eq "UIL"
        expect(l[123..125]).to eq "  1"
        expect(l[126..160]).to eq "VENDOR".ljust(35)
        expect(l[161..163]).to eq "USD"
        expect(l[164..188]).to eq "CCN# 98765".ljust(25)
        expect(l[189..189]).to eq "1"
        expect(l[190..198]).to eq "25.00000".rjust(9)
        expect(l[199..207]).to eq "0.00".rjust(9)
        expect(l[208..218]).to eq "9.25".rjust(11)
        expect(l[219..232]).to eq "123456".ljust(14)
        expect(l[233..247]).to eq "12345".ljust(15)
        expect(l[248..256]).to eq "1.234500".rjust(9)
        expect(l[257..259]).to eq " 11"
        expect(l[260..270]).to eq "1050".rjust(11)
        expect(l[271..286]).to eq "6".ljust(16)
        expect(l[287..345]).to eq "Description".ljust(59)
        expect(l[346..361]).to eq "7034567890000001"
        expect(l[362..364]).to eq "  1"
        expect(l[365..369]).to eq "    0"
        expect(l[370..380]).to eq "1.50".rjust(11)
        expect(l[381..388]).to eq "20150501"
        expect(l[389..392]).to eq "4567" 
        expect(l[393..395]).to eq "UOM"
        expect(l[396..403]).to eq "20150601"
        expect(l[404..418]).to eq "TAXID".ljust(15)
        expect(l[419..428]).to eq "CUSTNO".ljust(10)
        expect(l[429..463]).to eq "NAME".ljust(35)
        expect(l[464..465]).to eq "AB"
        expect(l[466..469]).to eq " 500"
        expect(l[470..483]).to eq "5.50".rjust(14)
        expect(l[484..497]).to eq "".ljust(14)
        expect(l[498..500]).to eq "000"
        expect(l[501..507]).to eq "0000009"
        expect(l[508..516]).to eq "9.45".rjust(9)
        expect(l[517..530]).to eq "19.75".rjust(14)
        expect(l[531..544]).to eq "18.50".rjust(14)
        expect(l[545..555]).to eq "3.00".rjust(11)
        expect(l[556..566]).to eq "18.90".rjust(11)
        expect(l[567..577]).to eq "11.00".rjust(11)
        expect(l[578..591]).to eq "51.40".rjust(14)


        l = lines.second
        expect(l[0..19]).to eq "PO123".ljust(20)
        expect(l[20..39]).to eq "PART2".ljust(20)
        expect(l[40..48]).to eq "1.00".rjust(9)
        expect(l[49..62]).to eq "2.00".rjust(14)
        expect(l[63..73]).to eq "0".rjust(11)
        expect(l[74..83]).to eq "123456".ljust(10)
        expect(l[84..87]).to eq "0009"
        expect(l[88..91]).to eq "1234"
        expect(l[92..105]).to eq "1234567890".ljust(14)
        expect(l[106..113]).to eq "20150331" # The date rolls because of the translation to Eastern timezone
        expect(l[114..116]).to eq "CN "
        expect(l[117..119]).to eq "  6"
        expect(l[120..122]).to eq "VN "
        expect(l[123..125]).to eq "  1"
        expect(l[126..160]).to eq "VENDOR".ljust(35)
        expect(l[161..163]).to eq "USD"
        expect(l[164..188]).to eq "CCN# 98765".ljust(25)
        expect(l[189..189]).to eq "1"
        expect(l[190..198]).to eq "25.00000".rjust(9)
        expect(l[199..207]).to eq "0.00".rjust(9)
        expect(l[208..218]).to eq "9.25".rjust(11)
        expect(l[219..232]).to eq "123456".ljust(14)
        expect(l[233..247]).to eq "12345".ljust(15)
        expect(l[248..256]).to eq "1.234500".rjust(9)
        expect(l[257..259]).to eq " 11"
        expect(l[260..270]).to eq "1050".rjust(11)
        expect(l[271..286]).to eq "6".ljust(16)
        expect(l[287..345]).to eq "Description".ljust(59)
        expect(l[346..361]).to eq "7034567890000002"
        expect(l[362..364]).to eq "  1"
        expect(l[365..369]).to eq "    0"
        expect(l[370..380]).to eq "1.50".rjust(11)
        expect(l[381..388]).to eq "20150501"
        expect(l[389..392]).to eq "4567"
        expect(l[393..395]).to eq "UOM"
        expect(l[396..403]).to eq "20150601"
        expect(l[404..418]).to eq "TAXID".ljust(15)
        expect(l[419..428]).to eq "CUSTNO".ljust(10)
        expect(l[429..463]).to eq "NAME".ljust(35)
        expect(l[464..465]).to eq "AB"
        expect(l[466..469]).to eq " 500"
        expect(l[470..483]).to eq "5.50".rjust(14)
        expect(l[484..497]).to eq "".ljust(14)
        expect(l[498..500]).to eq "000"
        expect(l[501..507]).to eq "0000009"
        expect(l[508..516]).to eq "9.45".rjust(9)
        expect(l[517..530]).to eq "19.75".rjust(14)
        expect(l[531..544]).to eq "0.00".rjust(14)
        expect(l[545..555]).to eq "0.00".rjust(11)
        expect(l[556..566]).to eq "0.00".rjust(11)
        expect(l[567..577]).to eq "0.00".rjust(11)
        expect(l[578..591]).to eq "0.00".rjust(14)
      end
    end

    describe "generate_and_send" do
      context "transactional fixtures" do
        before :each do
          @counter = KeyJsonItem.siemens_billing('counter').create! json_data: '{"counter": 0}'
          @entry.save!
        end
        
        it "writes entry data to a file and sends it" do
          encrypted_file = nil
          filename = nil
          subject.should_receive(:ftp_file) do |ftp_file|
            encrypted_file = ftp_file.read
            filename = ftp_file.original_filename
            true
          end

          subject.generate_and_send [@entry]


          # decrypt the file then make sure it's formatted the way we expect
          gpg = OpenChain::GPG.new 'spec/fixtures/files/vfitrack-passphraseless.gpg.key', 'spec/fixtures/files/vfitrack-passphraseless.gpg.private.key'

          decrypted_file = nil
          Tempfile.open("decrypt") do |f|
            Tempfile.open("encrypted", encoding: "ascii-8bit") do |en|
              en << encrypted_file
              en.flush
              gpg.decrypt_file en, f
            end

            decrypted_file = f.read
          end
          expect(decrypted_file.lines("\r\n").length).to eq 2
          expect(filename).to eq "aca#{Time.zone.now.in_time_zone("Eastern Time (US & Canada)").strftime("%Y%m%d")}1.dat.gpg"
          sr = @entry.sync_records.first
          expect(sr.trading_partner).to eq "Siemens Billing"
          expect(sr.sent_at).not_to be_nil
          expect(sr.confirmed_at).not_to be_nil

          expect(@counter.reload.data).to eq({"counter" => 1})
          expect(ActionMailer::Base.deliveries.length).to eq 0
        end

        it "sends an email if the ftp file couldn't be sent" do
          # This is a hack to get around the transactional handling of this test case in rspec.  We intercept 
          # the call to Entry.transaction and then run the passed block inside of a new database savepoint.  That
          # way, when the transaction is rolled back in the code we're testing, the database state is rolled back to 
          # this savepoint created inside the expectation below and then we can test that no data was retained during the 
          # test.
          Entry.should_receive(:transaction) do |&block| 
            ActiveRecord::Base.transaction(requires_new: true) do 
              block.call
            end
          end

          subject.should_receive(:ftp_file).and_raise "Error!"
          expect{ subject.generate_and_send [@entry]}.to raise_error "Error!"

          expect(@entry.reload.sync_records.length).to eq 0
          expect(@counter.reload.data).to eq({"counter" => 0})
          expect(ActionMailer::Base.deliveries.length).to eq 1
          mail = ActionMailer::Base.deliveries.first
          expect(mail.to).to eq [OpenMailer::BUG_EMAIL]
          expect(mail.subject).to eq "[VFI Track Exception] - Siemens Billing File Error"
          expect(mail.body.raw_source).to include "Failed to ftp daily Siemens Billing file.  Entries that would have been included in the attached file will be resent during the next run."
          att = mail.attachments["aca#{Time.zone.now.in_time_zone("Eastern Time (US & Canada)").strftime("%Y%m%d")}1.dat"]
          # This looks to be a bug in the mail gem, it's taking the 7-bit transfer encoding and decomposing \r\n values
          # in the text as \n...the encoding SHOULD be an "identity" encoding.  Meaning the encoded and decoded values
          # of the source, but they're not.
          expect(att.read.lines("\n").length).to eq 2
        end
      end
    end
  end
end