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
      allow(sql_proxy_client).to receive(:aws_context_hash).with("json", path_date: instance_of(ActiveSupport::TimeWithZone), parser_class: OpenChain::CustomHandler::Vandegrift::KewillStatementParser).and_return({s3_bucket: "test-bucket", s3_path: "test-path", sqs_queue: "test-queue"})
      allow(OpenChain::SQS).to receive(:get_queue_url).and_return "test"
      allow(OpenChain::S3).to receive(:integration_bucket_name).and_return "test-bucket"
      allow(OpenChain::S3).to receive(:integration_subfolder_path).with("/home/ubuntu/ftproot/chainroot/test/kewill_statements", end_time).and_return "subfolder/path"
    end

    it "requests updated statements" do
      expect(sql_proxy_client).to receive(:request_updated_statements).with(start_time, end_time, "test-bucket", "test-path", "test-queue", {customer_numbers: nil})
      subject.run_schedulable
    end

    it "uses customer_numbers from opts" do
      expect(sql_proxy_client).to receive(:request_updated_statements).with(start_time, end_time, "test-bucket", "test-path", "test-queue", {customer_numbers: ["A", "B"]})
      subject.run_schedulable({"customer_numbers" => ["A", "B"]})
    end

    it "uses s3_bucket from opts" do
      expect(sql_proxy_client).to receive(:request_updated_statements).with(start_time, end_time, "opts-bucket", "test-path", "test-queue", {customer_numbers: nil})
      subject.run_schedulable({"s3_bucket" => "opts-bucket"})
    end

    it "uses s3_path from opts" do
      expect(sql_proxy_client).to receive(:request_updated_statements).with(start_time, end_time, "test-bucket", "path/from/opts/file.json", "test-queue", {customer_numbers: nil})
      subject.run_schedulable({"s3_path" => "path/from/opts/file.json"})
    end

    it "uses sqs_queue from opts" do
      expect(sql_proxy_client).to receive(:request_updated_statements).with(start_time, end_time, "test-bucket", "test-path", "opts-queue", {customer_numbers: nil})
      subject.run_schedulable({"sqs_queue" => "opts-queue"})
    end
  end

  describe "request_daily_statements" do
    let! (:sql_proxy_client) {
      c = instance_double(OpenChain::KewillSqlProxyClient)
      allow(subject).to receive(:sql_proxy_client).and_return c
      c
    }

    it "requests daily statements via sql proxy client" do
      now = Time.zone.now
      expect(subject).to receive(:aws_context_data).with(sql_proxy_client, now, {}).and_return({s3_bucket: "bucket", s3_path: "path", sqs_queue: "queue"})
      expect(sql_proxy_client).to receive(:request_daily_statements).with(["A", "B"], "bucket", "path", "queue")
      Timecop.freeze(now) { subject.request_daily_statements ["A", "B"] }
    end
  end

  describe "request_monthly_statements" do
    let! (:sql_proxy_client) {
      c = instance_double(OpenChain::KewillSqlProxyClient)
      allow(subject).to receive(:sql_proxy_client).and_return c
      c
    }

    it "requests monthly statements via sql proxy client" do
      now = Time.zone.now
      expect(subject).to receive(:aws_context_data).with(sql_proxy_client, now, {}).and_return({s3_bucket: "bucket", s3_path: "path", sqs_queue: "queue"})
      expect(sql_proxy_client).to receive(:request_monthly_statements).with(["A", "B"], "bucket", "path", "queue")
      Timecop.freeze(now) { subject.request_monthly_statements ["A", "B"] }
    end
  end
end