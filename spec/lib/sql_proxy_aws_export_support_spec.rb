describe OpenChain::SqlProxyAwsExportSupport do

  describe "aws_file_export_context_data" do

    subject { Class.new { include OpenChain::SqlProxyAwsExportSupport } }

    it "generates a hash suitable to instruct sql proxy server where to send files back to" do 
      expect(subject).to receive(:default_sqs_queue_url).and_return "queue"
      expect(OpenChain::S3).to receive(:integration_bucket_name).and_return "bucket"
      expect(subject.aws_file_export_context_data("path")).to eq({s3_bucket: "bucket", s3_path: "path", sqs_queue: "queue"})
    end

  end

  describe "s3_export_path_from_parser", s3: true do

    subject { Class.new { include OpenChain::SqlProxyAwsExportSupport } }

    let (:parser) {
      d = class_double("SomeParserClass")
      allow(d).to receive(:integration_folder).and_return ["folder", "folder2"]
      d
    }

    it "builds a pathname for s3 export" do
      expect(subject.s3_export_path_from_parser(parser, "ext", path_date: Time.zone.parse("2018-01-01"), filename_prefix: "prefix")).to eq "2018-01/01/folder/prefix-2018-01-01-00-00-00-000.ext"
    end

    it "uses current time if parse date is not given" do
      Timecop.freeze(Time.zone.parse("2018-01-01")) {
        expect(subject.s3_export_path_from_parser(parser, "ext")).to eq "2018-01/01/folder/2018-01-01-00-00-00-000.ext"
      }
    end
  end
end