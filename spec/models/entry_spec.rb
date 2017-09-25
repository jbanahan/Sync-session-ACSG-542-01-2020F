require 'spec_helper'

describe Entry do
  
  context "tracking_status" do
    context "fenix" do
      it "should default to created" do
        expect(Factory(:entry,source_system:'Fenix').tracking_status).to eq(Entry::TRACKING_STATUS_CREATED)
      end
      it "should use open for all non-V type entries with across_sent_date" do
        expect(Factory(:entry,source_system:'Fenix',across_sent_date:Time.now).tracking_status).to eq(Entry::TRACKING_STATUS_OPEN)
      end
      it "should use open for all V type entries" do
        expect(Factory(:entry,source_system:'Fenix',entry_type:'V').tracking_status).to eq(Entry::TRACKING_STATUS_OPEN)
      end
      it "should not override closed" do
        ent = Factory(:entry,source_system:'Fenix',tracking_status:Entry::TRACKING_STATUS_CLOSED) 
        ent.release_date = Time.now
        ent.save!
        expect(ent.tracking_status).to eq(Entry::TRACKING_STATUS_CLOSED)
      end
    end
    context "alliance" do
      it "should use created for base entry" do
        Factory(:entry,source_system:'Alliance').tracking_status == Entry::TRACKING_STATUS_CREATED
      end
      it "should use open for entries that have been filed" do
        Factory(:entry,source_system:'Alliance',entry_filed_date:Time.now).tracking_status == Entry::TRACKING_STATUS_OPEN
      end
      it "should not override closed" do
        ent = Factory(:entry,source_system:'Alliance',tracking_status:Entry::TRACKING_STATUS_CLOSED)
        ent.entry_filed_date = Time.now
        ent.save!
        expect(ent.tracking_status).to eq(Entry::TRACKING_STATUS_CLOSED)
      end
    end
    context "other" do
      it "should default to open" do
        expect(Factory(:entry).tracking_status).to eq(Entry::TRACKING_STATUS_OPEN)
      end
      it "should not override closed" do
        ent = Factory(:entry,tracking_status:Entry::TRACKING_STATUS_CLOSED)
        ent.entry_filed_date = Time.now
        ent.save!
        expect(ent.tracking_status).to eq(Entry::TRACKING_STATUS_CLOSED)
      end
    end
  end
  describe "link_broker_invoices" do
    before :each do
      @ent = Factory(:entry,:broker_reference=>'5555',:source_system=>'ABC')
    end
    it 'should match' do 
      bi = BrokerInvoice.create!(:broker_reference=>'5555',:invoice_number=>'notbrokref',:source_system=>'ABC')
      @ent.link_broker_invoices
      expect(@ent.broker_invoices.first).to eq(bi)
    end
    it "should not match if source system doesn't match" do
      bi = BrokerInvoice.create!(:broker_reference=>'5555',:invoice_number=>'notbrokref',:source_system=>'ZZ')
      @ent.link_broker_invoices
      expect(@ent.broker_invoices.count).to eq(0)
    end
    it "should not match if broker_reference doesn't match" do
      bi = BrokerInvoice.create!(:broker_reference=>'XX',:invoice_number=>'notbrokref',:source_system=>'ABC')
      @ent.link_broker_invoices
      expect(@ent.broker_invoices.count).to eq(0)
    end
  end
  describe 'ocean?' do
    it "should return false for nil transport mode" do
      expect(Entry.new).not_to be_ocean
    end
    it "should return true for 10" do
      expect(Entry.new(:transport_mode_code=>"10")).to be_ocean
    end
    it "should return true for 11" do
      expect(Entry.new(:transport_mode_code=>"11")).to be_ocean
    end
    it "should return false for any other value" do
      expect(Entry.new(:transport_mode_code=>"40")).not_to be_ocean
    end
  end
  describe 'air?' do
    it "should return false for nil transport mode" do
      expect(subject).not_to be_air
    end
    it "should return true for 10" do
      expect(Entry.new(transport_mode_code: "40")).to be_air
    end
    it "should return true for 11" do
      expect(Entry.new(transport_mode_code: "41")).to be_air
    end
    it "should return false for any other value" do
      expect(Entry.new(transport_mode_code: "10")).not_to be_air
    end
  end
  context 'security' do
    before :each do
      MasterSetup.get.update_attributes(:entry_enabled=>true)
      @importer = Factory(:company,:importer=>true)
      @entry = Factory(:entry,:importer_id=>@importer.id)
      @importer_user = Factory(:user,:company_id=>@importer.id)
      allow(@importer_user).to receive(:view_entries?).and_return true
    end
    describe "can_view_importer?" do
      it "should allow same company" do
        expect(Entry.can_view_importer?(@importer, @importer_user)).to be_truthy
      end
      it "should not allow different company" do
        expect(Entry.can_view_importer?(Factory(:company), @importer_user)).to be_falsey
      end
      it "should allow master" do
        allow_any_instance_of(User).to receive(:view_entries?).and_return(true)
        expect(Entry.can_view_importer?(@importer, Factory(:master_user))).to be_truthy
      end
      it "should allow linked" do
        c = Factory(:company)
        @importer.linked_companies << c
        expect(Entry.can_view_importer?(c, @importer_user)).to be_truthy
      end
    end
    context 'search secure' do
      before :each do
        @entry_2 = Factory(:entry,:importer_id=>Factory(:company,:importer=>true).id)
      end
      it 'should restrict non master' do
        found = Entry.search_secure(@importer_user,Entry).all
        expect(found.entries.size).to eq(1)
        expect(found.first).to eq(@entry)
      end
      it "should allow linked company for non master" do
        importer2 = Factory(:company,:importer=>true)
        @importer.linked_companies << importer2
        e2 = Factory(:entry,:importer_id=>@importer.id)
        expect(Entry.search_secure(@importer_user,Entry).all).to eq([@entry,e2])
      end
      it 'should allow all for master' do
        u = Factory(:user,:entry_view=>true)
        u.company.update_attributes(:master=>true)
        found = Entry.search_secure(u,Entry).all
        expect(found.entries.size).to eq(2)
      end
    end
    it 'should allow importer user with permission to view/edit/comment/attach' do
      @importer_user.update_attributes(:entry_view=>true,:entry_comment=>true,:entry_edit=>true,:entry_attach=>true)
      expect(@entry.can_view?(@importer_user)).to be_truthy
      expect(@entry.can_edit?(@importer_user)).to be_falsey #hard coded to false
      expect(@entry.can_attach?(@importer_user)).to be_truthy
      expect(@entry.can_comment?(@importer_user)).to be_truthy
    end
    it 'should allow importer from parent company to view/edit/comment/attach' do
      @parent_company = Factory(:company,:importer=>true)
      @parent_user = Factory(:user,:company=>@parent_company,:entry_view=>true,:entry_comment=>true,:entry_edit=>true,:entry_attach=>true)
      @parent_company.linked_companies << @importer
      expect(@entry.can_view?(@parent_user)).to be_truthy
      expect(@entry.can_edit?(@parent_user)).to be_falsey #hard coded to false
      expect(@entry.can_attach?(@parent_user)).to be_truthy
      expect(@entry.can_comment?(@parent_user)).to be_truthy
    end
    it 'should not allow a user from a different company with overall permission to view/edit/comment/attach' do
      u = Factory(:user,:entry_view=>true,:entry_comment=>true,:entry_edit=>true,:entry_attach=>true)
      u.company.update_attributes(:importer=>true)
      expect(@entry.can_view?(u)).to be_falsey
      expect(@entry.can_edit?(u)).to be_falsey
      expect(@entry.can_attach?(u)).to be_falsey
      expect(@entry.can_comment?(u)).to be_falsey
    end
    it 'should allow master user to view' do
      u = Factory(:user,:entry_view=>true)
      u.company.update_attributes(:master=>true)
      expect(@entry.can_view?(u)).to be_truthy
    end
    it 'should allow user to comment' do
      u = Factory(:user,:entry_comment=>true)
      u.company.update_attributes(:master=>true)
      allow(u).to receive(:view_entries?).and_return true
      expect(Factory(:entry).can_comment?(u)).to be_truthy
    end
    it 'should not allow user w/o permission to comment' do
      u = Factory(:user,:entry_comment=>false)
      u.company.update_attributes(:master=>true)
      expect(Factory(:entry).can_comment?(u)).to be_falsey
    end
    it 'should allow user to attach' do
      u = Factory(:user,:entry_attach=>true)
      u.company.update_attributes(:master=>true)
      allow(u).to receive(:view_entries?).and_return true
      expect(Factory(:entry).can_attach?(u)).to be_truthy
    end
    it 'should not allow user w/o permisstion to attach' do
      u = Factory(:user,:entry_attach=>false)
      u.company.update_attributes(:master=>true)
      expect(Factory(:entry).can_attach?(u)).to be_falsey
    end
  end

  context 'ports' do
    before :each do 
      @port = Factory(:port)
    end
    it 'should find matching lading port' do
      ent = Factory(:entry,:lading_port_code=>@port.schedule_k_code)
      expect(ent.lading_port).to eq(@port)
    end
    it 'should find matching unlading port' do
      expect(Factory(:entry,:unlading_port_code=>@port.schedule_d_code).unlading_port).to eq(@port)
    end
    it 'should find matching entry port' do
      expect(Factory(:entry,:entry_port_code=>@port.schedule_d_code).entry_port).to eq(@port)
    end
    it 'should find matching us exit port' do
      expect(Factory(:entry,:us_exit_port_code=>@port.schedule_d_code).us_exit_port).to eq(@port)
    end
  end

  context "update_k84_month" do
    before :each do
      @entry = Factory(:entry)
    end

    it "should set k84 month" do
      @entry.update_attributes! cadex_accept_date: Time.zone.parse("2013-01-01")
      expect(@entry.k84_month).to eq 1
      expect(@entry.k84_due_date.to_date).to eq(Date.new(2013,1,25))
    end

    it "should set k84 month to next month if cadex accept is 25th or later" do
      @entry.update_attributes! cadex_accept_date: Time.zone.parse("2013-01-25")
      expect(@entry.k84_month).to eq 2
      expect(@entry.k84_due_date.to_date).to eq(Date.new(2013,2,25))
    end

    it "should set k84 month to 1 if cadex accept is after Dec 24th" do
      @entry.update_attributes! cadex_accept_date: Time.zone.parse("2013-12-25")
      expect(@entry.k84_due_date.to_date).to eq(Date.new(2014,1,25))
      expect(@entry.k84_month).to eq 1
    end

    it "uses k84 receive date for manual low-value entries, rather than cadex accept" do
      @entry.update_attributes! k84_receive_date: Time.zone.parse("2013-01-01"), entry_number: "119810123459", entry_type: "V", cadex_accept_date: Time.zone.now
      expect(@entry.k84_month).to eq 1
      expect(@entry.k84_due_date.to_date).to eq(Date.new(2013,1,25))
    end

    it "uses k84 receive date for hand-carry entries, rather than cadex accept" do
      @entry.update_attributes! k84_receive_date: Time.zone.parse("2013-01-01"), entry_number: "119810123459", entry_type: "C", cadex_accept_date: Time.zone.now
      expect(@entry.k84_month).to eq 1
      expect(@entry.k84_due_date.to_date).to eq(Date.new(2013,1,25))
    end

    it "uses k84 receive date for entry addendums, rather than cadex accept" do
      @entry.update_attributes! k84_receive_date: Time.zone.parse("2013-01-01"), entry_number: "119810123459", entry_type: "H", cadex_accept_date: Time.zone.now
      expect(@entry.k84_month).to eq 1
      expect(@entry.k84_due_date.to_date).to eq(Date.new(2013,1,25))
    end
  end

  describe "canadian?" do
    it 'identifies as canadian if import country is CA' do
      e = Entry.new
      c = Country.new
      c.iso_code = "CA"
      e.import_country = c
      expect(e.canadian?).to be_truthy

      e.import_country.iso_code = "US"
      expect(e.canadian?).to be_falsey
      e.import_country = nil
      expect(e.canadian?).to be_falsey
    end
  end

  describe "entry_port" do

    it 'returns Candian ports for Canadian imports' do
      e = Entry.new; c = Country.new; p_ca = Port.new(name: "Montreal"); p_us = Port.new(name: "Houston")
      c.iso_code = "CA"; c.save!
      e.us_entry_port = p_us; e.ca_entry_port = p_ca; e.import_country = c

      expect(e.entry_port).to eq(p_ca)
    end

    it 'returns US ports for US imports' do
      e = Entry.new; c = Country.new; p_ca = Port.new(name: "Montreal"); p_us = Port.new(name: "Houston")
      c.iso_code = "US"; c.save!
      e.us_entry_port = p_us; e.ca_entry_port = p_ca; e.import_country = c

      expect(e.entry_port).to eq(p_us)
    end

  end

  describe "purged?" do
    context "with existing purge record" do
       before :each do
        EntryPurge.create! source_system: "Source", broker_reference: "12345", date_purged: Time.zone.parse("2015-04-01 00:00")
      end

      it "reports purged if an entry purge record exists with a purge date after the given time" do
        expect(Entry.purged? 'Source', '12345', Time.zone.parse("2015-03-31 00:00")).to be_truthy
      end

      it "reports not purged if an entry purge record exists with a purge date prior the given system export time" do
        expect(Entry.purged? 'Source', '12345', Time.zone.parse("2015-04-01 10:00")).to be_falsey
      end
    end

    it "reports not purged if no purge record exists" do
      expect(Entry.purged? 'Source', '12345', Time.zone.parse("2015-03-31 00:00")).to be_falsey
    end
  end

  describe "purge!" do
    let (:entry) { Factory(:entry, broker_reference: "12345", source_system: "SOURCE", import_country: country)}
    let (:country) { Factory(:country, iso_code: "ZZ") }

    it "purges entries" do
      now = Time.zone.now
      Timecop.freeze(now) { entry.purge! }

      purge = EntryPurge.where(broker_reference: "12345").first
      expect(purge).not_to be_nil
      expect(purge.country_iso).to eq "ZZ"
      expect(purge.source_system).to eq "SOURCE"
      expect(purge.date_purged.to_i).to eq now.to_i
    end

    it "accepts an alternate date_purged value" do
      time = ActiveSupport::TimeZone["America/New_York"].parse "2017-01-01 12:00"
      entry.purge! date_purged: time

      purge = EntryPurge.where(broker_reference: "12345").first
      expect(purge).not_to be_nil
      expect(purge.date_purged).to eq time
    end

    it "handles missing import country" do
      entry.update_attributes! import_country: nil

      entry.purge!
      purge = EntryPurge.where(broker_reference: "12345").first
      expect(purge).not_to be_nil
      expect(purge.country_iso).to be_nil
    end
  end

  describe "first_sale_savings" do
    it "returns the sum of first-sale savings on all child invoices" do
      ent = Factory(:entry)
      Factory(:commercial_invoice_line, entry: ent, contract_amount: 500, value: 200, 
               commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 30, entered_value: 10)])
      Factory(:commercial_invoice_line, entry: ent, contract_amount: 250, value: 100, 
               commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 15, entered_value: 5)])
      Factory(:commercial_invoice_line, entry: ent, contract_amount: nil, value: 100, 
               commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 15, entered_value: 5)])
      expect(ent.first_sale_savings).to eq 1350
    end
  end

  context "hold date / hold release date" do
    let(:date_1) { ActiveSupport::TimeZone["Eastern Time (US & Canada)"].local(2017,1,12)}
    let(:date_2) { ActiveSupport::TimeZone["Eastern Time (US & Canada)"].local(2017,1,15)}
    let(:date_3) { ActiveSupport::TimeZone["Eastern Time (US & Canada)"].local(2017,1,17)}
    let(:now) { ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now }
    
    context "US" do
      let(:co) { Factory(:country, iso_code: "US") }

      describe "set_hold_date" do
        it "assigns the earliest hold date" do
          e = Factory(:entry, import_country: co, aphis_hold_date: date_1, cbp_hold_date: date_2, nmfs_hold_date: date_3, hold_date: nil)
          expect{e.set_hold_date}.to change(e, :hold_date).from(nil).to date_1
        end
      end

      describe "set_hold_release_date" do
        let(:e) { Factory(:entry, import_country: co, hold_release_date: nil, aphis_hold_date: date_1, cbp_hold_date: date_2, nmfs_hold_date: date_3, aphis_hold_release_date: date_1, cbp_hold_release_date: date_2, nmfs_hold_release_date: date_3) }
        
        it "assigns 'one usg date' if it isn't nil" do
          e.update_attributes!(one_usg_date: date_1)
          expect{e.set_hold_release_date}.to change(e, :hold_release_date).from(nil).to date_1
        end

        it "assigns the latest hold release date if 'one usg' is nil and there are no open holds" do
          e.update_attributes! on_hold: true
          expect{e.set_hold_release_date}.to change(e, :hold_release_date).from(nil).to date_3
        end

        it "assigns nil if 'one usg date' is nil and there is an open hold" do
          e.update_attributes!(one_usg_date: nil, hold_release_date: now, aphis_hold_release_date: nil)
          expect{e.set_hold_release_date}.to change(e, :hold_release_date).from(now).to nil
        end

        it "assigns nil if all hold release dates and 'one usg' are nil" do
          e.update_attributes!(hold_release_date: date_1, one_usg_date: nil, aphis_hold_release_date: nil, cbp_hold_release_date: nil, nmfs_hold_release_date: nil)
          expect{e.set_hold_release_date}.to change(e, :hold_release_date).from(date_1).to nil
        end
      end

      describe "set_on_hold" do
        let(:e) { Factory(:entry, import_country: co, on_hold: nil, aphis_hold_date: date_1, cbp_hold_date: date_2, nmfs_hold_date: date_3) }
        
        it "returns 'true' if any of the customs hold dates are assigned without a corresponding release date" do
          e.update_attributes!(aphis_hold_release_date: now, cbp_hold_release_date: now, nmfs_hold_release_date: nil)
          expect{e.set_on_hold}.to change(e, :on_hold).from(nil).to true
        end

        it "returns 'false' if no custom hold dates are assigned" do
          e.update_attributes!(on_hold: true, aphis_hold_date: nil, cbp_hold_date: nil, nmfs_hold_date: nil)
          expect{e.set_on_hold}.to change(e, :on_hold).from(true).to false
        end

        it "returns 'false' if a customs hold date is assigned with a corresponding release date" do
          e.update_attributes!(on_hold: true, aphis_hold_release_date: now, cbp_hold_release_date: now, nmfs_hold_release_date: now)
          expect{e.set_on_hold}.to change(e, :on_hold).from(true).to false
        end

        it "returns 'false' if 'one usg date' is assigned" do
          e.update_attributes!(on_hold: true, one_usg_date: now)
          expect{e.set_on_hold}.to change(e, :on_hold).from(true).to false
        end
      end

      describe "hold_attributes" do
        it "returns list of matching PGA hold and release dates" do
          e = Factory(:entry)
          expect(e.hold_attributes).to eq([{hold: :ams_hold_date, release: :ams_hold_release_date}, 
                                           {hold: :aphis_hold_date, release: :aphis_hold_release_date}, 
                                           {hold: :atf_hold_date, release: :atf_hold_release_date}, 
                                           {hold: :cargo_manifest_hold_date, release: :cargo_manifest_hold_release_date},
                                           {hold: :cbp_hold_date, release: :cbp_hold_release_date},
                                           {hold: :cbp_intensive_hold_date, release: :cbp_intensive_hold_release_date},
                                           {hold: :ddtc_hold_date, release: :ddtc_hold_release_date},
                                           {hold: :fda_hold_date, release: :fda_hold_release_date},
                                           {hold: :fsis_hold_date, release: :fsis_hold_release_date},
                                           {hold: :nhtsa_hold_date, release: :nhtsa_hold_release_date},
                                           {hold: :nmfs_hold_date, release: :nmfs_hold_release_date},
                                           {hold: :usda_hold_date, release: :usda_hold_release_date},
                                           {hold: :other_agency_hold_date, release: :other_agency_hold_release_date}])
        end
      end

      describe "all holds" do
        it "returns list of hashes containing hold/release-date pairs where the hold date is populated" do
          now = DateTime.now
          yesterday = DateTime.now - 1.day
          e = Factory(:entry, import_country: co, aphis_hold_date: yesterday, aphis_hold_release_date: yesterday, cbp_hold_date: now, nmfs_hold_date: nil)
          expect(e.all_holds).to eq [{hold: { mfid: :ent_aphis_hold_date, attribute: :aphis_hold_date, value: yesterday}, release: { mfid: :ent_aphis_hold_release_date, attribute: :aphis_hold_release_date, value: yesterday}}, 
                                     {hold: {mfid: :ent_cbp_hold_date, attribute: :cbp_hold_date, value: now}, release: {mfid: :ent_cbp_hold_release_date, attribute: :cbp_hold_release_date, value: nil}}]
        end
      end
    end
  
    context "CA" do
      let(:co) { Factory(:country, iso_code: "CA") }

      describe "set_hold_date" do
        it "assigns hold_date to the exam_ordered_date" do
          e = Factory(:entry, import_country: co, exam_ordered_date: date_1, hold_date: nil)
          expect{e.set_hold_date}.to change(e, :hold_date).from(nil).to(date_1)
        end
      end

      describe "set_hold_release_date" do
        it "assigns both hold_release_date and exam_release_date to release_date" do
          e = Factory(:entry, import_country: co, release_date: date_1, hold_release_date: nil, exam_release_date: nil)
          e.set_hold_release_date
          expect(e.exam_release_date).to eq date_1
          expect(e.hold_release_date).to eq date_1
        end
      end

      describe "set_on_hold" do
        it "assigns 'true' to on_hold if hold_date is populated but hold_release_date is not" do
          e = Factory(:entry, import_country: co, hold_date: date_1, on_hold: nil, hold_release_date: nil)
          expect{e.set_on_hold}.to change(e, :on_hold).from(nil).to true 
        end
      end

      describe "all_holds" do
        it "throws exception" do
          e = Factory(:entry, import_country: co)
          expect{e.all_holds}.to raise_error(RuntimeError, "Only valid for US entries!")
        end
      end

      describe "hold_attributes" do
        it "throws exception" do
          e = Factory(:entry, import_country: co)
          expect{e.hold_attributes}.to raise_error(RuntimeError, "Only valid for US entries!")
        end
      end
    end
  end

end
