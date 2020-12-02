describe OpenChain::CustomHandler::Vandegrift::CatairParserSupport do

  subject {
    Class.new {
      include OpenChain::CustomHandler::Vandegrift::CatairParserSupport

      def inbound_file
        nil
      end
    }.new
  }

  describe "record_type" do
    ["A", "B", "Y", "Z"].each do |record_type|
      it "identifies single character record type '#{record_type}'" do
        expect(subject.record_type "#{record_type}BCDEFG").to eq record_type
      end
    end

    it "identifies other record types" do
      expect(subject.record_type "XX10123457890712309").to eq "XX10"
    end

    it "identifies numeric only record types" do
      expect(subject.record_type "1010").to eq "10"
    end
  end

  describe "find_customer_number" do
    let! (:importer) { with_customs_management_id(create(:importer, irs_number: "XX-XXXXXXX"), "CMUS")}
    let! (:inbound_file) {
      i = InboundFile.new
      allow(subject).to receive(:inbound_file).and_return i
      i
    }

    it "finds importer with given IRS number and CMUS customer number" do
      expect(subject.find_customer_number "EI", "XX-XXXXXXX").to eq "CMUS"
      expect(inbound_file.company).to be_nil
    end

    it "logs importer to inbound file if instructed" do
      subject.find_customer_number "EI", "XX-XXXXXXX", log_customer_to_inbound_file: true
      expect(inbound_file.company).to eq importer
    end

    it "logs importer to inbound file if not instructed" do
      subject.find_customer_number "EI", "XX-XXXXXXX", log_customer_to_inbound_file: false
      expect(inbound_file.company).to be_nil
    end

    it "logs and raises an error if non-EI CATAIR Importer identifier types are utilized" do
      expect { subject.find_customer_number "XX", nil}.to raise_error "Importer Record Types of 'XX' are not supported at this time."
      expect(inbound_file).to have_reject_message("Importer Record Types of 'XX' are not supported at this time.")
    end

    it "logs and raises an error if no Importer is found with the given EIN #" do
      expect { subject.find_customer_number "EI", "YY-YYYYYYY"}.to raise_error "Failed to find any importer account associated with EIN # 'YY-YYYYYYY' that has a CMUS Customer Number."
      expect(inbound_file).to have_reject_message("Failed to find any importer account associated with EIN # 'YY-YYYYYYY' that has a CMUS Customer Number.")
    end

    it "logs and raises an error if Importer found does not have a CMUS number" do
      importer.system_identifiers.delete_all

      expect { subject.find_customer_number "EI", "XX-XXXXXXX"}.to raise_error "Failed to find any importer account associated with EIN # 'XX-XXXXXXX' that has a CMUS Customer Number."
      expect(inbound_file).to have_reject_message("Failed to find any importer account associated with EIN # 'XX-XXXXXXX' that has a CMUS Customer Number.")
    end
  end

  describe "gpg_secrets_key" do
    it "uses open_chain secrets key" do
      expect(subject.class.gpg_secrets_key({})).to eq "open_chain"
    end
  end

  describe "send_email_notification" do
    let (:importer) { with_customs_management_id(create(:importer), "CUST")}
    let! (:mailing_list) { MailingList.create! system_code: "CUST 3461 EDI", email_addresses: "me@there.com", company: importer, name: "3461 EDI", user: create(:user, company: importer) }
    let (:shipment) {
      e = OpenChain::CustomHandler::Vandegrift::VandegriftCatair3461Parser::CiLoadEntry.new
      e.customer = "CUST"
      e.entry_filer_code = "123"
      e.entry_number = "123456"
      e
    }

    it "notifies of received shipment data" do
      subject.send_email_notification [shipment], "3461"
      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "CUST 3461 EDI File Receipt"
      expect(m.body.raw_source).to include "EDI data was generated and sent to Customs Management for Entry Number: 123-12345-6."
    end

    it "does not send notification if no email group exists" do
      mailing_list.destroy
      subject.send_email_notification [shipment], "3461"
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end

    it "does not send notification if customer number doesn't exist" do
      importer.destroy
      subject.send_email_notification [shipment], "3461"
      expect(ActionMailer::Base.deliveries.length).to eq 0
    end
  end

  describe "strip_entry_number" do
    let (:shipment) {
      e = OpenChain::CustomHandler::Vandegrift::VandegriftCatair3461Parser::CiLoadEntry.new
      e.entry_filer_code = "123"
      e.entry_number = "123456"
      e.file_number = "12345"
      e
    }

    it "removes entry number information" do
      subject.strip_entry_number(shipment)
      expect(shipment.entry_filer_code).to be_nil
      expect(shipment.entry_number).to be_nil
      expect(shipment.file_number).to be_nil
    end
  end
end