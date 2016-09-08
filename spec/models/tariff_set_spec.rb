require "spec_helper"

describe TariffSet do
  context 'activate' do
    before :each do
      Country.destroy_all
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
      expect(OpenChain::OfficialTariffProcessor::TariffProcessor).to receive(:process_country).with(@c1)

      ts.activate

      found = OfficialTariff.where(:country_id => @c1.id)

      expect(found.size).to eq(2)
      expect(OfficialTariff.where(:country_id => @c1.id, :hts_code => "1234555555").first.full_description).to eq("changed_desc")
      expect(OfficialTariff.where(:country_id => @c1.id, :hts_code => "9999999999").first).not_to be_nil
      expect(OfficialTariff.where(:country_id => @c2.id, :hts_code => should_stay.hts_code).first).not_to be_nil
      expect(OfficialTariff.where(:country_id => @c1.id, :hts_code => should_be_gone.hts_code).first).to be_nil
      expect(TariffSet.find(old_ts.id)).not_to be_active #should have deactivated old tariff set for same country
      expect(TariffSet.find(ts.id)).to be_active #should have activated this tariff set
    end

    it 'writes user message' do
      u = Factory(:user)
      expect(u).not_to be_nil
      c = @c1
      ts = TariffSet.create!(:country_id => c.id, :label => "newts")
      ts.activate u
      expect(u.messages.size).to eq(1)
    end

    it "sends notifications to subscribed users" do
      u = Factory(:user)
      u2 = Factory(:user,tariff_subscribed:true)
      u3 = Factory(:user,tariff_subscribed:true)
      u4 = Factory(:user, disabled: true)
      c = @c1
      ts = TariffSet.create!(:country_id => c.id, :label => "newts")
      ts.activate u
      expect(ActionMailer::Base.deliveries.length).to eq 2
      m = ActionMailer::Base.deliveries.pop
      expect(m.to).to eq([u3.email])
      m = ActionMailer::Base.deliveries.pop
      expect(m.to).to eq([u2.email])
    end
  end

  context 'compare' do
    it "returns array of results" do
      c = Factory(:country,:iso_code=>'US')
      old = TariffSet.create!(:country_id => c.id, :label => "old")
      new = TariffSet.create!(:country_id => c.id, :label => "new")

      #will be removed
      old.tariff_set_records.create!(:hts_code => "123", :country_id => old.country_id)
      #will be changed
      old.tariff_set_records.create!(:hts_code => "345", :full_description => "abc", :country_id => old.country_id)
      #will stay the same
      old.tariff_set_records.create!(:hts_code => "901", :full_description => "xyz", :country_id => old.country_id)

      #changed
      new.tariff_set_records.create!(:hts_code => "345", :full_description => "def", :country_id => new.country_id)
      #added
      new.tariff_set_records.create!(:hts_code => "567", :country_id => new.country_id)
      #stayed the same
      new.tariff_set_records.create!(:hts_code => "901", :full_description => "xyz", :country_id => new.country_id)

      added, removed, changed = new.compare old

      expect(added.size).to eq(1)
      expect(added.first.hts_code).to eq("567")

      expect(removed.size).to eq(1)
      expect(removed.first.hts_code).to eq("123")

      expect(changed.size).to eq(1)
      expect(changed["345"][0]["full_description"]).to eq("def")
      expect(changed["345"][1]["full_description"]).to eq("abc")
    end
  end
end
