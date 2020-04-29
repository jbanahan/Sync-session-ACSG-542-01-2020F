describe OpenChain::CustomHandler::Vandegrift::EntryAttachmentStitchRequestComparator do
  let (:importer) { Factory(:importer) }

  let! (:archive_setup) {
    AttachmentArchiveSetup.create! company_id: importer.id, combine_attachments: true, combined_attachment_order: "B\nA"
  }

  let (:entry) {
    e = Factory(:entry, importer: archive_setup.company)
    e.broker_invoices.create! invoice_number: "INV"
    e
  }

  let (:user) {
    Factory(:user)
  }

  let (:snapshot) {
    entry.create_snapshot user
  }

  describe "accept?" do
    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("Document Stitching").and_return true
      ms
    }

    subject { described_class }

    it "accepts entry snapshots linked to importers with archive setups with combine attachments enabled" do
      expect(subject.accept? snapshot).to eq true
    end

    it "does not accept snapshots for importers without archive setups" do
      entry.update_attributes! importer_id: Factory(:importer).id
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept snapshots for importers that don't combine attachments" do
      archive_setup.update_attributes! combine_attachments: nil
      expect(subject.accept? snapshot).to eq false
    end

    it "does not accept snapshots when Document Stitching is not enabled" do
      expect(master_setup).to receive(:custom_feature?).with("Document Stitching").and_return false
      expect(subject.accept? snapshot).to eq false
    end

    it "accepts snapshots with importers that have parent attachment setups" do
      parent = Factory(:company)
      parent.linked_companies << importer
      archive_setup.update! company_id: parent.id
      expect(subject.accept? snapshot).to eq true
    end
  end

  describe "compare" do
    before :each do
      allow(subject).to receive(:sqs_queue).and_return "queue"
    end

    it "determines if any new attachments were added then generates and sends a stitch request" do
      old_snapshot = snapshot_json(entry)
      entry.attachments.create! attachment_type: "A", attached_file_name: "file.pdf"
      new_snapshot = snapshot_json(entry)
      expect(OpenChain::SQS).to receive(:send_json).with("queue", instance_of(Hash))

      subject.compare old_snapshot, new_snapshot
    end

    it "uses parent's archive setup" do
      parent = Factory(:company)
      parent.linked_companies << importer
      archive_setup.update! company_id: parent.id

      old_snapshot = snapshot_json(entry)
      entry.attachments.create! attachment_type: "A", attached_file_name: "file.pdf"
      new_snapshot = snapshot_json(entry)
      expect(OpenChain::SQS).to receive(:send_json).with("queue", instance_of(Hash))

      subject.compare old_snapshot, new_snapshot
    end

    it "determines if any new attachments were removed then generates and sends a stitch request" do
      entry.attachments.create! attachment_type: "A", attached_file_name: "file.pdf"
      entry.attachments.create! attachment_type: "B", attached_file_name: "file2.pdf"
      old_snapshot = snapshot_json(entry)
      entry.attachments.first.destroy
      entry.reload
      new_snapshot = snapshot_json(entry)
      expect(OpenChain::SQS).to receive(:send_json).with("queue", instance_of(Hash))

      subject.compare old_snapshot, new_snapshot
    end

    it "does nothing if no new attachments were added" do
      entry.attachments.create! attachment_type: "A", attached_file_name: "file.pdf"
      old_snapshot = snapshot_json(entry)
      new_snapshot = snapshot_json(entry)
      expect(OpenChain::SQS).not_to receive(:send_json)

      subject.compare old_snapshot, new_snapshot
    end

    it "deletes the archive packet if there's no archivable attachments left" do
      archive = entry.attachments.create! attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE, attached_file_name: "archive.pdf"
      a = entry.attachments.create! attachment_type: "A", attached_file_name: "file.pdf"
      old_snapshot = snapshot_json(entry)
      a.destroy
      entry.attachments.reload
      new_snapshot = snapshot_json(entry)
      expect(OpenChain::SQS).not_to receive(:send_json)

      subject.compare old_snapshot, new_snapshot

      expect(archive).not_to exist_in_db
      entry.reload
      expect(entry.attachments.find {|a| a.attachment_type == Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE}).to be_nil
      expect(entry.entity_snapshots.length).to eq 1
    end

    it "does nothing if added attachment was private" do
      old_snapshot = snapshot_json(entry)
      entry.attachments.create! attachment_type: "A", attached_file_name: "file.pdf", is_private: true
      new_snapshot = snapshot_json(entry)
      expect(OpenChain::SQS).not_to receive(:send_json)

      subject.compare old_snapshot, new_snapshot
    end

    it "does nothing if removed attachment was private" do
      entry.attachments.create! attachment_type: "A", attached_file_name: "file.pdf", is_private: true
      entry.attachments.create! attachment_type: "B", attached_file_name: "file2.pdf"
      old_snapshot = snapshot_json(entry)
      entry.attachments.first.destroy
      entry.reload
      new_snapshot = snapshot_json(entry)
      expect(OpenChain::SQS).not_to receive(:send_json)

      subject.compare old_snapshot, new_snapshot
    end

    it "rebuilds deleted archive packets" do
      archive = entry.attachments.create! attachment_type: Attachment::ARCHIVE_PACKET_ATTACHMENT_TYPE, attached_file_name: "archive.pdf"
      a = entry.attachments.create! attachment_type: "A", attached_file_name: "file.pdf"
      old_snapshot = snapshot_json(entry)
      archive.destroy
      entry.reload
      new_snapshot = snapshot_json(entry)

      expect(OpenChain::SQS).to receive(:send_json).with("queue", instance_of(Hash))

      subject.compare old_snapshot, new_snapshot
    end
  end

  describe "generate_stitch_request_for_entry" do
    let (:now) { Time.zone.now }
    let! (:a1) { entry.attachments.create! attachment_type: "A", attached_file_name: "file.pdf" }
    let! (:a2) { entry.attachments.create! attachment_type: "B", attached_file_name: "file.pdf" }

    before :each do
      stub_master_setup
    end

    it "generates valid stitch request, ordering files according to the setup" do
      stitch_request = nil
      Timecop.freeze(now) do
        stitch_request = subject.generate_stitch_request_for_entry entry, archive_setup
      end
      expect(stitch_request).to eq({
        'stitch_request' => {
          'source_files' => [
            {'path' => "/chain-io/test-uuid/attachment/#{a2.id}/#{a2.attached_file_name}", 'service' => "s3"},
            {'path' => "/chain-io/test-uuid/attachment/#{a1.id}/#{a1.attached_file_name}", 'service' => "s3"}
          ],
          'reference_info' => {
            'key'=>"Entry-#{entry.id}",
            'time'=>now.iso8601
          },
          'destination_file' => {'path' => "/chain-io/test-uuid/stitched/Entry-#{entry.id}-#{now.to_f}.pdf", 'service' => "s3"}
        }
      })
    end

    it 'orders multiple of the same attachment types by updated_at ASC' do
      a2.update_attributes! attachment_type: a1.attachment_type
      a2.update_column :updated_at, 1.year.ago

      stitch_request = subject.generate_stitch_request_for_entry entry, archive_setup

      expect(stitch_request['stitch_request']['source_files']).to eq [
        {'path' => "/chain-io/test-uuid/attachment/#{a2.id}/#{a2.attached_file_name}", 'service' => "s3"},
        {'path' => "/chain-io/test-uuid/attachment/#{a1.id}/#{a1.attached_file_name}", 'service' => "s3"}
      ]
    end

    it 'orders attachment types not in combined_attachment_order by updated date' do
      a2.update_attributes! attachment_type: ""
      a2.update_column :updated_at, 1.year.ago
      a3 = entry.attachments.create! attached_file_name: "test3.pdf", attachment_type: ""

      stitch_request = subject.generate_stitch_request_for_entry entry, archive_setup

      expect(stitch_request['stitch_request']['source_files']).to eq [
        {'path' => "/chain-io/test-uuid/attachment/#{a1.id}/#{a1.attached_file_name}", 'service' => "s3"},
        {'path' => "/chain-io/test-uuid/attachment/#{a2.id}/#{a2.attached_file_name}", 'service' => "s3"},
        {'path' => "/chain-io/test-uuid/attachment/#{a3.id}/#{a3.attached_file_name}", 'service' => "s3"}
      ]
    end

    it "skips attachment types not in combined_attachment_order if flag is set" do
      archive_setup.update_attributes! include_only_listed_attachments: true
      entry.attachments.create! attached_file_name: "test3.pdf", attachment_type: "C"

      stitch_request = subject.generate_stitch_request_for_entry entry, archive_setup

      expect(stitch_request['stitch_request']['source_files']).to eq [
        {'path' => "/chain-io/test-uuid/attachment/#{a2.id}/#{a2.attached_file_name}", 'service' => "s3"},
        {'path' => "/chain-io/test-uuid/attachment/#{a1.id}/#{a1.attached_file_name}", 'service' => "s3"}
      ]
    end

    it 'skips non image formats' do
      a2.update_attributes! attached_file_name: "file.zip"
      stitch_request = subject.generate_stitch_request_for_entry entry, archive_setup

      expect(stitch_request['stitch_request']['source_files']).to eq [
        {'path' => "/chain-io/test-uuid/attachment/#{a1.id}/#{a1.attached_file_name}", 'service' => "s3"}
      ]
    end

    it "skips private attachments" do
      a2.update_attributes! is_private: true
      stitch_request = subject.generate_stitch_request_for_entry entry, archive_setup

      expect(stitch_request['stitch_request']['source_files']).to eq [
        {'path' => "/chain-io/test-uuid/attachment/#{a1.id}/#{a1.attached_file_name}", 'service' => "s3"}
      ]
    end

    it 'returns blank when no attachments need to be sent' do
      entry.attachments.update_all attached_file_name: "file.zip"

      expect(subject.generate_stitch_request_for_entry entry, archive_setup).to eq({})
    end
  end
end