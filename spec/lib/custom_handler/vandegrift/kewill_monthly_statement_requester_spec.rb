describe OpenChain::CustomHandler::Vandegrift::KewillMonthlyStatementRequester do

  subject { described_class }

  describe "run_schedulable" do

    let (:sql_proxy_client) { 
      c = instance_double(OpenChain::KewillSqlProxyClient)
    }

    let (:aws_data) {
      {s3_bucket: "bucket", s3_path: "path", sqs_queue: "queue"}
    }

    let (:opts) {
      {}
    }

    before :each do 
      allow(subject).to receive(:sql_proxy_client).and_return sql_proxy_client
    end

    it "requests monthly statements updated today or yesterday" do
      date = Time.zone.parse("2017-12-22 12:00")

      expect(sql_proxy_client).to receive(:request_monthly_statements_between).with(Date.new(2017, 12, 21), Date.new(2017, 12, 22), "bucket", "path", "queue", customer_numbers: nil)
      expect(subject).to receive(:aws_context_data).with(date, opts).and_return aws_data

      Timecop.freeze(date) do 
        subject.run_schedulable opts
      end
    end

    it "requests customer numbers" do
      date = Time.zone.parse("2017-12-22 12:00")
      expect(sql_proxy_client).to receive(:request_monthly_statements_between).with(Date.new(2017, 12, 21), Date.new(2017, 12, 22), "bucket", "path", "queue", customer_numbers: ["1", "2"])
      expect(subject).to receive(:aws_context_data).and_return aws_data

      opts[:customer_numbers] = ["1", "2"]
      Timecop.freeze(date) do 
        subject.run_schedulable opts
      end
    end

    it "allows setting start / end dates via opts" do
      expect(sql_proxy_client).to receive(:request_monthly_statements_between).with(Date.new(2017, 12, 01), Date.new(2017, 12, 30), "bucket", "path", "queue", customer_numbers: nil)
      expect(subject).to receive(:aws_context_data).and_return aws_data

      opts[:start_date] = "2017-12-01"
      opts[:end_date] = "2017-12-30"

      subject.run_schedulable opts
    end
  end
end