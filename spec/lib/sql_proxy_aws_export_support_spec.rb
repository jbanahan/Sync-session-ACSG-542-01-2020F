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

  describe "s3_export_path_from_parser_identifier", s3: true do

    subject { Class.new { include OpenChain::SqlProxyAwsExportSupport } }

    it "builds a pathname for s3 export" do
      expect(subject.s3_export_path_from_parser_identifier("some_parser_id", "ext", system_code: "system", path_date: Time.zone.parse("2018-01-01"), filename_prefix: "prefix")).to eq "2018-01/01/system/some_parser_id/prefix-2018-01-01-00-00-00-000.ext"
    end

    it "uses current time if parse date is not given" do
      Timecop.freeze(Time.zone.parse("2018-01-01")) {
        expect(subject.s3_export_path_from_parser_identifier("some_parser_id", "ext", system_code: "system")).to eq "2018-01/01/system/some_parser_id/2018-01-01-00-00-00-000.ext"
      }
    end

    it "uses current system code by default" do
      stub_master_setup
      expect(subject.s3_export_path_from_parser_identifier("some_parser_id", "ext", path_date: Time.zone.parse("2018-01-01"), filename_prefix: "prefix")).to eq "2018-01/01/test/some_parser_id/prefix-2018-01-01-00-00-00-000.ext"
    end

    it "raises an error if system code is blank" do
      expect { subject.s3_export_path_from_parser_identifier "id", "ext", system_code: ""}.to raise_error "Unable to construct accurate s3 export path when system code is blank."
    end
  end
end