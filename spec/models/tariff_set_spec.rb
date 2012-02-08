require "spec_helper"

describe TariffSet do
  context 'activate' do
    it "replaces official tariff" do
      c1 = Country.first
      c2 = Country.last

      c1.should_not == c2

      should_be_gone = OfficialTariff.create!(:country_id => c1.id, :hts_code => "1234567890", :full_description => "FD1")
      should_be_changed = OfficialTariff.create!(:country_id => c1.id, :hts_code => "1234555555", :full_description => "FD3")
      should_stay = OfficialTariff.create!(:country_id => c2.id, :hts_code => should_be_gone.hts_code, :full_description => "FD2")

      old_ts = TariffSet.create!(:country_id => c1.id, :label => "oldts", :active => true)

      ts = TariffSet.create!(:country_id => c1.id, :label => "newts")
      r = ts.tariff_set_records
      r.create!(:country_id => c1.id, :hts_code => should_be_changed.hts_code, :full_description => "changed_desc")
      r.create!(:country_id => c1.id, :hts_code => "9999999999")

      OfficialQuota.should_receive(:relink_country).with(c1)
      
      ts.activate

      found = OfficialTariff.where(:country_id => c1.id)

      found.should have(2).items
      OfficialTariff.where(:country_id => c1.id, :hts_code => "1234555555").first.full_description.should == "changed_desc"
      OfficialTariff.where(:country_id => c1.id, :hts_code => "9999999999").first.should_not be_nil
      OfficialTariff.where(:country_id => c2.id, :hts_code => should_stay.hts_code).first.should_not be_nil
      OfficialTariff.where(:country_id => c1.id, :hts_code => should_be_gone.hts_code).first.should be_nil
      TariffSet.find(old_ts.id).should_not be_active #should have deactivated old tariff set for same country
      TariffSet.find(ts.id).should be_active #should have activated this tariff set
    end

    it 'writes user message' do
      u = User.first
      c = Country.first
      ts = TariffSet.create!(:country_id => c.id, :label => "newts")
      ts.activate u
      u.messages.should have(1).item
    end
  end
  
  context 'compare' do
    it "returns array of results" do
      old = TariffSet.create!(:country_id => Country.find_by_iso_code(:us).id, :label => "old")
      new = TariffSet.create!(:country_id => Country.find_by_iso_code(:us).id, :label => "new")

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

      added.should have(1).item
      added.first.hts_code.should == "567"

      removed.should have(1).item
      removed.first.hts_code.should == "123"

      changed.should have(1).item
      changed["345"][0]["full_description"].should == "def"
      changed["345"][1]["full_description"].should == "abc"
    end
  end
end
