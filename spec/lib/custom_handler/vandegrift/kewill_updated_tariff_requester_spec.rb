describe OpenChain::CustomHandler::Vandegrift::KewillUpdatedTariffRequester do

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
      allow(sql_proxy_client).to receive(:aws_context_hash).with("json", path_date: instance_of(ActiveSupport::TimeWithZone), parser_identifier: "kewill_tariffs").and_return({s3_bucket: "test-bucket", s3_path: "test-path", sqs_queue: "test-queue"})
      allow(OpenChain::SQS).to receive(:get_queue_url).and_return "test"
      allow(OpenChain::S3).to receive(:integration_bucket_name).and_return "test-bucket"
      allow(OpenChain::S3).to receive(:integration_subfolder_path).with("test/kewill_tariffs", end_time).and_return "subfolder/path"
    end

    it "requests updated tariffs" do
      expect(sql_proxy_client).to receive(:request_updated_tariff_classifications).with(start_time, end_time, "test-bucket", "test-path", "test-queue")
      subject.run_schedulable
    end

    it "uses s3_bucket from opts" do
      expect(sql_proxy_client).to receive(:request_updated_tariff_classifications).with(start_time, end_time, "opts-bucket", "test-path", "test-queue")
      subject.run_schedulable({"s3_bucket" => "opts-bucket"})
    end

    it "uses s3_path from opts" do
      expect(sql_proxy_client).to receive(:request_updated_tariff_classifications).with(start_time, end_time, "test-bucket", "path/from/opts/file.json", "test-queue")
      subject.run_schedulable({"s3_path" => "path/from/opts/file.json"})
    end

    it "uses sqs_queue from opts" do
      expect(sql_proxy_client).to receive(:request_updated_tariff_classifications).with(start_time, end_time, "test-bucket", "test-path", "opts-queue")
      subject.run_schedulable({"sqs_queue" => "opts-queue"})
    end
  end
end