describe OpenChain::CustomHandler::Vandegrift::KewillStatementRequester do

  subject { described_class }

  describe "run_schedulable" do
    let! (:master_setup) { stub_master_setup }
    let (:start_time) { Time.zone.parse "2017-11-28 15:00"}
    let (:end_time) { Time.zone.parse "2017-11-28 16:00"}
    let (:sql_proxy_client) { 
      c = instance_double(OpenChain::KewillSqlProxyClient)
      c
    }

    before :each do 
      allow(subject).to receive(:poll).and_yield start_time, end_time
      allow(subject).to receive(:sql_proxy_client).and_return sql_proxy_client
      allow(OpenChain::SQS).to receive(:get_queue_url).and_return "test"
      allow(OpenChain::S3).to receive(:integration_bucket_name).and_return "test-bucket"
      allow(OpenChain::S3).to receive(:integration_subfolder_path).with("/home/ubuntu/ftproot/chainroot/test/kewill_statements", end_time).and_return "subfolder/path"
    end

    it "requests updated statements" do
      expect(sql_proxy_client).to receive(:request_updated_statements).with(start_time, end_time, "test-bucket", "subfolder/path/20171128160000000.json", "test", {customer_numbers: nil})
      subject.run_schedulable
    end

    it "uses customer_numbers from opts" do
      expect(sql_proxy_client).to receive(:request_updated_statements).with(start_time, end_time, "test-bucket", "subfolder/path/20171128160000000.json", "test", {customer_numbers: ["A", "B"]})
      subject.run_schedulable({"customer_numbers" => ["A", "B"]})
    end

    it "uses s3_bucket from opts" do
      expect(sql_proxy_client).to receive(:request_updated_statements).with(start_time, end_time, "opts-bucket", "subfolder/path/20171128160000000.json", "test", {customer_numbers: nil})
      subject.run_schedulable({"s3_bucket" => "opts-bucket"})
    end

    it "uses s3_path from opts" do
      expect(sql_proxy_client).to receive(:request_updated_statements).with(start_time, end_time, "test-bucket", "path/from/opts/file.json", "test", {customer_numbers: nil})
      subject.run_schedulable({"s3_path" => "path/from/opts/file.json"})
    end

    it "uses sqs_queue from opts" do
      expect(sql_proxy_client).to receive(:request_updated_statements).with(start_time, end_time, "test-bucket", "subfolder/path/20171128160000000.json", "opts-queue", {customer_numbers: nil})
      subject.run_schedulable({"sqs_queue" => "opts-queue"})
    end
  end
end