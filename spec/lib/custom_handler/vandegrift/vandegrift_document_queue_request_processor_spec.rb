describe OpenChain::CustomHandler::Vandegrift::VandegriftDocumentQueueRequestProcessor do

  subject { described_class }

  describe "process_document_request_queue" do 
    let (:kewill_item) { DocumentRequestQueueItem.create! system: "KeWiLL", identifier: "12345", request_at: Time.zone.now }
    let (:fenix_item) { DocumentRequestQueueItem.create! system: "FeNiX", identifier: "12345", request_at: Time.zone.now }
    let (:secrets) { 
      {
        "kewill_imaging" => {
          "s3_bucket" => "bucket",
          "sqs_receive_queue" => "queue"
        }
      }
    }
    let! (:imaging_config) { 
      expect(MasterSetup).to receive(:secrets).and_return secrets
    }

    it "does nothing if no documents are requested" do
      expect(subject.process_document_request_queue).to eq 0
    end

    it "processes kewill item" do
      now = (Time.zone.now + 10.minutes)

      expect(subject).to receive(:request_kewill_images_for_queue_item) do |queue_item, config|
        expect(config).to eq secrets["kewill_imaging"]
        expect(queue_item).to eq kewill_item
        # Verify the queue item is locked w/ expected values
        expect(queue_item.locked_at.to_i).to eq now.to_i
        expect(queue_item.locked_by).to eq "VandegriftDocumentQueueRequestProcessor:#{Process.pid}"
      end

      kewill_item

      Timecop.freeze(now) { expect(subject.process_document_request_queue).to eq 1 }

      # The item should have been deleted from the queue
      expect(kewill_item).not_to exist_in_db
    end

    it "processes fenix item" do
      now = (Time.zone.now + 10.minutes)

      expect(subject).to receive(:request_fenix_images_for_queue_item) do |queue_item, config|
        expect(config).to eq secrets["kewill_imaging"]
        expect(queue_item).to eq fenix_item
        # Verify the queue item is locked w/ expected values
        expect(queue_item.locked_at.to_i).to eq now.to_i
        expect(queue_item.locked_by).to eq "VandegriftDocumentQueueRequestProcessor:#{Process.pid}"
      end

      fenix_item

      Timecop.freeze(now) { expect(subject.process_document_request_queue).to eq 1 }

      # The item should have been deleted from the queue
      expect(fenix_item).not_to exist_in_db
    end

    it "skips items that have request_at times in the future" do
      kewill_item
      now = (Time.zone.now - 1.minute)
      expect(subject).not_to receive(:request_kewill_images_for_queue_item)

      Timecop.freeze(now) { expect(subject.process_document_request_queue).to eq 0 }
    end

    it "skips items that are for different systems than those specified" do
      kewill_item
      now = (Time.zone.now + 10.minutes)
      expect(subject).not_to receive(:request_kewill_images_for_queue_item)

      Timecop.freeze(now) { expect(subject.process_document_request_queue system: "fenix").to eq 0 }
    end

    it "handles errors raised by request" do
      error = StandardError.new("Error")
      expect(subject).to receive(:request_kewill_images_for_queue_item).with(kewill_item, secrets["kewill_imaging"]).and_raise error
      expect(error).to receive(:log_me).with("Failed to process document request for system 'KeWiLL' with identifier '12345'.")

      now = (Time.zone.now + 10.minutes)
      Timecop.freeze(now) { expect(subject.process_document_request_queue).to eq 0 }

      expect(kewill_item).to exist_in_db
      kewill_item.reload
      expect(kewill_item.request_at.to_i).to eq((now + 1.minute).to_i)
    end

    it "handles errors raised by invalid systems being found" do
      kewill_item.update! system: "notkewill"

      expect_any_instance_of(described_class::InvalidQueueSystemError).to receive(:log_me) do |instance|
        expect(instance.message).to eq "Invalid document request queue item received with system 'notkewill' with identifier '12345'."
      end
      now = (Time.zone.now + 10.minutes)
      Timecop.freeze(now) { expect(subject.process_document_request_queue).to eq 0 }
      expect(kewill_item).not_to exist_in_db
    end
  end

  describe "request_kewill_images_for_queue_item" do
    let (:queue_item) { DocumentRequestQueueItem.new system: "kewill", identifier: "12345"}
    let (:secrets) { 
      {
        "kewill_imaging" => {
          "s3_bucket" => "bucket",
          "sqs_receive_queue" => "queue"
        }
      }
    }

    it "passes request through to kewill proxy client" do
      expect_any_instance_of(OpenChain::KewillImagingSqlProxyClient).to receive(:request_images_for_file).with("12345", "bucket", "queue")
      subject.request_kewill_images_for_queue_item queue_item, secrets["kewill_imaging"]
    end
  end

  describe "request_fenix_images_for_queue_item" do
    let (:queue_item) { DocumentRequestQueueItem.new system: "fenix", identifier: "12345"}
    let (:secrets) { 
      {
        "kewill_imaging" => {
          "s3_bucket" => "bucket",
          "sqs_receive_queue" => "queue"
        }
      }
    }

    it "passes request through to kewill proxy client" do
      expect_any_instance_of(OpenChain::FenixSqlProxyClient).to receive(:request_images_for_transaction_number).with("12345", "bucket", "queue")
      subject.request_fenix_images_for_queue_item queue_item, secrets["kewill_imaging"]
    end
  end

  describe "run_schedulable" do
    it "passes through schedulable opts to process_document_request_queue method" do
      expect(subject).to receive(:process_document_request_queue).with(system: "system")
      subject.run_schedulable({"wait_time_minutes" => 10, "system" => "system"})
    end

    it "handles no opts" do
      expect(subject).to receive(:process_document_request_queue).with(system: nil)
      subject.run_schedulable
    end
  end
end