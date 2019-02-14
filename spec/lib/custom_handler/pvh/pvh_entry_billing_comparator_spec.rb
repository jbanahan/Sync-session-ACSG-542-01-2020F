describe OpenChain::CustomHandler::Pvh::PvhEntryBillingComparator do 

  subject { described_class }

  describe "accept?" do
    
    
    let (:snapshot) { 
      s = EntitySnapshot.new
      s.recordable = entry
      s
    }

    # This whole context can be deleted once we're done w/ live testing
    context "with billing testing enabled" do
      let (:entry) { Entry.new file_logged_date: Date.new(2019, 1, 1), house_bills_of_lading: "BILLINGTEST", customer_number: "PVH" }
      let (:master_setup) {
        ms = stub_master_setup
        expect(ms).to receive(:custom_feature?).with("PVH Billing Testing").and_return true
        ms
      }

      ["PVHCANADA", "PVH", "PVHNE", "PVHCA"].each do |cust|
        it "accepts #{cust} snapshots" do
          entry.customer_number = cust
          expect(subject.accept? snapshot).to eq true
        end

        it "does not accept #{cust} snapshots prior to 2019" do
          entry.file_logged_date = Date.new(2018, 11, 30)
          expect(subject.accept? snapshot).to eq false
        end
      end

      it "does not accept non-PVH entries" do
        entry.customer_number = "NOTPVH"
        expect(subject.accept? snapshot).to eq false
      end

      it "accepts with container of billingtest" do
        entry.house_bills_of_lading = nil
        entry.container_numbers = "BILLINGTEST"
        expect(subject.accept? snapshot).to eq true
      end
    end

    context "without billing testing enabled" do
      let (:entry) { Entry.new file_logged_date: Date.new(2019, 1, 1), customer_number: "PVH" }

      let (:master_setup) {
        ms = stub_master_setup
        expect(ms).to receive(:custom_feature?).with("PVH Billing Testing").and_return false
        ms
      }

      ["PVHCANADA", "PVH", "PVHNE", "PVHCA"].each do |cust|
        it "accepts #{cust} snapshots" do
          entry.customer_number = cust
          expect(subject.accept? snapshot).to eq true
        end

        it "does not accept #{cust} snapshots prior to 2019" do
          entry.file_logged_date = Date.new(2018, 11, 30)
          expect(subject.accept? snapshot).to eq false
        end
      end

      it "does not accept non-PVH entries" do
        entry.customer_number = "NOTPVH"
        expect(subject.accept? snapshot).to eq false
      end
    end
  end


  describe "compare" do
    let (:snapshot_hash) {
      {
        "model_fields" => {
          "ent_cntry_iso" => "US"
        }
      }
    }

    it "retrieves snapshot and sends to US generator" do
      expect(subject).to receive(:get_json_hash).with("bucket", "path", "version").and_return snapshot_hash
      g = instance_double(OpenChain::CustomHandler::Pvh::PvhUsBillingInvoiceFileGenerator)
      expect(subject).to receive(:pvh_us_generator).and_return g
      expect(g).to receive(:generate_and_send).with(snapshot_hash)

      subject.compare nil, nil, nil, nil, nil, "bucket", "path", "version"
    end

    it "retrieves snapshot and sends to CA generator" do
      snapshot_hash["model_fields"]["ent_cntry_iso"] = "CA"

      expect(subject).to receive(:get_json_hash).with("bucket", "path", "version").and_return snapshot_hash
      g = instance_double(OpenChain::CustomHandler::Pvh::PvhCanadaBillingInvoiceFileGenerator)
      expect(subject).to receive(:pvh_ca_generator).and_return g
      expect(g).to receive(:generate_and_send).with(snapshot_hash)

      subject.compare nil, nil, nil, nil, nil, "bucket", "path", "version"
    end
  end
end