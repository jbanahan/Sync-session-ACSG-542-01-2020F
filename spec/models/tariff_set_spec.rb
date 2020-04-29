describe TariffSet do
  describe 'activate' do
    before :each do
      @c1 = Factory(:country)
      @c2 = Factory(:country)
    end

    it "replaces official tariff" do
      should_be_gone = OfficialTariff.create!(:country_id => @c1.id, :hts_code => "1234567890", :full_description => "FD1")
      should_be_changed = OfficialTariff.create!(:country_id => @c1.id, :hts_code => "1234555555", :full_description => "FD3")
      should_stay = OfficialTariff.create!(:country_id => @c2.id, :hts_code => should_be_gone.hts_code, :full_description => "FD2")

      old_ts = TariffSet.create!(:country_id => @c1.id, :label => "oldts", :active => true)

      ts = TariffSet.create!(:country_id => @c1.id, :label => "newts")
      r = ts.tariff_set_records
      r.create!(:country_id => @c1.id, :hts_code => should_be_changed.hts_code, :full_description => "changed_desc")
      r.create!(:country_id => @c1.id, :hts_code => "9999999999")

      expect(OfficialQuota).to receive(:relink_country).with(@c1)
      log = double("LOG LOG LOG")
      expect(OpenChain::OfficialTariffProcessor::TariffProcessor).to receive(:process_country).with(@c1, log)
      expect(Lock).to receive(:acquire).with("OfficialTariff-#{@c1.iso_code}").and_yield

      ts.activate(nil, log)

      found = OfficialTariff.where(:country_id => @c1.id)

      expect(found.size).to eq(2)
      expect(OfficialTariff.where(:country_id => @c1.id, :hts_code => "1234555555").first.full_description).to eq("changed_desc")
      expect(OfficialTariff.where(:country_id => @c1.id, :hts_code => "9999999999").first).not_to be_nil
      expect(OfficialTariff.where(:country_id => @c2.id, :hts_code => should_stay.hts_code).first).not_to be_nil
      expect(OfficialTariff.where(:country_id => @c1.id, :hts_code => should_be_gone.hts_code).first).to be_nil
      expect(TariffSet.find(old_ts.id)).not_to be_active # should have deactivated old tariff set for same country
      expect(TariffSet.find(ts.id)).to be_active # should have activated this tariff set
    end

    it 'queues jobs to notify users of update' do
      u = Factory(:user)
      expect(u).not_to be_nil
      c = @c1
      ts = TariffSet.create!(:country_id => c.id, :label => "newts")
      expect(described_class).to receive(:delay).exactly(2).times.and_return described_class
      expect(described_class).to receive(:notify_user_of_tariff_set_update).with ts.id, u.id
      expect(described_class).to receive(:notify_of_tariff_set_update).with ts.id

      ts.activate u
    end
  end

  describe 'compare' do
    it "returns array of results" do
      c = Factory(:country, :iso_code=>'US')
      old = TariffSet.create!(:country_id => c.id, :label => "old")
      new_ts = TariffSet.create!(:country_id => c.id, :label => "new")

      # will be removed
      old.tariff_set_records.create!(:hts_code => "123", :country_id => old.country_id)
      # will be changed
      old.tariff_set_records.create!(:hts_code => "345", :full_description => "abc", :country_id => old.country_id)
      # will stay the same
      old.tariff_set_records.create!(:hts_code => "901", :full_description => "xyz", :country_id => old.country_id)

      # changed
      new_ts.tariff_set_records.create!(:hts_code => "345", :full_description => "def", :country_id => new_ts.country_id)
      # added
      new_ts.tariff_set_records.create!(:hts_code => "567", :country_id => new_ts.country_id)
      # stayed the same
      new_ts.tariff_set_records.create!(:hts_code => "901", :full_description => "xyz", :country_id => new_ts.country_id)

      added, removed, changed = new_ts.compare old

      expect(added.size).to eq(1)
      expect(added.first.hts_code).to eq("567")

      expect(removed.size).to eq(1)
      expect(removed.first.hts_code).to eq("123")

      expect(changed.size).to eq(1)
      expect(changed["345"][0]["full_description"]).to eq("def")
      expect(changed["345"][1]["full_description"]).to eq("abc")
    end
  end

  describe "notify_of_tariff_set_update" do
    let! (:user) { Factory(:user, email: "me@there.com", tariff_subscribed: true) }
    let! (:tariff_set) { TariffSet.create! country: Factory(:country), label: "TariffSet" }
    subject { described_class }

    it "notifies subscribed users of tariff set updates" do
      mail = instance_double("ActionMailer::MessageDelivery")
      expect(OpenMailer).to receive(:send_tariff_set_change_notification).with(tariff_set, user).and_return mail
      expect(mail).to receive(:deliver_later)

      subject.notify_of_tariff_set_update tariff_set.id
    end

    it "does not notify unsubscribed users" do
      user.update_attributes! tariff_subscribed: false
      expect(OpenMailer).not_to receive(:send_tariff_set_change_notification)
      subject.notify_of_tariff_set_update tariff_set.id
    end

    it "does not notify disabled users" do
      user.disabled = true
      user.save!
      expect(OpenMailer).not_to receive(:send_tariff_set_change_notification)
      subject.notify_of_tariff_set_update tariff_set.id
    end
  end

  describe "notify_user_of_tariff_set_update" do
    let! (:user) { Factory(:user, email: "me@there.com", tariff_subscribed: true) }
    let! (:tariff_set) { TariffSet.create! country: Factory(:country), label: "TariffSet" }
    subject { described_class }

    it "sends system message to user about tariff set update" do
      subject.notify_user_of_tariff_set_update tariff_set.id, user.id

      m = user.messages.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "Tariff Set TariffSet activated."
      expect(m.body).to eq "Tariff Set TariffSet has been successfully activated."
    end
  end
end
