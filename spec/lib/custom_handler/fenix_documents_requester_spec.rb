describe OpenChain::CustomHandler::FenixDocumentsRequester do

  describe "run_schedulable" do
    let(:config) { {'s3_bucket' => "bucket", 'sqs_receive_queue' => "receive_queue"}.with_indifferent_access }

    before :each do
      allow(described_class).to receive(:imaging_config).and_return config
    end

    it "polls with given last/current run values" do
      s_time = Time.zone.now - 10.minutes
      e_time = Time.zone.now
      expect(described_class).to receive(:poll).with(polling_offset: 300).and_yield(s_time, e_time)

      sql_proxy = double("OpenChain::FenixSqlProxyClient")
      expect(described_class).to receive(:sql_proxy_client).and_return sql_proxy
      expect(sql_proxy).to receive(:request_images_added_between).with(s_time, e_time, "bucket", "receive_queue")
      described_class.run_schedulable
    end

    it "uses polling offset given in opts" do
      s_time = Time.zone.now - 10.minutes
      e_time = Time.zone.now
      expect(described_class).to receive(:poll).with(polling_offset: 0).and_yield(s_time, e_time)

      sql_proxy = double("OpenChain::FenixSqlProxyClient")
      expect(described_class).to receive(:sql_proxy_client).and_return sql_proxy
      expect(sql_proxy).to receive(:request_images_added_between).with(s_time, e_time, "bucket", "receive_queue")
      described_class.run_schedulable({'polling_offset' => 0})
    end
  end
end