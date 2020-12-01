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

    let(:drawback_customer) {FactoryBot.create(:company, drawback_customer: true)}
    let(:non_drawback_customer) {FactoryBot.create(:company, drawback_customer: false)}

  describe "purge" do

  end
    end
      end
        subject.run_schedulable({"years_old" => 10})
      Timecop.freeze(now) do

      expect(subject).to receive(:purge).with(older_than: start_date)
      start_date = now.in_time_zone("America/New_York").beginning_of_day - 10.years
    it "uses alternate years_old value" do
    let (:now) { Time.zone.now }

    it "executes the purge function" do
      start_date = now.in_time_zone("America/New_York").beginning_of_day - 5.years
      expect(subject).to receive(:purge).with(older_than: start_date)

        subject.run_schedulable({})
    end

      Timecop.freeze(now) do
      end

    it "executes the purge function with entry IDs which are older than 8 years" do
      e = FactoryBot.create(:entry, release_date: 8.years.ago, importer: drawback_customer)
      expect(subject).to receive(:purge).with [e.id]
      subject.run_schedulable
    end

    it "executes the purge function with entry IDs which are older than 5 years for non drawback customers" do
      e = FactoryBot.create(:entry, release_date: 5.years.ago, importer: non_drawback_customer)
      expect(subject).to receive(:purge).with [e.id]
      subject.run_schedulable
    end

    it "executes the purge function with entry IDs which are older than 5.5 years if release date is missing for non drawback customers" do
      e = FactoryBot.create(:entry, import_date: 6.years.ago, importer: non_drawback_customer)
      expect(subject).to receive(:purge).with [e.id]
      subject.run_schedulable
    end

    it "does not execute the purge function with entry IDs for drawback customers which aren't over 8 years" do
      FactoryBot.create(:entry, import_date: 7.years.ago, importer: drawback_customer)
      expect(subject).to receive(:purge).with []
      subject.run_schedulable
    end
  end

  describe "delete_s3_imaging_files" do
    it "removes files associated with an entry" do
      e = FactoryBot.create(:entry, source_system: "Alliance", broker_reference: "1234asdf")
      expect(OpenChain::S3).to receive(:each_file_in_bucket).with("bucket", max_files: nil, prefix: "KewillImaging/1234asdf")
                                                            .and_yield "KewillImaging/1234asdf/1234zxcv.pdf", "ver"

      expect(OpenChain::S3).to receive(:delete).with("bucket", "KewillImaging/1234asdf/1234zxcv.pdf", "ver")

      subject.delete_s3_imaging_files "bucket", e
    end

    it "does not remove anything if the prefix is empty" do
      e = FactoryBot.create(:entry, source_system: nil, broker_reference: "1234asdf")
      expect(OpenChain::S3).not_to receive(:each_file_in_bucket)

      expect(OpenChain::S3).not_to receive(:delete).with("bucket", "KewillImaging/1234asdf/1234zxcv.pdf", "ver")

      subject.delete_s3_imaging_files "bucket", e
    end
  end

  describe "purge_entry_ids" do

    let(:e1) { FactoryBot.create(:entry, source_system: "Alliance", broker_reference: "1234asdf") }
    let(:e2) { FactoryBot.create(:entry, source_system: "Alliance", broker_reference: "1234asdf") }

    it "does not call delete_s3_imaging_files if no bucket is present" do
      allow(MasterSetup).to receive(:secrets).and_return "kewill_imaging"

      expect(subject).not_to receive(:delete_s3_imaging_files).with("bucket", e1)
      expect(subject).not_to receive(:delete_s3_imaging_files).with("bucket", e2)

      subject.purge_entry_ids [e1.id, e2.id]
    end

    it "removes entries given their IDs" do
      expect(OpenChain::S3).to receive(:each_file_in_bucket).with("bucket", max_files: nil, prefix: "KewillImaging/1234asdf", list_versions: true)
                                                            .and_yield("KewillImaging/1234asdf/1234zxcv.pdf", "ver").twice

      expect(OpenChain::S3).to receive(:delete).with("bucket", "KewillImaging/1234asdf/1234zxcv.pdf", "ver").twice

      subject.purge_entry_ids [e1.id, e2.id]
      expect(e1).not_to exist_in_db
      expect(e2).not_to exist_in_db
    end
  end
end
