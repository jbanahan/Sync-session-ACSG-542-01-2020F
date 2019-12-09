describe OpenChain::CustomHandler::Vandegrift::KewillCustomerParser do

  let (:file_data) { IO.read 'spec/fixtures/files/kewill_customer.json'}
  let (:json_data) { JSON.parse(file_data) }

  describe "parse_customer" do
    let (:user) { Factory(:user) }
    let (:json) { json_data.first }
    let! (:country) { Factory(:country, iso_code: "CN")}

    it "parses customer json data" do
      subject.parse_customer(json, user, 'file.json')

      c = Company.where(name: "CHEER YOU E-BUSINESS CO., LTD.").first
      expect(c).not_to be_nil
      expect(c).to be_importer
      expect(c.system_code).to eq "CHYOU"
      expect(c.name).to eq "CHEER YOU E-BUSINESS CO., LTD."
      expect(c).to have_system_identifier("Customs Management", "CHYOU")

      expect(c.entity_snapshots.length).to eq 1
      expect(c.entity_snapshots.first.user).to eq user
      expect(c.entity_snapshots.first.context).to eq "file.json"

      expect(c.addresses.length).to eq 1
      a = c.addresses.first
      expect(a.system_code).to eq "1"
      expect(a.line_1).to eq "1510 NANYUAN ST, RM 1, YUHANG"
      expect(a.line_2).to eq "STE 123"
      expect(a.city).to eq "HANGZHOU"
      expect(a.state).to eq "FN"
      expect(a.country).to eq country
    end

    it "parses amazon importer data" do
      file_data.gsub!("CHYOU", "AMZNCHYOU")
      subject.parse_customer(json, user, 'file.json')

      c = Company.where(name: "CHEER YOU E-BUSINESS CO., LTD.").first
      expect(c).to have_system_identifier("Customs Management", "AMZNCHYOU")
      expect(c).to have_system_identifier("Amazon Reference", "U3APF6WDEFH7C")
    end

    it "updates company record" do
      existing = Factory(:company, name: "CUSTNO", system_code: "CODE")
      existing.system_identifiers.create! system: "Customs Management", code: "CHYOU"

      subject.parse_customer(json, user, 'file.json')
      existing.reload

      # System Code should not be updated.
      expect(existing.system_code).to eq "CODE"
      expect(existing.name).to eq "CHEER YOU E-BUSINESS CO., LTD."
      expect(existing.addresses.length).to eq 1
      a = existing.addresses.first
      expect(a.system_code).to eq "1"
      expect(a.line_1).to eq "1510 NANYUAN ST, RM 1, YUHANG"
      expect(a.line_2).to eq "STE 123"
      expect(a.city).to eq "HANGZHOU"
      expect(a.state).to eq "FN"
      expect(a.country).to eq country

      expect(existing.entity_snapshots.length).to eq 1
      expect(existing.entity_snapshots.first.user).to eq user
      expect(existing.entity_snapshots.first.context).to eq "file.json"
    end

    it "snapshots when only updating an address" do
      existing = Factory(:company, name: "CHEER YOU E-BUSINESS CO., LTD.")
      existing.system_identifiers.create! system: "Customs Management", code: "CHYOU"
      existing.addresses.create system_code: "1"

      subject.parse_customer(json, user, 'file.json')
      existing.reload
      expect(existing.addresses.length).to eq 1
      a = existing.addresses.first
      expect(a.system_code).to eq "1"
      expect(a.line_1).to eq "1510 NANYUAN ST, RM 1, YUHANG"
      expect(a.line_2).to eq "STE 123"
      expect(a.city).to eq "HANGZHOU"
      expect(a.state).to eq "FN"
      expect(a.country).to eq country

      expect(existing.entity_snapshots.length).to eq 1
      expect(existing.entity_snapshots.first.user).to eq user
      expect(existing.entity_snapshots.first.context).to eq "file.json"
    end
  end

  describe "parse" do
    subject { described_class }
    let! (:inbound_file) {
      i = InboundFile.new
      allow(subject).to receive(:inbound_file).and_return i
      i
    }

    it "parses json and calls parse_customer for each entity" do
      expect_any_instance_of(subject).to receive(:parse_customer).with(json_data.first, User.integration, "file.json")
      subject.parse file_data, key: "file.json"
    end

    it "logs errors raised by 'parse_customer'" do
      error = StandardError.new "Parser Error"
      expect_any_instance_of(subject).to receive(:parse_customer).with(json_data.first, User.integration, "file.json").and_raise error
      expect(error).to receive(:log_me)

      subject.parse file_data, key: "file.json"
      expect(inbound_file).to have_error_message("Failed to update account data for customer 'CHYOU'.")
    end
  end
end