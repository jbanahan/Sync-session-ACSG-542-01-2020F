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
    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:entry_enabled?).and_return true
      allow(ms).to receive(:entry_enabled).and_return true
      ms
    }
    let (:importer) { Factory(:importer) }
    let (:linked_importer) { 
      child_importer = Factory(:importer)
      importer.linked_companies << child_importer
      child_importer
    }
    let (:entry) { Factory(:entry, importer: importer) }
    let (:importer_user) {
      user = Factory(:user, company: importer)
      allow(user).to receive(:view_entries?).and_return true
      user
    }

    describe "can_view_importer?" do
      
      it "should allow same company" do
        expect(Entry.can_view_importer?(importer, importer_user)).to eq true
      end

      it "should not allow different company" do
        expect(Entry.can_view_importer?(Factory(:company), importer_user)).to eq false
      end
      
      it "should allow master" do
        master_user = Factory(:master_user)
        expect(master_user).to receive(:view_entries?).and_return(true)
        expect(Entry.can_view_importer?(importer, master_user)).to eq true
      end
      
      it "should allow linked" do
        expect(Entry.can_view_importer?(linked_importer, importer_user)).to eq true
      end
      
      it "should not allow nil importer" do
        expect(Entry.can_view_importer?(nil, importer_user)).to eq false
      end

      it "should not allow master user access to nil importer by default" do
        master_user = Factory(:master_user)
        expect(master_user).to receive(:view_entries?).and_return(true)
        expect(Entry.can_view_importer?(nil, master_user)).to eq false
      end

      it "should allow master user access to nil importer if requested" do
        master_user = Factory(:master_user)
        expect(master_user).to receive(:view_entries?).and_return(true)
        expect(Entry.can_view_importer?(nil, master_user, allow_nil_importer: true)).to eq true
      end
    end

    context 'search secure' do
      let! (:entry_2) { Factory(:entry, importer: Factory(:company,:importer=>true)) }
      before :each do 
        entry
      end

      it 'should restrict non master' do
        found = Entry.search_secure(importer_user,Entry).all
        expect(found.entries.size).to eq(1)
        expect(found.first).to eq(entry)
      end

      it "should allow linked company for non master" do
        importer2 = Factory(:company,:importer=>true)
        importer.linked_companies << importer2
        e2 = Factory(:entry,:importer_id=>importer.id)
        entries = Entry.search_secure(importer_user,Entry).all.to_a
        expect(entries).to include entry
        expect(entries).to include e2
      end

      it 'should allow all for master' do
        u = Factory(:user,:entry_view=>true)
        u.company.update!(:master=>true)
        found = Entry.search_secure(u,Entry).all
        expect(found.entries.size).to eq(2)
      end
    end

    it 'should allow importer user with permission to view/edit/comment/attach' do
      importer_user.update!(:entry_view=>true,:entry_comment=>true,:entry_edit=>true,:entry_attach=>true)
      expect(entry.can_view?(importer_user)).to eq true
      expect(entry.can_edit?(importer_user)).to eq false #hard coded to false
      expect(entry.can_attach?(importer_user)).to eq true
      expect(entry.can_comment?(importer_user)).to eq true
    end
    it 'should allow importer from parent company to view/edit/comment/attach' do
      parent_company = Factory(:company,:importer=>true)
      parent_user = Factory(:user,:company=>parent_company,:entry_view=>true,:entry_comment=>true,:entry_edit=>true,:entry_attach=>true)
      parent_company.linked_companies << importer
      expect(entry.can_view?(parent_user)).to eq true
      expect(entry.can_edit?(parent_user)).to eq false #hard coded to false
      expect(entry.can_attach?(parent_user)).to eq true
      expect(entry.can_comment?(parent_user)).to eq true
    end
    it 'should not allow a user from a different company with overall permission to view/edit/comment/attach' do
      u = Factory(:user,:entry_view=>true,:entry_comment=>true,:entry_edit=>true,:entry_attach=>true)
      u.company.update_attributes(:importer=>true)
      expect(entry.can_view?(u)).to eq false
      expect(entry.can_edit?(u)).to eq false
      expect(entry.can_attach?(u)).to eq false
      expect(entry.can_comment?(u)).to eq false
    end
    it 'should allow master user to view' do
      u = Factory(:user,:entry_view=>true)
      u.company.update_attributes(:master=>true)
      expect(entry.can_view?(u)).to eq true
    end
    it "does not allow non-master user to view importerless entry" do
      entry.update! importer_id: nil
      expect(entry.can_view?(importer_user)).to eq false
    end
    it "allows master user to view importerless entry" do
      entry.update! importer_id: nil
      u = Factory(:master_user, entry_view: true)

      expect(entry.can_view?(u)).to eq true
    end
    it 'should allow user to comment' do
      u = Factory(:user,:entry_comment=>true)
      u.company.update_attributes(:master=>true)
      allow(u).to receive(:view_entries?).and_return true
      expect(Factory(:entry, :importer=>Factory(:company,:importer=>true)).can_comment?(u)).to eq true
    end
    it 'should not allow user w/o permission to comment' do
      u = Factory(:user,:entry_comment=>false)
      u.company.update_attributes(:master=>true)
      expect(Factory(:entry, :importer=>Factory(:company,:importer=>true)).can_comment?(u)).to eq false
    end
    it 'should allow user to attach' do
      u = Factory(:user,:entry_attach=>true)
      u.company.update_attributes(:master=>true)
      allow(u).to receive(:view_entries?).and_return true
      expect(Factory(:entry, :importer=>Factory(:company,:importer=>true)).can_attach?(u)).to eq true
    end
    it 'should not allow user w/o permisstion to attach' do
      u = Factory(:user,:entry_attach=>false)
      u.company.update_attributes(:master=>true)
      expect(Factory(:entry, :importer=>Factory(:company,:importer=>true)).can_attach?(u)).to eq false
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

    it "uses k84 month and due date to find the payment due date" do
      calendar = Factory(:calendar, calendar_type: 'K84Due', year: 2013)
      cal_event = Factory(:calendar_event, event_date: Date.parse('2013-01-29'), calendar_id: calendar.id)

      @entry.update_attributes! k84_receive_date: Time.zone.parse("2013-01-01"), entry_number: "119810123459", entry_type: "V", cadex_accept_date: Time.zone.now
      expect(@entry.k84_month).to eq 1
      expect(@entry.k84_due_date.to_date).to eq(Date.new(2013,1,25))
      expect(@entry.k84_payment_due_date.to_date).to eq(Date.new(2013,1,29))
    end

    it "does not update the k84 payment due date if no calendar event is found" do
      @entry.update_attributes! k84_receive_date: Time.zone.parse("2013-01-01"), entry_number: "119810123459", entry_type: "C", cadex_accept_date: Time.zone.now
      expect(@entry.k84_month).to eq 1
      expect(@entry.k84_due_date.to_date).to eq(Date.new(2013,1,25))
      expect(@entry.k84_payment_due_date).to be_nil
    end
  end

  describe "value_for_tax" do
    let(:ci1) {Factory(:commercial_invoice, commercial_invoice_lines:
      [Factory(:commercial_invoice_line,
        commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: 1234)]),
      Factory(:commercial_invoice_line,
        commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: 1234)])
      ])}
    let(:ci2) {Factory(:commercial_invoice, commercial_invoice_lines:
      [Factory(:commercial_invoice_line,
        commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: nil)]),
      Factory(:commercial_invoice_line,
        commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: 1234)])
      ])}

    it 'sums all commercial invoice tariff values associated with the entry' do
      e = Entry.new
      c = Country.new
      c.iso_code = "CA"; c.save!
      e.import_country = c
      e.commercial_invoices = [ci1]
      expect(e.value_for_tax).to eq BigDecimal.new "6"
    end

    it 'does not return anything if the entry is not Candian' do
      e = Entry.new
      c = Country.new
      c.iso_code = "US"; c.save!
      e.import_country = c
      e.commercial_invoices = [ci2]
      expect(e.value_for_tax).to be_nil
    end
  end

  describe "american?" do
    it 'identifies as American if import country is US' do
      e = Entry.new
      c = Country.new
      c.iso_code = "US"
      e.import_country = c
      expect(e.american?).to be_truthy

      e.import_country.iso_code = "CA"
      expect(e.american?).to be_falsey
      e.import_country = nil
      expect(e.american?).to be_falsey
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
      inv = Factory(:commercial_invoice, entry:ent)
      Factory(:commercial_invoice_line, commercial_invoice: inv, contract_amount: 500, value: 200, 
               commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 30, entered_value: 10)])
      Factory(:commercial_invoice_line, commercial_invoice: inv, contract_amount: 250, value: 100, 
               commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 15, entered_value: 5)])
      Factory(:commercial_invoice_line, commercial_invoice: inv, contract_amount: nil, value: 100, 
               commercial_invoice_tariffs: [Factory(:commercial_invoice_tariff, duty_amount: 15, entered_value: 5)])
      expect(ent.first_sale_savings).to eq 1350
    end
  end

  context "hold date / hold release date" do
    context "US" do
      let(:co) { Factory(:country, iso_code: "US") }

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
                                           {hold: :other_agency_hold_date, release: :other_agency_hold_release_date},
                                           {hold: :fish_and_wildlife_hold_date, release: :fish_and_wildlife_hold_release_date}])
        end
      end

      describe "populated_holds" do
        it "returns list of hashes containing hold/release-date pairs where the hold date is populated" do
          now = DateTime.now
          yesterday = DateTime.now - 1.day
          e = Factory(:entry, import_country: co, aphis_hold_date: yesterday, aphis_hold_release_date: yesterday, cbp_hold_date: now, nmfs_hold_date: nil)
          expect(e.populated_holds).to eq [{hold: { mfid: :ent_aphis_hold_date, attribute: :aphis_hold_date, value: yesterday}, release: { mfid: :ent_aphis_hold_release_date, attribute: :aphis_hold_release_date, value: yesterday}}, 
                                     {hold: {mfid: :ent_cbp_hold_date, attribute: :cbp_hold_date, value: now}, release: {mfid: :ent_cbp_hold_release_date, attribute: :cbp_hold_release_date, value: nil}}]
        end
      end

      describe "active_holds" do
        it "returns list of hashes containing hold-release_date pairs where the hold date is populated but the hold release is not" do
          now = DateTime.now
          yesterday = DateTime.now - 1.day
          e = Factory(:entry, import_country: co, aphis_hold_date: yesterday, aphis_hold_release_date: yesterday, cbp_hold_date: now, nmfs_hold_date: nil)
          expect(e.active_holds).to eq [{hold: {mfid: :ent_cbp_hold_date, attribute: :cbp_hold_date, value: now}, release: {mfid: :ent_cbp_hold_release_date, attribute: :cbp_hold_release_date, value: nil}}]
        end
      end
    end
  
    context "CA" do
      let(:co) { Factory(:country, iso_code: "CA") }

      describe "populated_holds" do
        it "throws exception" do
          e = Factory(:entry, import_country: co)
          expect{e.populated_holds}.to raise_error(RuntimeError, "Only valid for US entries!")
        end
      end

      describe "active_holds" do
        it "throws_exception" do
          e = Factory(:entry, import_country: co)
          expect{e.active_holds}.to raise_error(RuntimeError, "Only valid for US entries!")
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

  describe "split_release_option_value" do
    it "returns 'Hold All' when 1" do
      expect(Entry.new(split_release_option: "1").split_release_option_value).to eq "Hold All"
    end

    it "returns 'Incremental' when 2" do
      expect(Entry.new(split_release_option: "2").split_release_option_value).to eq "Incremental"
    end

    it "returns '' when nil" do
      expect(Entry.new.split_release_option_value).to eq ""
    end
  end

  describe "total_duty_taxes_fees_amount" do

    let (:entry) { Entry.new total_duty: BigDecimal("1"), total_taxes: BigDecimal("2"), total_fees: BigDecimal("3"), total_add: BigDecimal("4"), total_cvd: BigDecimal("5") }

    it "returns sum of duty, taxes, fees, penalties" do
      expect(entry.total_duty_taxes_fees_amount).to eq BigDecimal("15")
    end

    it "handles nil values" do
      expect(Entry.new.total_duty_taxes_fees_amount).to eq BigDecimal('0')
    end
  end

  describe "split_shipment_date=" do
    let(:ent) { Factory(:entry, split_shipment_date: nil, split_shipment: nil) }
    let(:dt) { DateTime.new(2018,3,15,15,0) }

    it "also sets split_shipment flag to True when assigned" do
      ent.split_shipment_date = dt
      expect(ent.split_shipment_date).to eq dt
      expect(ent.split_shipment).to eq true
    end

    it "also sets split_shipment flag to False when unassigned" do
      ent.update_attributes! split_shipment_date: dt, split_shipment: true
      ent.split_shipment_date = nil
      expect(ent.split_shipment_date).to be_nil
      expect(ent.split_shipment).to eq false
    end
  end

  describe "get_transport_mode_codes_us_ca" do
    it "converts mode descriptor to numeric codes" do
      expect(Entry.get_transport_mode_codes_us_ca('Air')).to eq [40,41,1]
      expect(Entry.get_transport_mode_codes_us_ca('Sea')).to eq [10,11,9]
      expect(Entry.get_transport_mode_codes_us_ca('Rail')).to eq [20,21,6]
      expect(Entry.get_transport_mode_codes_us_ca('Truck')).to eq [30,31,2]
      expect(Entry.get_transport_mode_codes_us_ca('Dirigible')).to eq []
      expect(Entry.get_transport_mode_codes_us_ca('air')).to eq [40,41,1]
      expect(Entry.get_transport_mode_codes_us_ca('AIR')).to eq [40,41,1]
      expect(Entry.get_transport_mode_codes_us_ca(nil)).to eq []
    end
  end

  describe "get_transport_mode_name_lookup_us_ca" do
    it "returns hash with numeric codes as keys, mode descriptors as values" do
      expect(Entry.get_transport_mode_name_lookup_us_ca).to eq({1 => "AIR", 40 => "AIR", 41 => "AIR",
                                                                9 => "SEA", 10 => "SEA", 11 => "SEA",
                                                                6 => "RAIL", 20 => "RAIL", 21 => "RAIL",
                                                                2 => "TRUCK", 30 => "TRUCK", 31 => "TRUCK"})
    end
  end

  describe "ocean_mode?" do
    [10, 11, 9].each do |code|
      it "returns true for #{code}" do 
        e = Entry.new transport_mode_code: code
        expect(e.ocean_mode?).to eq true
      end
    end

    it "returns false for non-ocean codes" do
      e = Entry.new transport_mode_code: 1
      expect(e.ocean_mode?).to eq false
    end

    it "returns false for blank codes" do
      expect(Entry.new.ocean_mode?).to eq false
    end
  end

  describe "air_mode?" do
    [40, 41, 1].each do |code|
      it "returns true for #{code}" do 
        e = Entry.new transport_mode_code: code
        expect(e.air_mode?).to eq true
      end
    end

    it "returns false for non-air codes" do
      e = Entry.new transport_mode_code: 100
      expect(e.air_mode?).to eq false
    end

    it "returns false for blank codes" do
      expect(Entry.new.air_mode?).to eq false
    end
  end

  describe "rail_mode?" do
    [20,21,6].each do |code|
      it "returns true for #{code}" do 
        e = Entry.new transport_mode_code: code
        expect(e.rail_mode?).to eq true
      end
    end

    it "returns false for non-rail codes" do
      e = Entry.new transport_mode_code: 100
      expect(e.rail_mode?).to eq false
    end

    it "returns false for blank codes" do
      expect(Entry.new.rail_mode?).to eq false
    end
  end

  describe "truck_mode?" do
    [30,31,2].each do |code|
      it "returns true for #{code}" do 
        e = Entry.new transport_mode_code: code
        expect(e.truck_mode?).to eq true
      end
    end

    it "returns false for non-truck codes" do
      e = Entry.new transport_mode_code: 100
      expect(e.truck_mode?).to eq false
    end

    it "returns false for blank codes" do
      expect(Entry.new.truck_mode?).to eq false
    end
  end

  describe "destroy_commercial_invoices" do
    it "destroys all commercial invoices under the entry" do
      entry = Factory(:entry)
      invoice_1 = entry.commercial_invoices.build
      line_1a = invoice_1.commercial_invoice_lines.build
      invoice_1.commercial_invoice_lines.build
      line_1a.commercial_invoice_tariffs.build
      line_1a.commercial_invoice_tariffs.build
      entry.commercial_invoices.build
      entry.save!

      expect(entry.commercial_invoices.length).to eq 2
      entry.destroy_commercial_invoices
      # There's no good way to verify the preloading happened, so we're reall just verifying that destroy_all is called.
      entry.reload
      expect(entry.commercial_invoices.length).to eq 0
    end
  end

  describe "total_billed_duty_amount" do
    let (:entry) { Entry.new}
    let (:invoice_1) { 
      invoice = BrokerInvoice.new
      entry.broker_invoices << invoice
      invoice
    }

    let (:invoice_2) {
      invoice = BrokerInvoice.new
      entry.broker_invoices << invoice
      invoice 
    }

    it "sums duty for each invoice" do
      expect(invoice_1).to receive(:total_billed_duty_amount).and_return BigDecimal("100")
      expect(invoice_2).to receive(:total_billed_duty_amount).and_return BigDecimal("200")

      expect(entry.total_billed_duty_amount).to eq BigDecimal("300")
    end

    it "returns zero if no invoices exist" do
      expect(entry.total_billed_duty_amount).to eq BigDecimal("0")
    end
  end

  describe "total_duty_billed_subquery" do

    let (:entry) {
      Factory(:entry, broker_reference: "1234")
    }

    context "with Customs Management entries" do
      let! (:invoice) {
        broker_invoice = Factory(:broker_invoice, entry: entry, source_system: "Alliance")
        broker_invoice.broker_invoice_lines.create! charge_code: "0001", charge_amount: "100", charge_description: "DUTY"
        broker_invoice.broker_invoice_lines.create! charge_code: "0002", charge_amount: "200", charge_description: "NOT DUTY"
        broker_invoice
      }

      it "returns a subquery to calculate duty amount billed for an entry" do
        result = ActiveRecord::Base.connection.execute "SELECT #{Entry.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 100
      end

      it "returns 0 if no duty is billed" do
        invoice.broker_invoice_lines.first.destroy

        result = ActiveRecord::Base.connection.execute "SELECT #{Entry.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 0
      end
    end

    context "with Fenix entries" do
      let! (:invoice) {
        broker_invoice = Factory(:broker_invoice, entry: entry, source_system: "Fenix")
        broker_invoice.broker_invoice_lines.create! charge_code: "1", charge_amount: "100", charge_description: "DUTY"
        broker_invoice.broker_invoice_lines.create! charge_code: "2", charge_amount: "200", charge_description: "NOT DUTY"
        broker_invoice
      }

      it "returns a subquery to calculate duty amount billed for an entry" do
        result = ActiveRecord::Base.connection.execute "SELECT #{Entry.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 100
      end

      it "returns 0 if no duty is billed" do
        invoice.broker_invoice_lines.first.destroy

        result = ActiveRecord::Base.connection.execute "SELECT #{Entry.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 0
      end
    end

    context "with Cargowise entries" do
      let! (:invoice) {
        broker_invoice = Factory(:broker_invoice, entry: entry, source_system: "Cargowise")
        broker_invoice.broker_invoice_lines.create! charge_code: "200", charge_amount: "100", charge_description: "DUTY"
        broker_invoice.broker_invoice_lines.create! charge_code: "221", charge_amount: "200", charge_description: "MPF"
        broker_invoice.broker_invoice_lines.create! charge_code: "222", charge_amount: "300", charge_description: "HMF"
        broker_invoice.broker_invoice_lines.create! charge_code: "2", charge_amount: "200", charge_description: "NOT DUTY"
        broker_invoice
      }

      it "returns a subquery to calculate duty amount billed for an entry" do
        result = ActiveRecord::Base.connection.execute "SELECT #{Entry.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 600
      end

      it "returns 0 if no duty is billed" do
        invoice.broker_invoice_lines.each &:destroy
        invoice.broker_invoice_lines.create! charge_code: "2", charge_amount: "200", charge_description: "NOT DUTY"

        result = ActiveRecord::Base.connection.execute "SELECT #{Entry.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 0
      end
    end
    
  end
end
