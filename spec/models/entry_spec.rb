describe Entry do

  context "tracking_status" do
    context "fenix" do
      it "defaults to created" do
        expect(create(:entry, source_system: 'Fenix').tracking_status).to eq(Entry::TRACKING_STATUS_CREATED)
      end

      it "uses open for all non-V type entries with across_sent_date" do
        expect(create(:entry, source_system: 'Fenix', across_sent_date: Time.zone.now).tracking_status).to eq(Entry::TRACKING_STATUS_OPEN)
      end

      it "uses open for all V type entries" do
        expect(create(:entry, source_system: 'Fenix', entry_type: 'V').tracking_status).to eq(Entry::TRACKING_STATUS_OPEN)
      end

      it "does not override closed" do
        ent = create(:entry, source_system: 'Fenix', tracking_status: Entry::TRACKING_STATUS_CLOSED)
        ent.release_date = Time.zone.now
        ent.save!
        expect(ent.tracking_status).to eq(Entry::TRACKING_STATUS_CLOSED)
      end
    end

    context "alliance" do
      it "uses created for base entry" do
        create(:entry, source_system: 'Alliance').tracking_status == Entry::TRACKING_STATUS_CREATED
      end

      it "uses open for entries that have been filed" do
        create(:entry, source_system: 'Alliance', entry_filed_date: Time.zone.now).tracking_status == Entry::TRACKING_STATUS_OPEN
      end

      it "does not override closed" do
        ent = create(:entry, source_system: 'Alliance', tracking_status: Entry::TRACKING_STATUS_CLOSED)
        ent.entry_filed_date = Time.zone.now
        ent.save!
        expect(ent.tracking_status).to eq(Entry::TRACKING_STATUS_CLOSED)
      end
    end

    context "other" do
      it "defaults to open" do
        expect(create(:entry).tracking_status).to eq(Entry::TRACKING_STATUS_OPEN)
      end

      it "does not override closed" do
        ent = create(:entry, tracking_status: Entry::TRACKING_STATUS_CLOSED)
        ent.entry_filed_date = Time.zone.now
        ent.save!
        expect(ent.tracking_status).to eq(Entry::TRACKING_STATUS_CLOSED)
      end
    end
  end

  describe "link_broker_invoices" do
    subject { create(:entry, broker_reference: '5555', source_system: 'ABC') }

    it 'matches' do
      bi = BrokerInvoice.create!(broker_reference: '5555', invoice_number: 'notbrokref', source_system: 'ABC')
      subject.link_broker_invoices
      expect(subject.broker_invoices.first).to eq(bi)
    end

    it "does not match if source system doesn't match" do
      BrokerInvoice.create!(broker_reference: '5555', invoice_number: 'notbrokref', source_system: 'ZZ')
      subject.link_broker_invoices
      expect(subject.broker_invoices.count).to eq(0)
    end

    it "does not match if broker_reference doesn't match" do
      BrokerInvoice.create!(broker_reference: 'XX', invoice_number: 'notbrokref', source_system: 'ABC')
      subject.link_broker_invoices
      expect(subject.broker_invoices.count).to eq(0)
    end
  end

  describe 'ocean?' do
    it "returns false for nil transport mode" do
      expect(described_class.new).not_to be_ocean
    end

    it "returns true for 10" do
      expect(described_class.new(transport_mode_code: "10")).to be_ocean
    end

    it "returns true for 11" do
      expect(described_class.new(transport_mode_code: "11")).to be_ocean
    end

    it "returns false for any other value" do
      expect(described_class.new(transport_mode_code: "40")).not_to be_ocean
    end
  end

  describe 'air?' do
    it "returns false for nil transport mode" do
      expect(subject).not_to be_air
    end

    it "returns true for 10" do
      expect(described_class.new(transport_mode_code: "40")).to be_air
    end

    it "returns true for 11" do
      expect(described_class.new(transport_mode_code: "41")).to be_air
    end

    it "returns false for any other value" do
      expect(described_class.new(transport_mode_code: "10")).not_to be_air
    end
  end

  context 'security' do
    let! (:master_setup) do
      ms = stub_master_setup
      allow(ms).to receive(:entry_enabled?).and_return true
      allow(ms).to receive(:entry_enabled).and_return true
      ms
    end
    let (:importer) { create(:importer) }
    let (:linked_importer) do
      child_importer = create(:importer)
      importer.linked_companies << child_importer
      child_importer
    end
    let (:entry) { create(:entry, importer: importer) }
    let (:importer_user) do
      user = create(:user, company: importer)
      allow(user).to receive(:view_entries?).and_return true
      user
    end

    describe "can_view_importer?" do

      it "allows same company" do
        expect(described_class.can_view_importer?(importer, importer_user)).to eq true
      end

      it "does not allow different company" do
        expect(described_class.can_view_importer?(create(:company), importer_user)).to eq false
      end

      it "allows master" do
        master_user = create(:master_user)
        expect(master_user).to receive(:view_entries?).and_return(true)
        expect(described_class.can_view_importer?(importer, master_user)).to eq true
      end

      it "allows linked" do
        expect(described_class.can_view_importer?(linked_importer, importer_user)).to eq true
      end

      it "does not allow nil importer" do
        expect(described_class.can_view_importer?(nil, importer_user)).to eq false
      end

      it "does not allow master user access to nil importer by default" do
        master_user = create(:master_user)
        expect(master_user).to receive(:view_entries?).and_return(true)
        expect(described_class.can_view_importer?(nil, master_user)).to eq false
      end

      it "allows master user access to nil importer if requested" do
        master_user = create(:master_user)
        expect(master_user).to receive(:view_entries?).and_return(true)
        expect(described_class.can_view_importer?(nil, master_user, allow_nil_importer: true)).to eq true
      end
    end

    context 'search secure' do
      let! (:entry_2) { create(:entry, importer: create(:company, importer: true)) }

      before do
        entry
      end

      it 'restricts non master' do
        found = described_class.search_secure(importer_user, described_class).all
        expect(found.entries.size).to eq(1)
        expect(found.first).to eq(entry)
      end

      it "allows linked company for non master" do
        importer2 = create(:company, importer: true)
        importer.linked_companies << importer2
        e2 = create(:entry, importer_id: importer.id)
        entries = described_class.search_secure(importer_user, described_class).all.to_a
        expect(entries).to include entry
        expect(entries).to include e2
      end

      it 'allows all for master' do
        u = create(:user, entry_view: true)
        u.company.update!(master: true)
        found = described_class.search_secure(u, described_class).all
        expect(found.entries.size).to eq(2)
      end
    end

    it 'allows importer user with permission to view/edit/comment/attach' do
      importer_user.update!(entry_view: true, entry_comment: true, entry_edit: true, entry_attach: true)
      expect(entry.can_view?(importer_user)).to eq true
      expect(entry.can_edit?(importer_user)).to eq false # hard coded to false
      expect(entry.can_attach?(importer_user)).to eq true
      expect(entry.can_comment?(importer_user)).to eq true
    end

    it 'allows importer from parent company to view/edit/comment/attach' do
      parent_company = create(:company, importer: true)
      parent_user = create(:user, company: parent_company, entry_view: true, entry_comment: true, entry_edit: true, entry_attach: true)
      parent_company.linked_companies << importer
      expect(entry.can_view?(parent_user)).to eq true
      expect(entry.can_edit?(parent_user)).to eq false # hard coded to false
      expect(entry.can_attach?(parent_user)).to eq true
      expect(entry.can_comment?(parent_user)).to eq true
    end

    it 'does not allow a user from a different company with overall permission to view/edit/comment/attach' do
      u = create(:user, entry_view: true, entry_comment: true, entry_edit: true, entry_attach: true)
      u.company.update!(importer: true)
      expect(entry.can_view?(u)).to eq false
      expect(entry.can_edit?(u)).to eq false
      expect(entry.can_attach?(u)).to eq false
      expect(entry.can_comment?(u)).to eq false
    end

    it 'allows master user to view' do
      u = create(:user, entry_view: true)
      u.company.update!(master: true)
      expect(entry.can_view?(u)).to eq true
    end

    it "does not allow non-master user to view importerless entry" do
      entry.update! importer_id: nil
      expect(entry.can_view?(importer_user)).to eq false
    end

    it "allows master user to view importerless entry" do
      entry.update! importer_id: nil
      u = create(:master_user, entry_view: true)

      expect(entry.can_view?(u)).to eq true
    end

    it 'allows user to comment' do
      u = create(:user, entry_comment: true)
      u.company.update!(master: true)
      allow(u).to receive(:view_entries?).and_return true
      expect(create(:entry, importer: create(:company, importer: true)).can_comment?(u)).to eq true
    end

    it 'does not allow user w/o permission to comment' do
      u = create(:user, entry_comment: false)
      u.company.update!(master: true)
      expect(create(:entry, importer: create(:company, importer: true)).can_comment?(u)).to eq false
    end

    it 'allows user to attach' do
      u = create(:user, entry_attach: true)
      u.company.update!(master: true)
      allow(u).to receive(:view_entries?).and_return true
      expect(create(:entry, importer: create(:company, importer: true)).can_attach?(u)).to eq true
    end

    it 'does not allow user w/o permisstion to attach' do
      u = create(:user, entry_attach: false)
      u.company.update!(master: true)
      expect(create(:entry, importer: create(:company, importer: true)).can_attach?(u)).to eq false
    end
  end

  context 'ports' do
    let (:port) { create(:port) }

    it 'finds matching lading port' do
      ent = create(:entry, lading_port_code: port.schedule_k_code)
      expect(ent.lading_port).to eq(port)
    end

    it 'finds matching unlading port' do
      expect(create(:entry, unlading_port_code: port.schedule_d_code).unlading_port).to eq(port)
    end

    it 'finds matching entry port' do
      expect(create(:entry, entry_port_code: port.schedule_d_code).entry_port).to eq(port)
    end

    it 'finds matching us exit port' do
      expect(create(:entry, us_exit_port_code: port.schedule_d_code).us_exit_port).to eq(port)
    end
  end

  context "update_k84_month" do
    subject { create(:entry) }

    it "sets k84 month" do
      subject.update! cadex_accept_date: Time.zone.parse("2013-01-01")
      expect(subject.k84_month).to eq 1
      expect(subject.k84_due_date.to_date).to eq(Date.new(2013, 1, 25))
    end

    it "sets k84 month to next month if cadex accept is 25th or later" do
      subject.update! cadex_accept_date: Time.zone.parse("2013-01-25")
      expect(subject.k84_month).to eq 2
      expect(subject.k84_due_date.to_date).to eq(Date.new(2013, 2, 25))
    end

    it "sets k84 month to 1 if cadex accept is after Dec 24th" do
      subject.update! cadex_accept_date: Time.zone.parse("2013-12-25")
      expect(subject.k84_due_date.to_date).to eq(Date.new(2014, 1, 25))
      expect(subject.k84_month).to eq 1
    end

    it "uses k84 receive date for manual low-value entries, rather than cadex accept" do
      subject.update! k84_receive_date: Time.zone.parse("2013-01-01"), entry_number: "119810123459", entry_type: "V", cadex_accept_date: Time.zone.now
      expect(subject.k84_month).to eq 1
      expect(subject.k84_due_date.to_date).to eq(Date.new(2013, 1, 25))
    end

    it "uses k84 receive date for hand-carry entries, rather than cadex accept" do
      subject.update! k84_receive_date: Time.zone.parse("2013-01-01"), entry_number: "119810123459", entry_type: "C", cadex_accept_date: Time.zone.now
      expect(subject.k84_month).to eq 1
      expect(subject.k84_due_date.to_date).to eq(Date.new(2013, 1, 25))
    end

    it "uses k84 receive date for entry addendums, rather than cadex accept" do
      subject.update! k84_receive_date: Time.zone.parse("2013-01-01"), entry_number: "119810123459", entry_type: "H", cadex_accept_date: Time.zone.now
      expect(subject.k84_month).to eq 1
      expect(subject.k84_due_date.to_date).to eq(Date.new(2013, 1, 25))
    end

    it "uses k84 month and due date to find the payment due date" do
      calendar = create(:calendar, calendar_type: 'K84Due', year: 2013)
      create(:calendar_event, event_date: Date.parse('2013-01-29'), calendar_id: calendar.id)

      subject.update! k84_receive_date: Time.zone.parse("2013-01-01"), entry_number: "119810123459", entry_type: "V", cadex_accept_date: Time.zone.now
      expect(subject.k84_month).to eq 1
      expect(subject.k84_due_date.to_date).to eq(Date.new(2013, 1, 25))
      expect(subject.k84_payment_due_date.to_date).to eq(Date.new(2013, 1, 29))
    end

    it "does not update the k84 payment due date if no calendar event is found" do
      subject.update! k84_receive_date: Time.zone.parse("2013-01-01"), entry_number: "119810123459", entry_type: "C", cadex_accept_date: Time.zone.now
      expect(subject.k84_month).to eq 1
      expect(subject.k84_due_date.to_date).to eq(Date.new(2013, 1, 25))
      expect(subject.k84_payment_due_date).to be_nil
    end
  end

  describe "value_for_tax" do
    let(:ci1) do
      create(:commercial_invoice, commercial_invoice_lines:
      [create(:commercial_invoice_line,
               commercial_invoice_tariffs: [create(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: 1234)]),
      create(:commercial_invoice_line,
              commercial_invoice_tariffs: [create(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: 1234)])
      ])
    end
    let(:ci2) do
      create(:commercial_invoice, commercial_invoice_lines:
      [create(:commercial_invoice_line,
               commercial_invoice_tariffs: [create(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: nil)]),
      create(:commercial_invoice_line,
              commercial_invoice_tariffs: [create(:commercial_invoice_tariff, duty_amount: 1, entered_value: 2, value_for_duty_code: 1234)])
      ])
    end

    it 'sums all commercial invoice tariff values associated with the entry' do
      e = described_class.new
      c = Country.new
      c.iso_code = "CA"; c.save!
      e.import_country = c
      e.commercial_invoices = [ci1]
      expect(e.value_for_tax).to eq BigDecimal "6"
    end

    it 'does not return anything if the entry is not Candian' do
      e = described_class.new
      c = Country.new
      c.iso_code = "US"; c.save!
      e.import_country = c
      e.commercial_invoices = [ci2]
      expect(e.value_for_tax).to be_nil
    end
  end

  describe "american?" do
    it 'identifies as American if import country is US' do
      e = described_class.new
      c = Country.new
      c.iso_code = "US"
      e.import_country = c
      expect(e).to be_american

      e.import_country.iso_code = "CA"
      expect(e).not_to be_american
      e.import_country = nil
      expect(e).not_to be_american
    end
  end

  describe "canadian?" do
    it 'identifies as canadian if import country is CA' do
      e = described_class.new
      c = Country.new
      c.iso_code = "CA"
      e.import_country = c
      expect(e).to be_canadian

      e.import_country.iso_code = "US"
      expect(e).not_to be_canadian
      e.import_country = nil
      expect(e).not_to be_canadian
    end
  end

  describe "entry_port" do

    it 'returns Candian ports for Canadian imports' do
      e = described_class.new; c = Country.new; p_ca = Port.new(name: "Montreal"); p_us = Port.new(name: "Houston")
      c.iso_code = "CA"; c.save!
      e.us_entry_port = p_us; e.ca_entry_port = p_ca; e.import_country = c

      expect(e.entry_port).to eq(p_ca)
    end

    it 'returns US ports for US imports' do
      e = described_class.new; c = Country.new; p_ca = Port.new(name: "Montreal"); p_us = Port.new(name: "Houston")
      c.iso_code = "US"; c.save!
      e.us_entry_port = p_us; e.ca_entry_port = p_ca; e.import_country = c

      expect(e.entry_port).to eq(p_us)
    end

  end

  describe "purged?" do
    context "with existing purge record" do
       before do
        EntryPurge.create! source_system: "Source", broker_reference: "12345", date_purged: Time.zone.parse("2015-04-01 00:00")
       end

       it "reports purged if an entry purge record exists with a purge date after the given time" do
         expect(described_class).to be_purged('Source', '12345', Time.zone.parse("2015-03-31 00:00"))
       end

       it "reports not purged if an entry purge record exists with a purge date prior the given system export time" do
         expect(described_class).not_to be_purged('Source', '12345', Time.zone.parse("2015-04-01 10:00"))
       end
    end

    it "reports not purged if no purge record exists" do
      expect(described_class).not_to be_purged('Source', '12345', Time.zone.parse("2015-03-31 00:00"))
    end
  end

  describe "purge!" do
    let (:entry) { create(:entry, broker_reference: "12345", source_system: "SOURCE", import_country: country)}
    let (:country) { create(:country, iso_code: "ZZ") }

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
      entry.update! import_country: nil

      entry.purge!
      purge = EntryPurge.where(broker_reference: "12345").first
      expect(purge).not_to be_nil
      expect(purge.country_iso).to be_nil
    end
  end

  describe "first_sale_savings" do
    it "returns the sum of first-sale savings on all child invoices" do
      ent = create(:entry)
      inv = create(:commercial_invoice, entry: ent)
      create(:commercial_invoice_line, commercial_invoice: inv, contract_amount: 500, value: 200,
                                        commercial_invoice_tariffs: [create(:commercial_invoice_tariff, duty_amount: 30, entered_value: 10)])
      create(:commercial_invoice_line, commercial_invoice: inv, contract_amount: 250, value: 100,
                                        commercial_invoice_tariffs: [create(:commercial_invoice_tariff, duty_amount: 15, entered_value: 5)])
      create(:commercial_invoice_line, commercial_invoice: inv, contract_amount: nil, value: 100,
                                        commercial_invoice_tariffs: [create(:commercial_invoice_tariff, duty_amount: 15, entered_value: 5)])
      expect(ent.first_sale_savings).to eq 1350
    end
  end

  context "hold date / hold release date" do
    context "US" do
      let(:co) { create(:country, iso_code: "US") }

      describe "hold_attributes" do
        it "returns list of matching PGA hold and release dates" do
          e = create(:entry)
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
          now = time_now
          yesterday = now - 1.day
          e = create(:entry, import_country: co, aphis_hold_date: yesterday, aphis_hold_release_date: yesterday, cbp_hold_date: now, nmfs_hold_date: nil)
          expect(e.populated_holds).to eq [{hold: { mfid: :ent_aphis_hold_date, attribute: :aphis_hold_date, value: yesterday},
                                            release: { mfid: :ent_aphis_hold_release_date, attribute: :aphis_hold_release_date, value: yesterday}},
                                            {hold: {mfid: :ent_cbp_hold_date, attribute: :cbp_hold_date, value: now},
                                             release: {mfid: :ent_cbp_hold_release_date, attribute: :cbp_hold_release_date, value: nil}}]
        end
      end

      describe "active_holds" do
        it "returns list of hashes containing hold-release_date pairs where the hold date is populated but the hold release is not" do
          now = time_now
          yesterday = now - 1.day
          e = create(:entry, import_country: co, aphis_hold_date: yesterday, aphis_hold_release_date: yesterday, cbp_hold_date: now, nmfs_hold_date: nil)
          expect(e.active_holds).to eq [{hold: {mfid: :ent_cbp_hold_date, attribute: :cbp_hold_date, value: now},
                                         release: {mfid: :ent_cbp_hold_release_date, attribute: :cbp_hold_release_date, value: nil}}]
        end
      end
    end

    context "CA" do
      let(:co) { create(:country, iso_code: "CA") }

      describe "populated_holds" do
        it "throws exception" do
          e = create(:entry, import_country: co)
          expect {e.populated_holds}.to raise_error(RuntimeError, "Only valid for US entries!")
        end
      end

      describe "active_holds" do
        it "throws_exception" do
          e = create(:entry, import_country: co)
          expect {e.active_holds}.to raise_error(RuntimeError, "Only valid for US entries!")
        end
      end

      describe "hold_attributes" do
        it "throws exception" do
          e = create(:entry, import_country: co)
          expect {e.hold_attributes}.to raise_error(RuntimeError, "Only valid for US entries!")
        end
      end
    end
  end

  describe "split_release_option_value" do
    it "returns 'Hold All' when 1" do
      expect(described_class.new(split_release_option: "1").split_release_option_value).to eq "Hold All"
    end

    it "returns 'Incremental' when 2" do
      expect(described_class.new(split_release_option: "2").split_release_option_value).to eq "Incremental"
    end

    it "returns '' when nil" do
      expect(described_class.new.split_release_option_value).to eq ""
    end
  end

  describe "total_duty_taxes_fees_amount" do

    subject do
      described_class.new total_duty: BigDecimal("1"), total_taxes: BigDecimal("2"), total_fees: BigDecimal("3"), total_add: BigDecimal("4"), total_cvd: BigDecimal("5")
    end

    it "returns sum of duty, taxes, fees, penalties" do
      expect(subject.total_duty_taxes_fees_amount).to eq BigDecimal("15")
    end

    it "handles nil values" do
      expect(described_class.new.total_duty_taxes_fees_amount).to eq BigDecimal('0')
    end
  end

  describe "split_shipment_date=" do
    let(:ent) { create(:entry, split_shipment_date: nil, split_shipment: nil) }
    let(:dt) { DateTime.new(2018, 3, 15, 15, 0) }

    it "also sets split_shipment flag to True when assigned" do
      ent.split_shipment_date = dt
      expect(ent.split_shipment_date).to eq dt
      expect(ent.split_shipment).to eq true
    end

    it "also sets split_shipment flag to False when unassigned" do
      ent.update! split_shipment_date: dt, split_shipment: true
      ent.split_shipment_date = nil
      expect(ent.split_shipment_date).to be_nil
      expect(ent.split_shipment).to eq false
    end
  end

  describe "get_transport_mode_codes_us_ca" do
    it "converts mode descriptor to numeric codes" do
      expect(described_class.get_transport_mode_codes_us_ca('Air')).to eq [40, 41, 1]
      expect(described_class.get_transport_mode_codes_us_ca('Sea')).to eq [10, 11, 9]
      expect(described_class.get_transport_mode_codes_us_ca('Rail')).to eq [20, 21, 6]
      expect(described_class.get_transport_mode_codes_us_ca('Truck')).to eq [30, 31, 2]
      expect(described_class.get_transport_mode_codes_us_ca('Dirigible')).to eq []
      expect(described_class.get_transport_mode_codes_us_ca('air')).to eq [40, 41, 1]
      expect(described_class.get_transport_mode_codes_us_ca('AIR')).to eq [40, 41, 1]
      expect(described_class.get_transport_mode_codes_us_ca(nil)).to eq []
    end
  end

  describe "get_transport_mode_name_lookup_us_ca" do
    it "returns hash with numeric codes as keys, mode descriptors as values" do
      expect(described_class.get_transport_mode_name_lookup_us_ca).to eq({1 => "AIR", 40 => "AIR", 41 => "AIR",
                                                                          9 => "SEA", 10 => "SEA", 11 => "SEA",
                                                                          6 => "RAIL", 20 => "RAIL", 21 => "RAIL",
                                                                          2 => "TRUCK", 30 => "TRUCK", 31 => "TRUCK"})
    end
  end

  describe "ocean_mode?" do
    [10, 11, 9].each do |code|
      it "returns true for #{code}" do
        e = described_class.new transport_mode_code: code
        expect(e.ocean_mode?).to eq true
      end
    end

    it "returns false for non-ocean codes" do
      e = described_class.new transport_mode_code: 1
      expect(e.ocean_mode?).to eq false
    end

    it "returns false for blank codes" do
      expect(described_class.new.ocean_mode?).to eq false
    end
  end

  describe "air_mode?" do
    [40, 41, 1].each do |code|
      it "returns true for #{code}" do
        e = described_class.new transport_mode_code: code
        expect(e.air_mode?).to eq true
      end
    end

    it "returns false for non-air codes" do
      e = described_class.new transport_mode_code: 100
      expect(e.air_mode?).to eq false
    end

    it "returns false for blank codes" do
      expect(described_class.new.air_mode?).to eq false
    end
  end

  describe "rail_mode?" do
    [20, 21, 6].each do |code|
      it "returns true for #{code}" do
        e = described_class.new transport_mode_code: code
        expect(e.rail_mode?).to eq true
      end
    end

    it "returns false for non-rail codes" do
      e = described_class.new transport_mode_code: 100
      expect(e.rail_mode?).to eq false
    end

    it "returns false for blank codes" do
      expect(described_class.new.rail_mode?).to eq false
    end
  end

  describe "truck_mode?" do
    [30, 31, 2].each do |code|
      it "returns true for #{code}" do
        e = described_class.new transport_mode_code: code
        expect(e.truck_mode?).to eq true
      end
    end

    it "returns false for non-truck codes" do
      e = described_class.new transport_mode_code: 100
      expect(e.truck_mode?).to eq false
    end

    it "returns false for blank codes" do
      expect(described_class.new.truck_mode?).to eq false
    end
  end

  describe "destroy_commercial_invoices" do
    it "destroys all commercial invoices under the entry" do
      entry = create(:entry)
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
    let (:entry) { described_class.new}
    let (:invoice_1) do
      invoice = BrokerInvoice.new
      entry.broker_invoices << invoice
      invoice
    end

    let (:invoice_2) do
      invoice = BrokerInvoice.new
      entry.broker_invoices << invoice
      invoice
    end

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

    let (:entry) do
      create(:entry, broker_reference: "1234")
    end

    context "with Customs Management entries" do
      let! (:invoice) do
        broker_invoice = create(:broker_invoice, entry: entry, source_system: "Alliance")
        broker_invoice.broker_invoice_lines.create! charge_code: "0001", charge_amount: "100", charge_description: "DUTY"
        broker_invoice.broker_invoice_lines.create! charge_code: "0002", charge_amount: "200", charge_description: "NOT DUTY"
        broker_invoice
      end

      it "returns a subquery to calculate duty amount billed for an entry" do
        result = ActiveRecord::Base.connection.execute "SELECT #{described_class.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 100
      end

      it "returns 0 if no duty is billed" do
        invoice.broker_invoice_lines.first.destroy

        result = ActiveRecord::Base.connection.execute "SELECT #{described_class.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 0
      end
    end

    context "with Fenix entries" do
      let! (:invoice) do
        broker_invoice = create(:broker_invoice, entry: entry, source_system: "Fenix")
        broker_invoice.broker_invoice_lines.create! charge_code: "1", charge_amount: "100", charge_description: "DUTY"
        broker_invoice.broker_invoice_lines.create! charge_code: "2", charge_amount: "200", charge_description: "NOT DUTY"
        broker_invoice
      end

      it "returns a subquery to calculate duty amount billed for an entry" do
        result = ActiveRecord::Base.connection.execute "SELECT #{described_class.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 100
      end

      it "returns 0 if no duty is billed" do
        invoice.broker_invoice_lines.first.destroy

        result = ActiveRecord::Base.connection.execute "SELECT #{described_class.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 0
      end
    end

    context "with Cargowise entries" do
      let! (:invoice) do
        broker_invoice = create(:broker_invoice, entry: entry, source_system: "Cargowise")
        broker_invoice.broker_invoice_lines.create! charge_code: "200", charge_amount: "100", charge_description: "DUTY"
        broker_invoice.broker_invoice_lines.create! charge_code: "221", charge_amount: "200", charge_description: "MPF"
        broker_invoice.broker_invoice_lines.create! charge_code: "222", charge_amount: "300", charge_description: "HMF"
        broker_invoice.broker_invoice_lines.create! charge_code: "2", charge_amount: "200", charge_description: "NOT DUTY"
        broker_invoice
      end

      it "returns a subquery to calculate duty amount billed for an entry" do
        result = ActiveRecord::Base.connection.execute "SELECT #{described_class.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 600
      end

      it "returns 0 if no duty is billed" do
        invoice.broker_invoice_lines.each(&:destroy)
        invoice.broker_invoice_lines.create! charge_code: "2", charge_amount: "200", charge_description: "NOT DUTY"

        result = ActiveRecord::Base.connection.execute "SELECT #{described_class.total_duty_billed_subquery} FROM entries WHERE entries.id = #{entry.id}"
        expect(result.first[0]).to eq 0
      end
    end

  end

  describe "calculate_cbp_check_digit" do
    it "calculates check digit using CATAIR example" do
      expect(described_class.calculate_cbp_check_digit("B76", "324527")).to eq "8"
    end

    it "calculates check digit for 316 filer code" do
      expect(described_class.calculate_cbp_check_digit("316", "2509314")).to eq "6"
    end

    it "calculates check digit for 595 filer code" do
      expect(described_class.calculate_cbp_check_digit("595", "5663812")).to eq "6"
    end

    it "calculates check digits that evaluate to 10" do
      expect(described_class.calculate_cbp_check_digit("316", "0000504")).to eq "0"
    end
  end

  describe "format_entry_number" do
    it "formats an entry number" do
      expect(described_class.format_entry_number("31679758714")).to eq "316-7975871-4"
      expect(described_class.format_entry_number("316-7975871-4")).to eq "316-7975871-4"
      expect(described_class.format_entry_number("316.7975871.4")).to eq "316-7975871-4"
      expect(described_class.format_entry_number("3167975874")).to eq "316-797587-4"
      expect(described_class.format_entry_number("3167")).to eq "3167"
      expect(described_class.format_entry_number("ALL ALPHA")).to eq "ALL ALPHA"
      expect(described_class.format_entry_number(nil)).to eq nil
    end
  end

  describe "format_importer_tax_id" do
    it "formats an importer tax ID" do
      expect(described_class.format_importer_tax_id("31679758714")).to eq "31-679758714"
      expect(described_class.format_importer_tax_id("31-679758714")).to eq "31-679758714"
      expect(described_class.format_importer_tax_id("31.679758714")).to eq "31-679758714"
      expect(described_class.format_importer_tax_id("3167975874")).to eq "31-67975874"
      expect(described_class.format_importer_tax_id("31")).to eq "31"
      expect(described_class.format_importer_tax_id("ALL ALPHA")).to eq "ALL ALPHA"
      expect(described_class.format_importer_tax_id(nil)).to eq nil
    end
  end

  describe "includes_pga_summary_for_agency?" do
    it "returns true when agency code is found in PGA summaries, false when it's not" do
      ent = create(:entry)
      ent.entry_pga_summaries.build(agency_code: "FDA", total_claimed_pga_lines: 0)
      ent.entry_pga_summaries.build(agency_code: "epa", total_claimed_pga_lines: 0)

      expect(ent.includes_pga_summary_for_agency?("fda")).to eq true
      expect(ent.includes_pga_summary_for_agency?("FDA")).to eq true
      expect(ent.includes_pga_summary_for_agency?("epa")).to eq true
      expect(ent.includes_pga_summary_for_agency?("EPA")).to eq true
      expect(ent.includes_pga_summary_for_agency?(nil)).to eq false
      expect(ent.includes_pga_summary_for_agency?("FBI")).to eq false
      expect(ent.includes_pga_summary_for_agency?(["fDa", "FBI"])).to eq true
      expect(ent.includes_pga_summary_for_agency?(["fbi", "EPA", "ALF"])).to eq true
      expect(ent.includes_pga_summary_for_agency?(["FBI", "ALF"])).to eq false
      expect(ent.includes_pga_summary_for_agency?([])).to eq false
    end

    it "factors total claimed PGA line count into the comparison when told to do so" do
      ent = create(:entry)
      ent.entry_pga_summaries.build(agency_code: "FDA", total_claimed_pga_lines: 1)
      ent.entry_pga_summaries.build(agency_code: "EPA", total_claimed_pga_lines: 0)

      expect(ent.includes_pga_summary_for_agency?("FDA", claimed_pga_lines_only: true)).to eq true
      expect(ent.includes_pga_summary_for_agency?("EPA", claimed_pga_lines_only: true)).to eq false
      expect(ent.includes_pga_summary_for_agency?("EPA", claimed_pga_lines_only: false)).to eq true
    end
  end

  describe "matching_entry_comments?" do
    it "returns true when a comments record matches a pattern" do
      ent = create(:entry)
      ent.entry_comments.build(body: "STMNT DATA ACCEPTED AS REQUESTED Type 6 08/31/20")
      ent.entry_comments.build(body: "EPA TS1 Ln 1 PG 1 Dsp: 07 MAY PROCEED", username: "CUSTOMS")
      ent.entry_comments.build(username: "KC Abi Send")

      expect(ent.matching_entry_comments?(/^EPA .*MAY PROCEED/)).to eq true
      expect(ent.matching_entry_comments?(/^EPA .*JUNE PROCEED/)).to eq false
      expect(ent.matching_entry_comments?(/^EPA .*MAY PROCEED/, username: "CUSTOMS")).to eq true
      expect(ent.matching_entry_comments?(/^EPA .*MAY PROCEED/, username: "customs")).to eq true
      expect(ent.matching_entry_comments?(/^EPA .*MAY PROCEED/, username: "TOMSCUS")).to eq false
    end
  end

  describe "search_where_by_company_id" do

    subject { described_class }

    let (:importer) { create(:importer) }
    let (:broker) { create(:broker) }
    let! (:entry) { create(:entry, importer: importer, broker: broker) }

    it "returns a where clause that will return an entry linked to an importer user's company" do
      user = create(:user, company: importer)
      expect(described_class.where(subject.search_where_by_company_id(user.company.id)).to_a).to include entry
    end

    it "returns a where clause that will return an entry linked to an importer user's linked company" do
      user = create(:user)
      user.company.linked_companies << importer

      expect(described_class.where(subject.search_where_by_company_id(user.company.id)).to_a).to include entry
    end

    it "returns a where clause that will return an entry linked to a broker user's company" do
      user = create(:user, company: broker)
      expect(described_class.where(subject.search_where_by_company_id(user.company.id)).to_a).to include entry
    end

    it "returns a where clause that will return an entry linked to an broker user's linked company" do
      user = create(:user)
      user.company.linked_companies << broker

      expect(described_class.where(subject.search_where_by_company_id(user.company.id)).to_a).to include entry
    end

    it "returns a where clause that will return any entry if user belongs to the master company" do
      user = create(:master_user)
      expect(described_class.where(subject.search_where_by_company_id(user.company.id)).to_a).to include entry
    end

    it "returns a where clause that will not return a match if user doesn't match importer / broker companies" do
      expect(described_class.where(subject.search_where_by_company_id(create(:user).company.id)).to_a).to be_blank
    end
  end

  describe "can_view?" do

    subject { entry }

    let! (:master_setup) do
      ms = stub_master_setup
      allow(ms).to receive(:entry_enabled?).and_return true
      allow(ms).to receive(:entry_enabled).and_return true
      ms
    end

    let! (:user) do
      user = create(:user)
      allow(user).to receive(:view_entries?).and_return true
      user
    end

    let (:importer) { create(:importer) }
    let (:broker) { create(:broker) }
    let! (:entry) { create(:entry, importer: importer, broker: broker) }

    it "returns false if user is not related to parties on the entry" do
      expect(subject.can_view?(user)).to eq false
    end

    it "returns true if user is master" do
      user.company.update! master: true
      expect(subject.can_view?(user)).to eq true
    end

    it "returns false if user cannot view entries" do
      user.company.update! master: true
      expect(user).to receive(:view_entries?).and_return false
      expect(subject.can_view?(user)).to eq false
    end

    it "returns true if user belongs to importer company" do
      user.update! company_id: importer.id
      expect(subject.can_view?(user)).to eq true
    end

    it "returns true if user's company is linked to the importer" do
      user.company.linked_companies << importer
      expect(subject.can_view?(user)).to eq true
    end

    it "returns true if belongs to the broker company" do
      user.update! company_id: broker.id
      expect(subject.can_view?(user)).to eq true
    end

    it "returns true if user is linked to the broker" do
      user.company.linked_companies << broker
      expect(subject.can_view?(user)).to eq true
    end
  end

  describe "entry_filer" do
    it "returns first 3 chars of US entry number" do
      ent = create(:entry, entry_number: "12345678")
      expect(ent).to receive(:canadian?).and_return false

      expect(ent.entry_filer).to eq "123"
    end

    it "returns first 5 chars of Canada entry number" do
      ent = create(:entry, entry_number: "12345678")
      expect(ent).to receive(:canadian?).and_return true

      expect(ent.entry_filer).to eq "12345"
    end

    it "returns all chars of a short entry number" do
      ent = create(:entry, entry_number: "12")
      expect(ent).to receive(:canadian?).and_return false

      expect(ent.entry_filer).to eq "12"
    end

    it "returns nil for a nil entry number" do
      ent = create(:entry, entry_number: nil)

      expect(ent.entry_filer).to be_nil
    end

    it "returns nil for a blank entry number" do
      ent = create(:entry, entry_number: "         ")

      expect(ent.entry_filer).to be_nil
    end
  end

  describe "post_summary_correction?" do
    it "returns true when 1+ commercial invoice line under an entry has PSC date set" do
      ent = create(:entry)
      ci_1 = ent.commercial_invoices.create!
      ci_1.commercial_invoice_lines.create! psc_date: nil
      cil_1b = ci_1.commercial_invoice_lines.create! psc_date: Time.zone.now
      ci_2 = ent.commercial_invoices.create!
      cil_2 = ci_2.commercial_invoice_lines.create! psc_date: nil

      expect(ent.post_summary_correction?).to eq true

      cil_2.update! psc_date: Time.zone.now

      expect(ent.post_summary_correction?).to eq true

      cil_1b.update! psc_date: nil
      cil_2.update! psc_date: nil

      expect(ent.post_summary_correction?).to eq false
    end
  end
end
