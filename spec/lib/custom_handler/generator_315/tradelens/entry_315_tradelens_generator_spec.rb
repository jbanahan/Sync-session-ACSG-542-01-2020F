describe OpenChain::CustomHandler::Generator315::Tradelens::Entry315TradelensGenerator do

  let (:data) do
    struct = OpenStruct.new
    struct.sync_record = SyncRecord.new
    struct
  end

  before do
    DataCrossReference.create! cross_reference_type: "tradelens_entry_milestone_fields", key: "ent_one_usg_date", value: "customs_release"
  end

  describe "generate_and_send_315s" do

    let (:config) { MilestoneNotificationConfig.new output_style: MilestoneNotificationConfig::OUTPUT_STYLE_TRADELENS_MBOL, customer_number: "config_cust" }

    it "splits data, generates milestones for each and sends" do
      splits = ["S1", "S2"]
      milestones = ["M1", "M2"]
      data_315s = ["D1", "D2", "D3", "D4"]
      obj = Object.new

      expect(subject).to receive(:split_entry_data_identifiers).with("tradelens_mbol", obj).and_return splits
      expect(subject).to receive(:create_315_data).with(obj, "S1", "M1").and_return data_315s[0]
      expect(subject).to receive(:create_315_data).with(obj, "S1", "M2").and_return data_315s[1]
      expect(subject).to receive(:create_315_data).with(obj, "S2", "M1").and_return data_315s[2]
      expect(subject).to receive(:create_315_data).with(obj, "S2", "M2").and_return data_315s[3]
      expect(subject).to receive(:setup_customer).with(config).and_return "setup_customer"

      expect(subject).to receive(:generate_and_send_document).with("setup_customer", data_315s, false).and_yield(data)
      expect(data.sync_record).to receive(:save!)
      now = Time.zone.now
      Timecop.freeze(now) { subject.generate_and_send_315s config, obj, milestones }

      expect(data.sync_record.confirmed_at).to eq now
    end
  end

  describe "generate_and_send_document" do
    let(:session) { create(:api_session) }

    before do
      data.event_code = "one_usg_date"
    end

    it "sends milestone with handler determined by event code, yields 315 data" do
      expect_any_instance_of(OpenChain::CustomHandler::Generator315::Tradelens::CustomsReleaseHandler).to receive(:send_milestone)
        .with(data)
        .and_return session
      expect { |b| subject.generate_and_send_document nil, [data], &b }.to yield_with_args data
      expect(data.sync_record.api_session).to eq session
    end

    it "does nothing without 315 data" do
      expect { |b| subject.generate_and_send_document nil, [], &b }.not_to yield_with_args
    end

    it "doesn't yield if 'testing'" do
      expect_any_instance_of(OpenChain::CustomHandler::Generator315::Tradelens::CustomsReleaseHandler).to receive(:send_milestone)
        .with(data)
        .and_return session

      expect { |b| subject.generate_and_send_document nil, [data], true, &b }.not_to yield_with_args
      expect(data.sync_record.api_session).to eq session
    end
  end

  describe "create_315_data" do
    let(:milestone) { described_class::MilestoneUpdate.new "one_usg_date", DateTime.new(2020, 3, 15) }

    it "calls field handler indicated by milestone" do
      expect_any_instance_of(OpenChain::CustomHandler::Generator315::Tradelens::CustomsReleaseHandler).to receive(:create_315_data)
        .with("entry", data, milestone)
      subject.create_315_data "entry", data, milestone
    end
  end

  describe "split_entry_data_identifiers" do
    let(:entry) do
      create(:entry, transport_mode_code: "10", master_bills_of_lading: "mbol1\nmbol2", container_numbers: "ctainr1\nctainr2",
                      house_bills_of_lading: "hbol1\nhbol2", cargo_control_number: "ccn1\nccn2")
    end

    it "splits by master bill, then container" do
      values = subject.split_entry_data_identifiers MilestoneNotificationConfig::OUTPUT_STYLE_TRADELENS_MBOL_CONTAINER_SPLIT, entry
      expect(values).to eq [{transport_mode_code: "10", master_bills: ["mbol1"], container_numbers: ["ctainr1"], house_bills: ["hbol1", "hbol2"],
                             cargo_control_numbers: ["ccn1", "ccn2"]},
                            {transport_mode_code: "10", master_bills: ["mbol1"], container_numbers: ["ctainr2"], house_bills: ["hbol1", "hbol2"],
                             cargo_control_numbers: ["ccn1", "ccn2"]},
                            {transport_mode_code: "10", master_bills: ["mbol2"], container_numbers: ["ctainr1"], house_bills: ["hbol1", "hbol2"],
                             cargo_control_numbers: ["ccn1", "ccn2"]},
                            {transport_mode_code: "10", master_bills: ["mbol2"], container_numbers: ["ctainr2"], house_bills: ["hbol1", "hbol2"],
                             cargo_control_numbers: ["ccn1", "ccn2"]}]
    end

    it "splits by master bill only" do
      values = subject.split_entry_data_identifiers MilestoneNotificationConfig::OUTPUT_STYLE_TRADELENS_MBOL, entry
      expect(values).to eq [{transport_mode_code: "10", master_bills: ["mbol1"], container_numbers: ["ctainr1", "ctainr2"], house_bills: ["hbol1", "hbol2"],
                             cargo_control_numbers: ["ccn1", "ccn2"]},
                            {transport_mode_code: "10", master_bills: ["mbol2"], container_numbers: ["ctainr1", "ctainr2"], house_bills: ["hbol1", "hbol2"],
                             cargo_control_numbers: ["ccn1", "ccn2"]}]
    end
  end

end
