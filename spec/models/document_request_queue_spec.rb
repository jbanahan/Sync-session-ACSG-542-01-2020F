describe DocumentRequestQueueItem do

  describe "enqueue_kewill_document_request" do
    subject { described_class }

    it "queues a kewill document request" do
      now = Time.zone.now
      Timecop.freeze(now) { subject.enqueue_kewill_document_request("12345") }

      q = DocumentRequestQueueItem.where(system: "Kewill", identifier: "12345").first
      expect(q).not_to be_nil

      expect(q.request_at.to_i).to eq now.to_i
    end

    it "updates request_at for an item already queued" do
      subject.enqueue_kewill_document_request("12345")

      future = (Time.zone.now + 10.minutes)
      Timecop.freeze(future) { subject.enqueue_kewill_document_request("12345") }

      q = DocumentRequestQueueItem.where(system: "Kewill", identifier: "12345").first
      expect(q).not_to be_nil
      # If the updated at is not equal to the created it it shows that the item was updated
      expect(q.created_at).not_to eq q.updated_at
      expect(q.request_at.to_i).to eq future.to_i
    end

    it "allows adding delay to the request_at time" do
      now = Time.zone.now
      Timecop.freeze(now) { subject.enqueue_kewill_document_request("12345", request_delay_minutes: 5) }

      q = DocumentRequestQueueItem.where(system: "Kewill", identifier: "12345").first
      expect(q).not_to be_nil
      expect(q.request_at.to_i).to eq (now + 5.minutes).to_i
    end
  end

  describe "enqueue_fenix_document_request" do
    subject { described_class }

    it "queues a fenix document request" do
      now = Time.zone.now
      Timecop.freeze(now) { subject.enqueue_fenix_document_request("12345") }

      q = DocumentRequestQueueItem.where(system: "Fenix", identifier: "12345").first
      expect(q).not_to be_nil

      expect(q.request_at.to_i).to eq now.to_i
    end

    it "updates request_at for an item already queued" do
      subject.enqueue_fenix_document_request("12345")

      future = (Time.zone.now + 10.minutes)
      Timecop.freeze(future) { subject.enqueue_fenix_document_request("12345") }

      q = DocumentRequestQueueItem.where(system: "Fenix", identifier: "12345").first
      expect(q).not_to be_nil
      # If the updated at is not equal to the created it it shows that the item was updated
      expect(q.created_at).not_to eq q.updated_at
      expect(q.request_at.to_i).to eq future.to_i
    end

    it "allows adding delay to the request_at time" do
      now = Time.zone.now
      Timecop.freeze(now) { subject.enqueue_fenix_document_request("12345", request_delay_minutes: 5) }

      q = DocumentRequestQueueItem.where(system: "Fenix", identifier: "12345").first
      expect(q).not_to be_nil
      expect(q.request_at.to_i).to eq (now + 5.minutes).to_i
    end
  end

end