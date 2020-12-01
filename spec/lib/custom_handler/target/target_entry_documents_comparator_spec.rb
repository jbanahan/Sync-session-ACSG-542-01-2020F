describe OpenChain::CustomHandler::Target::TargetEntryDocumentsComparator do

  describe "accept?" do

    subject { described_class }

    let (:sync_record) { SyncRecord.new trading_partner: "TARGET_CUSDEC", sent_at: Time.zone.now }
    let (:entry) do
      e = Entry.new customer_number: "TARGEN"
      e.sync_records << sync_record
      e
    end

    let (:snapshot) { EntitySnapshot.new recordable: entry }

    it "accepts Target entries that have already had cusdecs sent" do
      expect(subject.accept?(snapshot)).to eq true
    end

    it "does not accept non-target snapshots" do
      entry.customer_number = "XXX"
      expect(subject.accept?(snapshot)).to eq false
    end

    it "does not accept entries that have not had cusdecs sent" do
      entry.sync_records.clear
      expect(subject.accept?(snapshot)).to eq false
    end

    it "does not accept entries that have had cusdec sent at dates cleared" do
      entry.sync_records.first.sent_at = nil
      expect(subject.accept?(snapshot)).to eq false
    end
  end

  describe "process_new_documents" do

    subject { described_class.new }

    let (:packet_generator) { instance_double(OpenChain::CustomHandler::Target::TargetDocumentPacketZipGenerator) }
    let (:entry) { FactoryBot(:entry, customer_number: "TARGEN", broker_reference: "256") }
    let (:invoice_attachment) { Attachment.create! attachable: entry, attached_file_name: "6789.pdf", attachment_type: "COMMERCIAL INVOICE"}
    let (:usc_doc_attachment) { Attachment.create! attachable: entry, attached_file_name: "12345.pdf", attachment_type: "OTHER USC DOCUMENTS"}

    let (:old_snapshot) do
      {
        "entity" => {
          "core_module" => "Entry",
          "record_id" => entry.id,
          "model_fields" => {
            "ent_brok_ref" => "256",
            "ent_cust_num" => "TARGEN"
          },
          "children" => []
        }
      }
    end

    let (:new_snapshot) do
      {
        "entity" => {
          "core_module" => "Entry",
          "record_id" => entry.id,
          "model_fields" => {
            "ent_brok_ref" => "256",
            "ent_cust_num" => "TARGEN"
          },
          "children" => [
            {
              "entity" => {
                "core_module" => "Attachment",
                "record_id" => usc_doc_attachment.id,
                "model_fields" => {
                  "att_file_name" => "12345.pdf",
                  "att_attachment_type" => "Other USC Documents"
                }
              }
            },
            {
              "entity" => {
                "core_module" => "Attachment",
                "record_id" => invoice_attachment.id,
                "model_fields" => {
                  "att_file_name" => "6789.pdf",
                  "att_attachment_type" => "Commercial Invoice"
                }
              }
            }
          ]
        }
      }
    end

    it "recognizes new documents and sends to packet zip generator" do
      expect(subject).to receive(:target_document_packet_zip_generator).and_return packet_generator
      expect(packet_generator).to receive(:generate_and_send_doc_packs).with(entry, attachments: [usc_doc_attachment, invoice_attachment])

      subject.process_new_documents old_snapshot, new_snapshot
    end

    it "sends nothing if no docs were added" do
      expect(subject).not_to receive(:target_document_packet_zip_generator)
      subject.process_new_documents new_snapshot, new_snapshot
    end

    it "ignores 7501 and non-tdox document types" do
      new_snapshot["entity"]["children"][0]["entity"]["model_fields"]["att_attachment_type"] = "ENTRY SUMMARY - F7501"
      new_snapshot["entity"]["children"][1]["entity"]["model_fields"]["att_attachment_type"] = "Non-TDOX"
      expect(subject).not_to receive(:target_document_packet_zip_generator)

      subject.process_new_documents old_snapshot, new_snapshot
    end

    it "skips entries that have been destroyed since snapshot creation" do
      old_snapshot
      new_snapshot
      entry.destroy
      expect(subject).not_to receive(:target_document_packet_zip_generator)

      subject.process_new_documents old_snapshot, new_snapshot
    end

    it "skips attachments that have been destroyed since snapshot creation" do
      old_snapshot
      new_snapshot
      invoice_attachment.destroy
      expect(subject).to receive(:target_document_packet_zip_generator).and_return packet_generator
      expect(packet_generator).to receive(:generate_and_send_doc_packs).with(entry, attachments: [usc_doc_attachment])

      subject.process_new_documents old_snapshot, new_snapshot
    end
  end

  describe "compare" do
    subject { described_class }

    let (:old_snapshot) { {snapshot: :old} }
    let (:new_snapshot) { {snapshot: :new} }

    it "retrieves snapshot data and calls through to proces method" do
      expect_any_instance_of(subject).to receive(:get_json_hash).with("old_bucket", "old_path", "old_version").and_return old_snapshot
      expect_any_instance_of(subject).to receive(:get_json_hash).with("new_bucket", "new_path", "new_version").and_return new_snapshot
      expect_any_instance_of(subject).to receive(:process_new_documents).with(old_snapshot, new_snapshot)

      subject.compare nil, nil, "old_bucket", "old_path", "old_version", "new_bucket", "new_path", "new_version"
    end
  end
end