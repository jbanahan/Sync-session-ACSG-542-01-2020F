describe OpenChain::CustomHandler::Generator315::Tradelens::Data315Filler do
  let(:data) { {transport_mode_code: 40, master_bills: ["MAEUMBOL1", "MAEUMBOL2"], container_numbers: ["cont_num1", "cont_num2"]} }
  let(:milestone) { OpenStruct.new code: "ms code", date: Date.new(2020, 3, 15), sync_record: SyncRecord.new }
  let(:entry) { Factory(:entry, entry_port_code: "PORT CODE", import_country: Factory(:country, iso_code: "US"))  }

  describe "create_315_data" do
    it "creates 315" do
      filler = described_class.new(entry, data, milestone)
      filler.create_315_data
      data_315 = filler.data_315

      expect(data_315.transport_mode_code).to eq 40
      expect(data_315.master_bills).to eq ["MAEUMBOL1", "MAEUMBOL2"]
      expect(data_315.container_numbers).to eq ["cont_num1", "cont_num2"]
      expect(data_315.event_code).to eq "ms code"
      expect(data_315.event_date).to eq Date.new(2020, 3, 15)
      expect(data_315.sync_record).to be_instance_of(SyncRecord)
    end

    it "returns nil if masterbills are missing" do
      data[:master_bills] = nil
      filler = described_class.new(entry, data, milestone)
      filler.create_315_data

      expect(filler.data_315).to be_nil
    end

    it "returns nil if container numbers are missing" do
      data[:container_numbers] = nil
      filler = described_class.new(entry, data, milestone)
      filler.create_315_data

      expect(filler.data_315).to be_nil
    end
  end

  describe "add_entry_port" do
    it "adds port code as UN/Locode if alpha string" do
      filler = described_class.new(entry, data, milestone)
      filler.create_315_data.add_entry_port
      data_315 = filler.data_315

      expect(data_315.unlocode).to eq "PORT CODE"
      expect(data_315.gln).to be_nil
    end

    context "with numeric code" do
      it "adds prefixes port code with 'Schedule D:' for US entry" do
        entry.entry_port_code = "12345"

        filler = described_class.new(entry, data, milestone)
        filler.create_315_data.add_entry_port
        data_315 = filler.data_315

        expect(data_315.unlocode).to be_nil
        expect(data_315.gln).to eq "Schedule D: 12345"
      end

      it "adds prefixes port code with 'CBSA:' for CA entry" do
        entry.entry_port_code = "12345"
        entry.import_country = Factory(:country, iso_code: "CA")

        filler = described_class.new(entry, data, milestone)
        filler.create_315_data.add_entry_port
        data_315 = filler.data_315

        expect(data_315.unlocode).to be_nil
        expect(data_315.gln).to eq "CBSA: 12345"
      end
    end

    it "does nothing if 315 data hasn't been created" do
      filler = described_class.new(entry, data, milestone)
      filler.add_entry_port
      expect(filler.data_315).to be_nil
    end
  end
end
