describe OpenChain::PurgeEntry do

  subject { described_class }

  let (:secrets) do
    {
      "kewill_imaging" => {
        "sqs_send_queue" => "send_queue",
        "s3_bucket" => "bucket",
        "sqs_receive_queue" => "queue"
      }
    }
  end

  let! (:ms) do
    stub_master_setup
    allow(MasterSetup).to receive(:secrets).and_return secrets
  end

  describe "run_schedulable" do

    let(:drawback_customer) {Factory.create(:company, drawback_customer: true)}
    let(:non_drawback_customer) {Factory.create(:company, drawback_customer: false)}

    it "executes the purge function with entry IDs which are older than 8 years" do
      e = Factory.create(:entry, release_date: 8.years.ago, importer: drawback_customer)
      expect(subject).to receive(:purge).with [e.id]
      subject.run_schedulable
    end

    it "executes the purge function with entry IDs which are older than 5 years for non drawback customers" do
      e = Factory.create(:entry, release_date: 5.years.ago, importer: non_drawback_customer)
      expect(subject).to receive(:purge).with [e.id]
      subject.run_schedulable
    end

    it "executes the purge function with entry IDs which are older than 5.5 years if release date is missing for non drawback customers" do
      e = Factory.create(:entry, import_date: 6.years.ago, importer: non_drawback_customer)
      expect(subject).to receive(:purge).with [e.id]
      subject.run_schedulable
    end

    it "does not execute the purge function with entry IDs for drawback customers which aren't over 8 years" do
      Factory.create(:entry, import_date: 7.years.ago, importer: drawback_customer)
      expect(subject).to receive(:purge).with []
      subject.run_schedulable
    end
  end

  describe "delete_s3_imaging_files" do
    it "removes files associated with an entry" do
      e = Factory.create(:entry, source_system: "Alliance", broker_reference: "1234asdf")
      expect(OpenChain::S3).to receive(:each_file_in_bucket).with("bucket", max_files: nil, prefix: "KewillImaging/1234asdf")
                                                            .and_yield "KewillImaging/1234asdf/1234zxcv.pdf", "ver"

      expect(OpenChain::S3).to receive(:delete).with("bucket", "KewillImaging/1234asdf/1234zxcv.pdf", "ver")

      subject.delete_s3_imaging_files "bucket", e
    end

    it "does not remove anything if the prefix is empty" do
      e = Factory.create(:entry, source_system: nil, broker_reference: "1234asdf")
      expect(OpenChain::S3).not_to receive(:each_file_in_bucket)
        .with("bucket", max_files: nil, prefix: "KewillImaging/1234asdf")
        .and_yield "KewillImaging/1234asdf/1234zxcv.pdf", "ver"

      expect(OpenChain::S3).not_to receive(:delete).with("bucket", "KewillImaging/1234asdf/1234zxcv.pdf", "ver")

      subject.delete_s3_imaging_files "bucket", e
    end
  end

  describe "purge" do

    let(:e1) { Factory.create(:entry, source_system: "Alliance", broker_reference: "1234asdf") }
    let(:e2) { Factory.create(:entry, source_system: "Alliance", broker_reference: "1234asdf") }

    it "does not call delete_s3_imaging_files if no bucket is present" do
      allow(MasterSetup).to receive(:secrets).and_return "kewill_imaging"

      expect(subject).not_to receive(:delete_s3_imaging_files).with("bucket", e1)
      expect(subject).not_to receive(:delete_s3_imaging_files).with("bucket", e2)

      subject.purge [e1.id, e2.id]
    end

    it "removes entries given their IDs" do
      expect(OpenChain::S3).to receive(:each_file_in_bucket).with("bucket", max_files: nil, prefix: "KewillImaging/1234asdf")
                                                            .and_yield("KewillImaging/1234asdf/1234zxcv.pdf", "ver").twice

      expect(OpenChain::S3).to receive(:delete).with("bucket", "KewillImaging/1234asdf/1234zxcv.pdf", "ver").twice

      subject.purge [e1.id, e2.id]
      expect {e1.reload}.to raise_error ActiveRecord::RecordNotFound
      expect {e2.reload}.to raise_error ActiveRecord::RecordNotFound
    end
  end
end
