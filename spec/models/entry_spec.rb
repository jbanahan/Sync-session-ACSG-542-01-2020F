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
end
