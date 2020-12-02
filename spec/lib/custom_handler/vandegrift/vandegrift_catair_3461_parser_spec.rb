describe OpenChain::CustomHandler::Vandegrift::VandegriftCatair3461Parser do
  let (:data) { IO.read 'spec/fixtures/files/catair_3461.txt' }
  let! (:inbound_file) do
    file = InboundFile.new
    allow(subject).to receive(:inbound_file).and_return file
    file
  end

  let! (:importer) do
    with_customs_management_id(create(:importer, irs_number: "30-0641353"), "CUSTNO")
  end

  describe "process_file" do

    it "parses catair file and generates xml" do
      shipments = subject.process_file data
      shipment = shipments.first

      expect(shipment).not_to be_nil
      expect(shipment.entry_filer_code).to be_nil
      expect(shipment.entry_number).to be_nil
      expect(shipment.file_number).to be_nil
      expect(shipment.entry_type).to eq "06"
      expect(shipment.customer).to eq "CUSTNO"
      expect(shipment.customs_ship_mode).to eq 11
      expect(shipment.bond_type).to eq 4
      expect(shipment.total_value_us).to eq 2_094_923_138
      expect(shipment.entry_port).to eq 4103
      expect(shipment.unlading_port).to eq 1234
      expect(shipment.edi_identifier&.master_bill).to eq "31600000019P"

      expect(shipment.firms_code).to eq "HAW9"
      expect(shipment.vessel).to eq "FTZ138030"
      expect(shipment.voyage).to eq "VOYA"
      expect(shipment.dates.length).to eq 1
      d = shipment.dates.first
      expect(d.code).to eq :elected_entry_date
      expect(d.date).to eq Date.new(2020, 1, 9)

      expect(shipment.invoices.length).to eq 1
      inv = shipment.invoices.first

      expect(inv.invoice_number).to eq "316-0000001-9"
      expect(inv.invoice_date).to eq Date.new(2020, 1, 9)

      expect(inv.invoice_lines.length).to eq 1
      line = inv.invoice_lines.first

      expect(line.part_number).to eq "001"
      expect(line.country_of_origin).to eq "CN"
      expect(line.description).to eq "DESCRIPTION OF PRODUCT"
      expect(line.ftz_zone_status).to eq "N"
      expect(line.ftz_priv_status_date).to eq Date.new(2020, 2, 2)
      expect(line.ftz_quantity).to eq 5544
      expect(line.hts).to eq "3303003000"
      expect(line.foreign_value).to eq 10_000
      expect(line.ftz_expired_hts_number).to eq "9999999999"

      expect(line.parties.length).to eq 1
      p = line.parties.first

      expect(p.qualifier).to eq "MF"
      expect(p.name).to eq "COSBE LABORATORY INC."
      expect(p.address_1).to eq "NO.1A BUILDING AND NO.5 JINPU ROAD,"
      expect(p.address_2).to be_nil
      expect(p.address_3).to be_nil
      expect(p.city).to eq "SHANTOU"
      expect(p.country_subentity).to eq "XXX"
      expect(p.zip).to eq "12345"
      expect(p.country).to eq "CN"
      expect(p.mid).to eq "CNWAHLAIHUI"

      expect(inbound_file.company).to eq importer
    end

    it "does not append master bill suffix for non-FTZ files" do
      data.gsub!(" 06EI ", " 01EI ")

      shipment = Array.wrap(subject.process_file(data)).first
      expect(shipment.entry_type).to eq "01"
      expect(shipment.edi_identifier&.master_bill).to eq "31600000019"
    end

    it "raises an error if non EIN importer identifier is utilized on SE10 lines" do
      data.sub!("EI 30-0641353", "AB 30-0641353")

      expect { subject.process_file data }.to raise_error "Importer Record Types of 'AB' are not supported at this time."
      expect(inbound_file).to have_reject_message "Importer Record Types of 'AB' are not supported at this time."
    end

    it "raises an error if no Importer account exists with the EIN given" do
      importer.update! irs_number: "12345"

      expect { subject.process_file data }.to raise_error "Failed to find any importer account associated with EIN # '30-0641353' that has a CMUS Customer Number."
      expect(inbound_file).to have_reject_message "Failed to find any importer account associated with EIN # '30-0641353' that has a CMUS Customer Number."
    end

    it "raises an error if no Importer account using the given EIN Number has a Customs Managment id" do
      importer.system_identifiers.delete_all

      expect { subject.process_file data }.to raise_error "Failed to find any importer account associated with EIN # '30-0641353' that has a CMUS Customer Number."
      expect(inbound_file).to have_reject_message "Failed to find any importer account associated with EIN # '30-0641353' that has a CMUS Customer Number."
    end

    it "checks all importers that share EIN numbers for a CMUS identifier to use" do
      importer.system_identifiers.delete_all
      # Create an alternate importer to show that we use the one w/ the actual system identifier
      with_customs_management_id(create(:importer, irs_number: "30-0641353"), "ALTERNATE")

      shipments = subject.process_file data
      shipment = shipments.first

      expect(shipment).not_to be_nil
      expect(shipment.customer).to eq "ALTERNATE"
    end
  end

  describe "process_B" do
    it "logs and raises an error if invalid Application Code is sent" do
      expect { subject.process_B nil, "B  4103316XX"}
        .to raise_error "CATAIR B-record's Application Identifier Code (Position 11-12) must be 'SE' to indicate a Cargo Release.  It was 'XX'."
      expect(inbound_file).to have_reject_message "CATAIR B-record's Application Identifier Code (Position 11-12) must be 'SE' to indicate a Cargo Release.  It was 'XX'."
    end
  end

  describe "process_SE35_55" do
    let (:party) { described_class::CiLoadParty.new }

    it "handles combines address elements present on the same segment into 1 address field" do
      subject.process_SE35_55 party, "SE550177-78                              02INDUSTRIAL ESTATE"
      expect(party.address_1).to eq "77-78 INDUSTRIAL ESTATE"
      expect(party.address_2).to be_nil
      expect(party.address_3).to be_nil
    end

    it "uses address_2 if address_1 already has a value in it" do
      party.address_1 = "123 FAKE ST"
      subject.process_SE35_55 party, "SE5515NO.1A BUILDING AND NO.5 JINPU ROAD"
      expect(party.address_1).to eq "123 FAKE ST"
      expect(party.address_2).to eq "NO.1A BUILDING AND NO.5 JINPU ROAD"
      expect(party.address_3).to be_nil
    end

    it "does not add line to address if the line is already present in the address" do
      party.address_1 = "NO.1A BUILDING AND NO.5 JINPU ROAD"
      subject.process_SE35_55 party, "SE5515NO.1A BUILDING AND NO.5 JINPU ROAD"
      expect(party.address_1).to eq "NO.1A BUILDING AND NO.5 JINPU ROAD"
      expect(party.address_2).to be_nil
      expect(party.address_3).to be_nil
    end

    it "does nothing if address data is blank" do
      subject.process_SE35_55 party, "SE5501                                   02               "
      expect(party.address_1).to be_nil
      expect(party.address_2).to be_nil
      expect(party.address_3).to be_nil
    end

    it "skips new line if it is a subset of an existing line" do
      party.address_1 = "123 FAKE ST, Building A"
      subject.process_SE35_55 party, "SE5515123 Fake ST"
      expect(party.address_1).to eq "123 FAKE ST, Building A"
      expect(party.address_2).to be_nil
      expect(party.address_3).to be_nil
    end

    it "replaces an existing line if it is a superset of an existing line" do
      party.address_1 = "123 FAKE ST"
      subject.process_SE35_55 party, "SE5515123 Fake ST, Building A"
      expect(party.address_1).to eq "123 Fake ST, Building A"
      expect(party.address_2).to be_nil
      expect(party.address_3).to be_nil
    end
  end

  describe "parse" do
    subject { described_class }

    let (:shipment) { described_class::CiLoadEntry.new }

    before do
      allow_any_instance_of(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "parses a file and ftps the resulting xml" do
      expect_any_instance_of(subject).to receive(:process_file).with(data).and_return [shipment]
      expect_any_instance_of(subject).to receive(:generate_and_send_shipment_xml).with([shipment])
      expect_any_instance_of(subject).to receive(:send_email_notification).with([shipment], "3461")
      subject.parse data
    end
  end
end