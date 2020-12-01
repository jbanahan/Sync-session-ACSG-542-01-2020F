describe OpenChain::CustomHandler::Generator315::Tradelens::EntryFieldHandler do

  let(:handler_class) do
    OpenChain::CustomHandler::Generator315::Tradelens::CustomsReleaseHandler.new
  end

  let(:sr) { SyncRecord.create! trading_partner: "partner" }
  let(:date) { DateTime.new(2020, 3, 15) }
  let(:data) do
    {transport_mode_code: 10,
     master_bills: ["MAEUMBOL1", "MAEUMBOL2"],
     container_numbers: ["ctainr_num1", "ctainr_num2"],
     house_bills: ["HBOL1", "HBOL2"],
     cargo_control_numbers: ["ccn_num1", "ccn_num2"]}
  end
  let(:milestone) { described_class::MilestoneUpdate.new "one_usg_date", date, sr }
  let(:ent) { FactoryBot(:entry, entry_port_code: "ABCD") }

  describe "endpoint_labels" do
    it "converts subclass data into labels" do
      expect(described_class.endpoint_labels).to eq({customs_release: "Customs Release", customs_hold: "Customs Hold" })
    end
  end

  describe "create_315_data" do

    it "combines entry and milestone data in a struct" do
      data_315 = handler_class.create_315_data ent, data, milestone

      expect(data_315.master_bills).to eq ["MAEUMBOL1", "MAEUMBOL2"]
      expect(data_315.container_numbers).to eq ["ctainr_num1", "ctainr_num2"]
      expect(data_315.event_code).to eq "one_usg_date"
      expect(data_315.event_date).to eq date
      expect(data_315.sync_record).to eq sr
    end

    it "returns nil if missing either master bills or container numbers" do
      data[:container_numbers] = []
      expect(handler_class.create_315_data(ent, data, milestone)).to be_nil
    end
  end

  describe "send_milestone" do
    let(:request) do
      {originatorName: "Damco Customs Services Inc", originatorId: "DCSI", eventSubmissionTime8601: "2020-03-16T00:00:00.000+00:00",
       equipmentNumber: "ctainr_num1", billOfLadingNumber: "MBOL1", eventOccurrenceTime8601: "2020-03-15T00:00:00.000+00:00",
       location: {type: "UN/LOCODE", value: "ABCD"}}
    end

    it "attaches request to new session, calls TL client" do
      tl_client = instance_double(OpenChain::CustomHandler::Generator315::Tradelens::TradelensClient)
      expect(OpenChain::CustomHandler::Generator315::Tradelens::TradelensClient).to receive(:new)
        .with("/api/v1/genericEvents/customsRelease")
        .and_return tl_client
      expect(tl_client).to receive(:url).and_return "url"
      # 'anything' is the session id, but it isn't practical to mock it
      expect(tl_client).to receive(:send_milestone).with(request, anything, delay: true)

      t = Tempfile.new
      expect(Tempfile).to receive(:open).with(["CustomsReleaseHandler_request_", ".json"]).and_yield t

      data_315 = handler_class.create_315_data ent, data, milestone

      Timecop.freeze(date + 1.day) do
        expect { handler_class.send_milestone(data_315) }.to change(ApiSession, :count).from(0).to 1
      end

      session = ApiSession.first
      expect(session.class_name).to eq 'OpenChain::CustomHandler::Generator315::Tradelens::CustomsReleaseHandler'
      expect(session.endpoint).to eq "url"
      expect(session.retry_count).to eq 0
      expect(session.attachments.count).to eq 1

      att = session.attachments.first
      expect(att.attachment_type).to eq "request"
      expect(att.uploaded_by).to eq User.integration

      t.rewind
      expect(JSON.parse(t.read).deep_symbolize_keys).to eq(request)
      t.close
    end
  end
end
