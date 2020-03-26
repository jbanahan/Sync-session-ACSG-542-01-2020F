describe OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSenderSupport do
  subject {
    Class.new do 
      include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSenderSupport
    end.new
  }

  


  describe "generate_and_send_shipment_xml" do
    let (:shipment_data_with_bol) {
      edi = subject.class::CiLoadEdiIdentifier.new
      edi.master_bill = "MASTERBILL"
      edi.house_bill = "HOUSEBILL"

      shipment_data.edi_identifier = edi

      bol = subject.class::CiLoadBillsOfLading.new
      bol.master_bill = "BOLMASTERBILL"
      bol.house_bill = "BOLHOUSEBILL"
      shipment_data.bills_of_lading = [bol]

      shipment_data
    }

    let (:shipment_data) {
      s = subject.class::CiLoadEntry.new
      s.file_number = "12345"
      s.customer = "CUST"
      s
    }

    let (:xml) {
      REXML::Document.new("<shipment></shipment>")
    }

    before :each do 
      allow(subject).to receive(:generate_entry_xml).and_return xml
    end

    it "generates xml data and ftps it" do
      now = Time.zone.now
      expect(subject).to receive(:ftp_file) do |file, ftp_opts|
        expect(file.original_filename).to eq "CM_SHP_CUST_12345_#{now.strftime("%Y-%m-%dT%H-%M-%S")}.xml"
        expect(ftp_opts[:folder]).to eq "kewill_edi/to_kewill"
        expect(ftp_opts[:username]).to eq "ecs"
      end
      Timecop.freeze(now) { subject.generate_and_send_shipment_xml(shipment_data) }
    end

    it "generates xml data and ftps it with single sync_record" do
      sr = Object.new
      expect(subject).to receive(:ftp_sync_file) do |file, sync_record, ftp_opts|
        expect(file.original_filename).to start_with "CM_SHP_CUST_12345_"
        expect(sync_record).to eq sr
      end
      subject.generate_and_send_shipment_xml(shipment_data, sync_records: sr)
    end

    it "generates xml data for multiple files and ftps it with multiple sync_records" do
      srs = [Object.new, Object.new]
      times = 0
      expect(subject).to receive(:ftp_sync_file).exactly(2).times do |file, sync_record, ftp_opts|
        expect(sync_record).to eq srs[times]
        times += 1
      end
      subject.generate_and_send_shipment_xml([shipment_data, shipment_data], sync_records: srs)
    end

    context "without file_number" do
      before :each do 
        shipment_data.file_number = nil
      end

      it "uses edi identifier masterbill in filename and ftps it" do
        expect(subject).to receive(:ftp_file) do |file, ftp_opts|
          expect(file.original_filename).to start_with("CM_SHP_CUST_MASTERBILL_")
        end

        subject.generate_and_send_shipment_xml(shipment_data_with_bol)
      end

      it "uses edi identifier housebill in filename and ftps it" do
        shipment_data_with_bol.edi_identifier.master_bill = nil

        expect(subject).to receive(:ftp_file) do |file, ftp_opts|
          expect(file.original_filename).to start_with("CM_SHP_CUST_HOUSEBILL_")
        end

        subject.generate_and_send_shipment_xml(shipment_data_with_bol)
      end

      context "without edi_identifier" do
        before :each do 
          shipment_data_with_bol.edi_identifier = nil
        end

        it "uses edi identifier masterbill in filename and ftps it" do
          expect(subject).to receive(:ftp_file) do |file, ftp_opts|
            expect(file.original_filename).to start_with("CM_SHP_CUST_BOLMASTERBILL_")
          end

          subject.generate_and_send_shipment_xml(shipment_data_with_bol)
        end

        it "uses edi identifier housebill in filename and ftps it" do
          shipment_data_with_bol.bills_of_lading.first.master_bill = nil

          expect(subject).to receive(:ftp_file) do |file, ftp_opts|
            expect(file.original_filename).to start_with("CM_SHP_CUST_BOLHOUSEBILL_")
          end

          subject.generate_and_send_shipment_xml(shipment_data_with_bol)
        end
      end
    end
  end

  describe "generate_and_send_invoice_xml" do
    let (:invoice_data) {
      s = subject.class::CiLoadEntry.new
      s.file_number = "12345"
      s.customer = "CUST"
      i = subject.class::CiLoadInvoice.new
      i.invoice_number = "INVOICE"
      i.file_number = "67890"
      s.invoices = [i]
      s
    }

    let (:xml) {
      REXML::Document.new("<shipment></shipment>")
    }

    before :each do 
      allow(subject).to receive(:generate_entry_xml).and_return xml
    end

    it "generates xml data and ftps it" do
      now = Time.zone.now
      expect(subject).to receive(:ftp_sync_file) do |file, sync_record, ftp_opts|
        expect(file.original_filename).to eq "CM_CI_CUST_12345_#{now.strftime("%Y-%m-%dT%H-%M-%S")}.xml"
        expect(ftp_opts[:folder]).to eq "kewill_edi/to_kewill"
        expect(ftp_opts[:username]).to eq "ecs"
        expect(sync_record).to be_nil
      end
      Timecop.freeze(now) { subject.generate_and_send_invoice_xml(invoice_data) }
    end

    it "generates xml data and ftps it with single sync_record" do
      sr = Object.new
      expect(subject).to receive(:ftp_sync_file) do |file, sync_record, ftp_opts|
        expect(file.original_filename).to start_with "CM_CI_CUST_12345_"
        expect(sync_record).to eq sr
      end
      subject.generate_and_send_invoice_xml(invoice_data, sync_records: sr)
    end

    it "generates xml data for multiple files and ftps it with multiple sync_records" do
      srs = [Object.new, Object.new]
      times = 0
      expect(subject).to receive(:ftp_sync_file).exactly(2).times do |file, sync_record, ftp_opts|
        expect(sync_record).to eq srs[times]
        times += 1
      end
      subject.generate_and_send_invoice_xml([invoice_data, invoice_data], sync_records: srs)
    end

    context "without file_number" do
      before :each do 
        invoice_data.file_number = nil
      end

      it "falls back to invoice level file number for filename" do
        expect(subject).to receive(:ftp_file) do |file, ftp_opts|
          expect(file.original_filename).to start_with("CM_CI_CUST_67890_")
        end

        subject.generate_and_send_invoice_xml(invoice_data)
      end

      it "falls back to invoice level invoice number for filename" do
        invoice_data.invoices.first.file_number = nil

        expect(subject).to receive(:ftp_file) do |file, ftp_opts|
          expect(file.original_filename).to start_with("CM_CI_CUST_INVOICE_")
        end

        subject.generate_and_send_invoice_xml(invoice_data)
      end
    end
  end
end