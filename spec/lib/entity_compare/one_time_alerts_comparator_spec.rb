describe OpenChain::EntityCompare::OneTimeAlertsComparator do
  describe "compare" do
    let(:ent) { create(:entry, gross_weight: 5, broker_reference: "BROKREF_ABC") }

    let!(:ota) do
      create(:one_time_alert, module_type: "Entry", inactive: false, expire_date: nil,
                               search_criterions: [create(:search_criterion, model_field_uid: "ent_gross_weight", value: 5)])
    end

    before do
      create(:one_time_alert, module_type: "Entry", expire_date: Date.new(2018, 3, 15),
                               search_criterions: [create(:search_criterion, model_field_uid: "ent_gross_weight", value: 5)])
      create(:one_time_alert, module_type: "Entry", expire_date: Date.new(2018, 3, 22),
                               search_criterions: [create(:search_criterion, model_field_uid: "ent_gross_weight", value: 4)])
    end

    it "triggers enabled alerts and takes snapshot for object matching OTA's reference-field criteria" do
      expect_any_instance_of(OneTimeAlert).to receive(:trigger) do |alert, entry|
        expect(alert).to eq ota
        expect(entry).to eq ent
      end
      Timecop.freeze(DateTime.new(2018, 3, 20)) do
        described_class.compare "Entry", ent.id, "old bucket", "old_path", "old_version", "new_bucket", "new path", "new version"
      end
    end

    it "omits 'inactive' OTAs" do
      ota.update! inactive: true
      expect_any_instance_of(OneTimeAlert).not_to receive(:trigger)

      Timecop.freeze(DateTime.new(2018, 3, 20)) do
        described_class.compare "Entry", ent.id, "old bucket", "old_path", "old_version", "new_bucket", "new path", "new version"
      end
    end

    it "skips objects with sync record matching alert" do
      ent.sync_records.create! trading_partner: "one_time_alert", fingerprint: ota.id.to_s

      expect_any_instance_of(OneTimeAlert).not_to receive(:trigger)

      Timecop.freeze(DateTime.new(2018, 3, 20)) do
        described_class.compare "Entry", ent.id, "old bucket", "old_path", "old_version", "new_bucket", "new path", "new version"
      end
    end
  end
end
