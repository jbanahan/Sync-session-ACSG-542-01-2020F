describe OpenChain::CustomHandler::Generator315::Abstract315Dispatcher do

  subject do
    Class.new(described_class).new
  end

  describe "process_field" do
    let (:entry) { Factory(:entry, release_date: Time.zone.parse("2015-12-01 12:05")) }
    let (:user) { Factory(:master_user) }
    let (:field) {  {model_field_uid: :ent_release_date } }

    it "returns a milestone update object for a specific model field" do
      milestone = subject.process_field field, user, entry, false, false, []
      expect(milestone.code).to eq "release_date"
      expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York")
      expect(milestone.sync_record.sent_at).to be_within(1.minute).of(Time.zone.now)
      expect(milestone.sync_record.fingerprint).not_to be_nil
      expect(milestone.sync_record.trading_partner).to eq "315_release_date"
      expect(milestone.sync_record.context).to be_empty
    end

    it "returns a milestone update object when a sync_record has been cleared" do
      sr = entry.sync_records.create! trading_partner: "315_release_date"

      milestone = subject.process_field field, user, entry, false, false, []
      expect(milestone.code).to eq "release_date"
      expect(milestone.sync_record).to eq sr
    end

    context "with gtn_time_modifier" do
      it "adds time to sync_record context even when no adjustment is needed" do
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York")
        expect(milestone.sync_record.context).to eq({"milestone_uids" => {"20151201" => [425]}})
      end

      it "increments timestamp by 1 if current one has already been used" do
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [425]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") + 1.minute
        uids = milestone.sync_record.context["milestone_uids"]["20151201"]
        expect(uids.count).to eq 2
        expect(uids[1]).to eq 426
      end

      it "decrements timestamp by 1 if current one and next one have already been used" do
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [425, 426]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") - 1.minute
        uids = milestone.sync_record.context["milestone_uids"]["20151201"]
        expect(uids.count).to eq 3
        expect(uids[2]).to eq 424
      end

      it "increments timestamp by 2 if current and immediately neighboring have already been used" do
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [425, 426, 424]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") + 2.minutes
        uids = milestone.sync_record.context["milestone_uids"]["20151201"]
        expect(uids.count).to eq 4
        expect(uids[3]).to eq 427
      end

      it "decrements timestamp by 2 if current immediate neighbors, and next highest have already been used" do
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [425, 426, 424, 427]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") - 2.minutes
        uids = milestone.sync_record.context["milestone_uids"]["20151201"]
        expect(uids.count).to eq 5
        expect(uids[4]).to eq 423
      end

      it "decrements timestamp if incrementing would change the day" do
        entry.update! release_date: Time.find_zone("Eastern Time (US & Canada)").parse("2015-12-01 23:59")
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [1439]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") - 1.minute
        uids = milestone.sync_record.context["milestone_uids"]["20151201"]
        expect(uids.count).to eq 2
        expect(uids[1]).to eq 1438
      end

      it "increments timestamp if decrementing would change the day" do
        entry.update! release_date: Time.find_zone("Eastern Time (US & Canada)").parse("2015-12-01 00:00")
        # Since increments are always attempted before decrements, setup requires that first increment already exists on the sync record.
        # We're checking that a second one gets made.
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => [0, 1]}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York") + 2.minutes
        uids = milestone.sync_record.context["milestone_uids"]["20151201"]
        expect(uids.count).to eq 3
        expect(uids[2]).to eq 2
      end

      it "adds unmodified time if date has been sent 1440 times" do
        entry.sync_records.create! trading_partner: "315_release_date", context: {"milestone_uids" => {"20151201" => (0..1439).to_a}}.to_json
        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq entry.release_date.in_time_zone("America/New_York")
        uids = milestone.sync_record.context["milestone_uids"]["20151201"]
        expect(uids[1440]).to eq 425
      end

      it "works with regular dates" do
        field.merge! no_time: true

        milestone = subject.process_field field, user, entry, false, true, []
        expect(milestone.date).to eq subject.default_timezone.local(2015, 12, 1, 0, 0)
        expect(milestone.sync_record.context).to eq({"milestone_uids" => {"20151201" => [0]}})

        milestone2 = subject.process_field field, user, entry, false, true, []
        expect(milestone2.date).to eq subject.default_timezone.local(2015, 12, 1, 0, 1)
        expect(milestone2.sync_record.context).to eq({"milestone_uids" => {"20151201" => [0, 1]}})
      end
    end
  end

  context "sync records" do
    let(:sr) { SyncRecord.new  }

    describe "milestone_uids" do
      it "returns uids" do
        sr = SyncRecord.new trading_partner: "ACME", context: {"milestone_uids" => {"20190315" => [1, 2]}}.to_json
        expect(subject.milestone_uids(sr, "20190315")).to eq [1, 2]
        expect(subject.milestone_uids(sr, "20190316")).to be_empty
      end
    end

    describe "set_milestone_uids" do
      it "assigns uid" do
        sr = SyncRecord.new trading_partner: "ACME", context: nil
        subject.set_milestone_uids sr, "20190315", [1, 2]
        expect(sr.context).to eq({"milestone_uids" => {"20190315" => [1, 2]}})

        subject.set_milestone_uids sr, "20190315", [1, 2, 3]
        expect(sr.context).to eq({"milestone_uids" => {"20190315" => [1, 2, 3]}})

        subject.set_milestone_uids sr, "20190316", [4]
        expect(sr.context).to eq({"milestone_uids" => {"20190315" => [1, 2, 3], "20190316" => [4]}})
      end
    end
  end

end
