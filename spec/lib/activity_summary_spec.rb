describe OpenChain::ActivitySummary do
  let! (:us) { Factory(:country, iso_code: 'US') }
  let! (:ca) { Factory(:country, iso_code: 'CA') }

  describe "generate_us_entry_summary" do
    it "creates json" do
      ent = Factory(:entry, import_country_id: us.id, importer_id: Factory(:company).id, first_release_received_date: '2013-12-25 05:00:00 UTC')
      h = described_class.generate_us_entry_summary(ent.importer_id, Time.zone.parse('2013-12-27 16:00:00 UTC'))
      expect(h['activity_summary']['summary']['1w']['count']).to eq(1)
    end
  end

  describe "generate_ca_entry_summary" do
    it "creates json" do
      ent = Factory(:entry, import_country_id: ca.id, importer_id: Factory(:company).id, release_date: '2013-12-25 05:00:00 UTC')
      h = described_class.generate_ca_entry_summary(ent.importer_id, Time.zone.parse('2013-12-27 16:00:00 UTC'))
      expect(h['activity_summary']['summary']['1w']['count']).to eq(1)
    end
  end

  describe OpenChain::ActivitySummary::CAEntrySummaryGenerator do

    it "creates summary section" do
      importer = Factory(:company)

      Factory(:entry, import_country_id: ca.id, importer_id: importer.id, arrival_date: '2013-12-24 05:00:00 UTC', release_date: '2013-12-25 05:00:00 UTC',
                      total_duty: 100, total_gst: 50, total_duty_gst: 150, entered_value: 1000, total_invoiced_value: 1100, total_units: 70)
      Factory(:entry, import_country_id: ca.id, importer_id: importer.id, arrival_date: '2013-12-14 05:00:00 UTC', release_date: '2013-12-15 05:00:00 UTC',
                      total_duty: 200, total_gst: 75, total_duty_gst: 275, entered_value: 1500, total_invoiced_value: 1600, total_units: 40)
      Factory(:entry, import_country_id: ca.id, importer_id: importer.id, arrival_date: '2013-12-17 05:00:00 UTC', file_logged_date: '2013-12-18 05:00:00 UTC',
                      on_hold: true, total_duty: 50, total_gst: 40, total_duty_gst: 90, entered_value: 60, total_invoiced_value: 66, total_units: 3)
      Factory(:entry, import_country_id: ca.id, importer_id: importer.id, arrival_date: '2012-12-24 05:00:00 UTC', release_date: '2012-12-25 05:00:00 UTC',
                      total_duty: 200, total_gst: 75, total_duty_gst: 275, entered_value: 1500, total_invoiced_value: 1600, total_units: 40)

      h = described_class.new.generate_hash importer.id, Time.zone.parse('2013-12-27 16:00:00 UTC')
      expect(h['summary']['1w']['count']).to eq(1)
      expect(h['summary']['1w']['duty']).to eq(100)
      expect(h['summary']['1w']['gst']).to eq(50)
      expect(h['summary']['1w']['duty_gst']).to eq(150)
      expect(h['summary']['1w']['entered']).to eq(1000)
      expect(h['summary']['1w']['invoiced']).to eq(1100)
      expect(h['summary']['1w']['units']).to eq(70)

      expect(h['summary']['4w']['count']).to eq(2)
      expect(h['summary']['4w']['duty']).to eq(300)
      expect(h['summary']['4w']['gst']).to eq(125)
      expect(h['summary']['4w']['duty_gst']).to eq(425)
      expect(h['summary']['4w']['entered']).to eq(2500)
      expect(h['summary']['4w']['invoiced']).to eq(2700)
      expect(h['summary']['4w']['units']).to eq(110)

      expect(h['summary']['holds']['count']).to eq(1)
      expect(h['summary']['holds']['duty']).to eq(50)
      expect(h['summary']['holds']['gst']).to eq(40)
      expect(h['summary']['holds']['duty_gst']).to eq(90)
      expect(h['summary']['holds']['entered']).to eq(60)
      expect(h['summary']['holds']['invoiced']).to eq(66)
      expect(h['summary']['holds']['units']).to eq(3)

      expect(h['summary']['open']['count']).to eq(1)
      expect(h['summary']['open']['duty']).to eq(50)
      expect(h['summary']['open']['gst']).to eq(40)
      expect(h['summary']['open']['duty_gst']).to eq(90)
      expect(h['summary']['open']['entered']).to eq(60)
      expect(h['summary']['open']['invoiced']).to eq(66)
      expect(h['summary']['open']['units']).to eq(3)

      expect(h['summary']['ytd']['count']).to eq(2)
      expect(h['summary']['ytd']['duty']).to eq(300)
      expect(h['summary']['ytd']['gst']).to eq(125)
      expect(h['summary']['ytd']['duty_gst']).to eq(425)
      expect(h['summary']['ytd']['entered']).to eq(2500)
      expect(h['summary']['ytd']['invoiced']).to eq(2700)
      expect(h['summary']['ytd']['units']).to eq(110)
    end

    it "creates k84 section" do
      importer = Factory(:company, name: 'IMP')
      Factory(:entry, k84_due_date: Date.new(2012, 12, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      Factory(:entry, k84_due_date: Date.new(2013, 1, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      Factory(:entry, k84_due_date: Date.new(2013, 1, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      Factory(:entry, k84_due_date: Date.new(2013, 1, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      Factory(:entry, k84_due_date: Date.new(2013, 2, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      Factory(:entry, k84_due_date: Date.new(2013, 2, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      Factory(:entry, k84_due_date: Date.new(2013, 2, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      Factory(:entry, k84_due_date: Date.new(2013, 3, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      Factory(:entry, k84_due_date: Date.new(2013, 3, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      Factory(:entry, k84_due_date: Date.new(2013, 3, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      Factory(:entry, k84_due_date: Date.new(2013, 3, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      # only find last 3, so don't find this one
      Factory(:entry, k84_due_date: Date.new(2012, 1, 25), total_duty_gst: 100, import_country_id: ca.id, importer_id: importer.id)
      h = described_class.new.generate_hash importer.id, Time.zone.parse('2013-02-25 16:00:00 UTC')
      k = h['k84']
      expect(k.size).to eq(4)
      expect(k[0]['importer_name']).to eq('IMP')
      expect(k[0]['due']).to eq(Date.new(2013, 3, 25))
      expect(k[0]['amount']).to eq(400)
      expect(k[1]['importer_name']).to eq('IMP')
      expect(k[1]['due']).to eq(Date.new(2013, 2, 25))
      expect(k[1]['amount']).to eq(300)
      expect(k[2]['importer_name']).to eq('IMP')
      expect(k[2]['due']).to eq(Date.new(2013, 1, 25))
      expect(k[2]['amount']).to eq(300)
      expect(k[3]['importer_name']).to eq('IMP')
      expect(k[3]['due']).to eq(Date.new(2012, 12, 25))
      expect(k[3]['amount']).to eq(100)
    end
  end

  describe OpenChain::ActivitySummary::USEntrySummaryGenerator do
    describe "generate_hash" do
      it "creates summary section" do
        importer = Factory(:company)

        Factory(:entry, import_country_id: us.id, importer_id: importer.id, transport_mode_code: 40, arrival_date: "2013-12-24 05:00:00 UTC",
                        first_release_received_date: '2013-12-25 05:00:00 UTC', total_duty: 100, total_fees: 50, entered_value:  1000,
                        total_invoiced_value: 1100, total_units: 70)
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, transport_mode_code: 10, arrival_date: "2013-12-14 05:00:00 UTC",
                        first_release_received_date: '2013-12-15 05:00:00 UTC', total_duty: 200, total_fees: 75, entered_value:  1500,
                        total_invoiced_value: 1600, total_units: 40)
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, transport_mode_code: 10, arrival_date: "2013-12-17 05:00:00 UTC",
                        file_logged_date: "2013-12-17 05:00:00 UTC", entry_filed_date: '2013-12-18 05:00:00 UTC', on_hold: true, total_duty: 50,
                        total_fees: 40, entered_value: 60, total_invoiced_value: 66, total_units: 3)
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, transport_mode_code: 10, arrival_date: "2012-12-24 05:00:00 UTC",
                        first_release_received_date: '2012-12-25 05:00:00 UTC', total_duty: 200, total_fees: 75, entered_value:  1500,
                        total_invoiced_value: 1600, total_units: 40)
        # don't find for wrong country
        Factory(:entry, import_country_id: Factory(:country).id, importer_id: importer.id, first_release_received_date: 2.days.ago, total_duty: 100,
                        total_fees: 50, entered_value: 1000, total_invoiced_value: 1100, total_units: 70)

        h = described_class.new.generate_hash importer.id, Time.zone.parse('2013-12-27 16:00:00 UTC')
        expect(h['summary']['1w']['count']).to eq(1)
        expect(h['summary']['1w']['duty']).to eq(100)
        expect(h['summary']['1w']['fees']).to eq(50)
        expect(h['summary']['1w']['entered']).to eq(1000)
        expect(h['summary']['1w']['invoiced']).to eq(1100)
        expect(h['summary']['1w']['units']).to eq(70)

        expect(h['summary']['4w']['count']).to eq(2)
        expect(h['summary']['4w']['duty']).to eq(300)
        expect(h['summary']['4w']['fees']).to eq(125)
        expect(h['summary']['4w']['entered']).to eq(2500)
        expect(h['summary']['4w']['invoiced']).to eq(2700)
        expect(h['summary']['4w']['units']).to eq(110)

        expect(h['summary']['holds']['count']).to eq(1)
        expect(h['summary']['holds']['duty']).to eq(50)
        expect(h['summary']['holds']['fees']).to eq(40)
        expect(h['summary']['holds']['entered']).to eq(60)
        expect(h['summary']['holds']['invoiced']).to eq(66)
        expect(h['summary']['holds']['units']).to eq(3)

        expect(h['summary']['open']['count']).to eq(1)
        expect(h['summary']['open']['duty']).to eq(50)
        expect(h['summary']['open']['fees']).to eq(40)
        expect(h['summary']['open']['entered']).to eq(60)
        expect(h['summary']['open']['invoiced']).to eq(66)
        expect(h['summary']['open']['units']).to eq(3)

        expect(h['summary']['ytd']['count']).to eq(2)
        expect(h['summary']['ytd']['duty']).to eq(300)
        expect(h['summary']['ytd']['fees']).to eq(125)
        expect(h['summary']['ytd']['entered']).to eq(2500)
        expect(h['summary']['ytd']['invoiced']).to eq(2700)
        expect(h['summary']['ytd']['units']).to eq(110)
      end

      it "does not include holds for files logged over a year ago" do
        importer = Factory(:company)
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, transport_mode_code: 10, arrival_date: "2013-12-17 05:00:00 UTC",
                        file_logged_date: "2013-12-17 05:00:00 UTC", entry_filed_date: '2013-12-18 05:00:00 UTC', on_hold: true, total_duty: 50,
                        total_fees: 40, entered_value: 60, total_invoiced_value: 66, total_units: 3)
        h = described_class.new.generate_hash importer.id, Time.zone.parse('2014-12-17 05:00:01 UTC')
        expect(h['summary']['holds']['count']).to eq(0)
      end

      it "creates statements section" do
        importer = Factory(:company, name: 'IMP')
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, monthly_statement_due_date: Date.new(2013, 12, 25),
                        monthly_statement_paid_date: nil, total_duty: 100, total_fees: 50)
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, monthly_statement_due_date: Date.new(2013, 11, 25),
                        monthly_statement_paid_date: Date.new(2013, 11, 24), total_duty: 200, total_fees: 100)
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, monthly_statement_due_date: Date.new(2013, 11, 25),
                        monthly_statement_paid_date: Date.new(2013, 11, 24), total_duty: 200, total_fees: 100)
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, monthly_statement_due_date: Date.new(2013, 10, 25),
                        monthly_statement_paid_date: Date.new(2013, 10, 24), total_duty: 200, total_fees: 100)
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, monthly_statement_due_date: Date.new(2013, 9, 25),
                        monthly_statement_paid_date: Date.new(2013, 9, 24), total_duty: 200, total_fees: 100)
        # next line won't be included since we only return record from next month and last 3
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, monthly_statement_due_date: Date.new(2013, 8, 24),
                        monthly_statement_paid_date: Date.new(2013, 8, 24), total_duty: 200, total_fees: 100)
        # don't find for wrong country
        Factory(:entry, import_country_id: Factory(:country).id, importer_id: importer.id, monthly_statement_due_date: Date.new(2013, 10, 25),
                        monthly_statement_paid_date: Date.new(2013, 10, 24), total_duty: 200, total_fees: 100)

        h = described_class.new.generate_hash importer.id, Time.zone.parse('2013-11-25 16:00:00 UTC')
        statements = h['pms']
        expect(statements.size).to eq(4)
        expect(statements[0]['importer_name']).to eq('IMP')
        expect(statements[0]['due']).to eq(Date.new(2013, 12, 25))
        expect(statements[0]['paid']).to be_nil
        expect(statements[0]['amount']).to eq(150)
        expect(statements[1]['importer_name']).to eq('IMP')
        expect(statements[1]['due']).to eq(Date.new(2013, 11, 25))
        expect(statements[1]['paid']).to eq(Date.new(2013, 11, 24))
        expect(statements[1]['amount']).to eq(600)
        expect(statements[2]['importer_name']).to eq('IMP')
        expect(statements[2]['due']).to eq(Date.new(2013, 10, 25))
        expect(statements[2]['paid']).to eq(Date.new(2013, 10, 24))
        expect(statements[2]['amount']).to eq(300)
        expect(statements[3]['importer_name']).to eq('IMP')
        expect(statements[3]['paid']).to eq(Date.new(2013, 9, 24))
        expect(statements[3]['amount']).to eq(300)
      end

      it "creates separate lines per importer_id" do
        imp1 = Factory(:company, name: 'imp1')
        Factory(:entry, import_country_id: us.id, importer_id: imp1.id, monthly_statement_due_date: Date.new(2013, 11, 25),
                        monthly_statement_paid_date: Date.new(2013, 11, 24), total_duty: 200, total_fees: 100)
        imp2 = Factory(:company, name: 'imp2') # linked
        Factory(:entry, import_country_id: us.id, importer_id: imp2.id, monthly_statement_due_date: Date.new(2013, 11, 25),
                        monthly_statement_paid_date: Date.new(2013, 11, 24), total_duty: 200, total_fees: 100)
        imp3 = Factory(:company, name: 'imp3') # not linked
        Factory(:entry, import_country_id: us.id, importer_id: imp3.id, monthly_statement_due_date: Date.new(2013, 11, 25),
                        monthly_statement_paid_date: Date.new(2013, 11, 24), total_duty: 200, total_fees: 100)

        imp1.linked_companies << imp2
        h = described_class.new.generate_hash imp1.id, Time.zone.parse('2013-11-25 16:00:00 UTC')
        statements = h['pms']
        expect(statements.length).to eq 2
        expect(statements[0]['importer_name']).to eq 'imp1'
        expect(statements[0]['amount']).to eq 300
        expect(statements[1]['importer_name']).to eq 'imp2'
        expect(statements[1]['amount']).to eq 300
      end

      it "creates top 5 vendors YTD" do
        importer = Factory(:company)
        ent1 = Factory(:entry, import_country_id: us.id, first_release_received_date: "2013-12-01", importer_id: importer.id)
        ci1 = Factory(:commercial_invoice, entry: ent1)
        cil1 = Factory(:commercial_invoice_line, vendor_name: 'V1', commercial_invoice: ci1)
        Factory(:commercial_invoice_tariff, entered_value: 100, commercial_invoice_line: cil1)
        Factory(:commercial_invoice_tariff, entered_value: 150, commercial_invoice_line: cil1)

        ent2 = Factory(:entry, import_country_id: us.id, first_release_received_date: "2013-11-01", importer_id: importer.id)
        ci2 = Factory(:commercial_invoice, entry: ent2)
        cil2 = Factory(:commercial_invoice_line, vendor_name: 'V1', commercial_invoice: ci2)
        Factory(:commercial_invoice_tariff, entered_value: 100, commercial_invoice_line: cil2)

        ent3 = Factory(:entry, import_country_id: us.id, first_release_received_date: "2013-12-01", importer_id: importer.id)
        ci3 = Factory(:commercial_invoice, entry: ent3)
        cil3 = Factory(:commercial_invoice_line, vendor_name: 'V2', commercial_invoice: ci3)
        Factory(:commercial_invoice_tariff, entered_value: 100, commercial_invoice_line: cil3)

        ent4 = Factory(:entry, import_country_id: us.id, first_release_received_date: "2012-11-01", importer_id: importer.id)
        ci4 = Factory(:commercial_invoice, entry: ent4)
        cil4 = Factory(:commercial_invoice_line, vendor_name: 'V1', commercial_invoice: ci4)
        Factory(:commercial_invoice_tariff, entered_value: 100, commercial_invoice_line: cil4)

        # don't find for wrong country
        ent5 = Factory(:entry, import_country_id: Factory(:country).id, first_release_received_date: "2013-12-01", importer_id: importer.id)
        ci5 = Factory(:commercial_invoice, entry: ent5)
        cil5 = Factory(:commercial_invoice_line, vendor_name: 'V1', commercial_invoice: ci5)
        Factory(:commercial_invoice_tariff, entered_value: 100, commercial_invoice_line: cil5)

        h = described_class.new.generate_hash importer.id, Time.zone.parse('2013-12-25 16:00:00 UTC')
        v = h['vendors_ytd']
        expect(v.size).to eq(2)
        expect(v[0]['name']).to eq('V1')
        expect(v[0]['entered']).to eq(350)
        expect(v[1]['name']).to eq('V2')
        expect(v[1]['entered']).to eq(100)
      end

      it "creates port YTD" do
        importer = Factory(:company)
        Port.create!(name: 'P1', schedule_d_code: '0001')
        Port.create!(name: 'P2', schedule_d_code: '0002')
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, entry_port_code: '0001', total_units: 100,
                        first_release_received_date: '2013-12-25 16:00:00 UTC')
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, entry_port_code: '0001', total_units: 50,
                        first_release_received_date: '2013-12-18 16:00:00 UTC')
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, entry_port_code: '0002', total_units: 75,
                        first_release_received_date: '2013-12-18 16:00:00 UTC')
        # don't find not released
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, entry_port_code: '0001', total_units: 60,
                        entry_filed_date: '2013-12-25 16:00:00 UTC', first_release_received_date: nil)
        # don't find for wrong country
        Factory(:entry, import_country_id: Factory(:country).id, importer_id: importer.id, entry_port_code: '0001', total_units: 100,
                        first_release_received_date: '2013-12-24 16:00:00 UTC')
        h = described_class.new.generate_hash importer.id, Time.zone.parse('2013-12-27 16:00:00 UTC')
        p = h['ports_ytd']
        expect(p.entries.size).to eq(2)
        expect(p[0]['name']).to eq('P1')
        expect(p[0]['count']).to eq(2)
        expect(p[0]['code']).to eq('0001')
        expect(p[1]['name']).to eq('P2')
        expect(p[1]['count']).to eq(1)
        expect(p[1]['code']).to eq('0002')
      end

      it "creates port breakouts" do
        importer = Factory(:company)
        Port.create!(name: 'P1', schedule_d_code: '0001')
        Port.create!(name: 'P2', schedule_d_code: '0002')
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, entry_port_code: '0001', total_units: 100,
                        file_logged_date: "2013-12-20 16:00:00 UTC", first_release_received_date: '2013-12-25 16:00:00 UTC')
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, entry_port_code: '0001', total_units: 50,
                        file_logged_date: "2013-12-20 16:00:00 UTC", first_release_received_date: '2013-12-18 16:00:00 UTC')
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, entry_port_code: '0002', total_units: 75,
                        file_logged_date: "2013-12-20 16:00:00 UTC", first_release_received_date: '2013-12-18 16:00:00 UTC')
        Factory(:entry, import_country_id: us.id, importer_id: importer.id, entry_port_code: '0001', total_units: 60,
                        file_logged_date: "2013-12-20 16:00:00 UTC", entry_filed_date: '2013-12-25 16:00:00 UTC',
                        first_release_received_date: nil)
        # don't find for wrong country
        Factory(:entry, import_country_id: Factory(:country).id, importer_id: importer.id, entry_port_code: '0001', total_units: 60,
                        file_logged_date: "2013-12-20 16:00:00 UTC", entry_filed_date: '2013-12-24 16:00:00 UTC',
                        first_release_received_date: nil)
        h = described_class.new.generate_hash importer.id, Time.zone.parse('2013-12-27 16:00:00 UTC')
        bp = h['by_port']

        expect(bp.size).to eq(3)
        expect(bp.first['name']).to eq('P1')
        expect(bp.first['1w']).to eq(1)
        expect(bp.first['4w']).to eq(2)
        expect(bp.first['open']).to eq(1)
        expect(bp.first['code']).to eq('0001')
        expect(bp[1]['name']).to eq('P2')
        expect(bp[1]['1w']).to be_nil
        expect(bp[1]['4w']).to eq(1)
        expect(bp[1]['open']).to be_nil
        expect(bp[1]['code']).to eq('0002')
        expect(bp.last['name']).to eq('TOTAL')
        expect(bp.last['1w']).to eq(1)
        expect(bp.last['4w']).to eq(3)
        expect(bp.last['open']).to eq(1)
        expect(bp.last['code']).to be_nil
      end

      it "creates hts by line breakouts" do
        importer = Factory(:company)
        hts_codes = ['6112345', '6154321', '6112345', '700000', '700000', '8412311']
        hts_codes.each_with_index do |h, i|
          # everything for 1 week
          ent1 = Factory(:entry, import_country_id: us.id, importer_id: importer.id, file_logged_date: "2013-12-20 16:00:00 UTC",
                                 first_release_received_date: '2013-12-25 16:00:00 UTC')
          ci1 = Factory(:commercial_invoice, entry: ent1)
          cil1 = Factory(:commercial_invoice_line, commercial_invoice: ci1)
          Factory(:commercial_invoice_tariff, hts_code: h, commercial_invoice_line: cil1)

          # every other for 4 week
          if i.even?
            ent2 = Factory(:entry, import_country_id: us.id, importer_id: importer.id, file_logged_date: "2013-12-20 16:00:00 UTC",
                                   first_release_received_date: '2013-12-18 16:00:00 UTC')
            ci2 = Factory(:commercial_invoice, entry: ent2)
            cil2 = Factory(:commercial_invoice_line, commercial_invoice: ci2)
            Factory(:commercial_invoice_tariff, hts_code: h, commercial_invoice_line: cil2)
          end

          # first for open
          if i == 0
            ent3 = Factory(:entry, import_country_id: us.id, importer_id: importer.id, file_logged_date: "2013-12-20 16:00:00 UTC",
                                   entry_filed_date: '2013-12-26 16:00:00 UTC')
            ci3 = Factory(:commercial_invoice, entry: ent3)
            cil3 = Factory(:commercial_invoice_line, commercial_invoice: ci3)
            Factory(:commercial_invoice_tariff, hts_code: h, commercial_invoice_line: cil3)
          end

          # wrong country
          if i == 0
            ent4 = Factory(:entry, import_country_id: Factory(:country).id, importer_id: importer.id, file_logged_date: "2013-12-20 16:00:00 UTC",
                                   entry_filed_date: '2013-12-26 16:00:00 UTC')
            ci4 = Factory(:commercial_invoice, entry: ent4)
            cil4 = Factory(:commercial_invoice_line, commercial_invoice: ci4)
            Factory(:commercial_invoice_tariff, hts_code: h, commercial_invoice_line: cil4)
          end
        end

        h = described_class.new.generate_hash importer.id, Time.zone.parse('2013-12-27 16:00:00 UTC')
        bh = h['by_hts']
        expect(bh.size).to eq(4)
        expect(bh[0]['name']).to eq('61')
        expect(bh[0]['1w']).to eq(3)
        expect(bh[0]['4w']).to eq(5)
        expect(bh[0]['open']).to eq(1)
        expect(bh[1]['name']).to eq('70')
        expect(bh[1]['1w']).to eq(2)
        expect(bh[1]['4w']).to eq(3)
        expect(bh[1]['open']).to be_nil
        expect(bh[2]['name']).to eq('84')
        expect(bh[2]['1w']).to eq(1)
        expect(bh[2]['4w']).to eq(1)
        expect(bh[2]['open']).to be_nil
        expect(bh[3]['name']).to eq('TOTAL')
        expect(bh[3]['1w']).to eq(6)
        expect(bh[3]['4w']).to eq(9)
        expect(bh[3]['open']).to eq(1)
      end

      it "creates unpaid duty breakouts" do
        date = Time.zone.today + 10
        first_release_received_date = date.to_datetime
        company = Factory(:company, name: 'Acme', importer: true)
        company.update(linked_companies: [company])
        Factory(:entry, importer_id: company.id, customer_name: company.name, first_release_received_date: first_release_received_date,
                        duty_due_date: date, total_duty: 100, total_fees: 200)
        Factory(:entry, importer_id: company.id, customer_name: company.name, first_release_received_date: first_release_received_date,
                        duty_due_date: date, total_duty: 200, total_fees: 250)

        h = described_class.new.generate_hash company.id, Time.zone.parse('2013-12-27 16:00:00 UTC')
        unpaid_duty = h['unpaid_duty']
        expect(unpaid_duty[0]['customer_name']).to eq 'Acme'
        expect(unpaid_duty[0]['total_duty']).to eq 300
        expect(unpaid_duty[0]['total_fees']).to eq 450
        expect(unpaid_duty[0]['total_duty_and_fees']).to eq 750
        expect(unpaid_duty[1]['customer_name']).to eq 'Acme'
        expect(unpaid_duty[1]['total_duty']).to eq 300
        expect(unpaid_duty[1]['total_fees']).to eq 450
        expect(unpaid_duty[1]['total_duty_and_fees']).to eq 750
      end
    end

    describe "generate_unpaid_duty_section" do
      it "delegates to #single_company_unpaid_duty and #linked_companies_unpaid_duty, producing joined/flattened list" do
        c = instance_double(Company)
        single_total = [instance_double(Integer)]
        linked_total_1 = [instance_double(Integer)]
        linked_total_2 = [instance_double(Integer)]
        linked_total_3 = [instance_double(Integer)]

        expect_any_instance_of(described_class).to receive(:single_company_unpaid_duty).with(c, Time.zone.today).and_return single_total
        expect_any_instance_of(described_class).to receive(:linked_companies_unpaid_duty).with(c, Time.zone.today).and_return [linked_total_1, linked_total_2, linked_total_3]
        expect(described_class.new.generate_unpaid_duty_section(c, Time.zone.today)).to eq [single_total[0], linked_total_1[0], linked_total_2[0], linked_total_3[0]]
      end
    end

    describe "linked_companies_unpaid_duty" do
      it "populates an array with the totals of an importer's linked companies" do
        company = Factory(:company, name: 'Acme')
        allow(company).to receive(:linked_companies) do
          [Company.new(name: 'RiteChoys', importer: true), Company.new(name: 'Super Pow', importer: true), Company.new(name: 'Walshop', importer: true)]
        end
        expect_any_instance_of(described_class).to receive(:single_company_unpaid_duty) {|_instance, c, _date| [company_name: c.name]}.exactly(3).times
        expect(described_class.new.linked_companies_unpaid_duty(company, Time.zone.today)).to eq [[{company_name: "RiteChoys"}], [{company_name: "Super Pow"}], [{company_name: "Walshop"}]] # rubocop:disable Layout/LineLength
      end
    end

    describe "single_company_unpaid_duty" do
      let(:date1) { Time.zone.today }
      let(:date2) { Time.zone.today + 15 }
      let(:date3) { Time.zone.today - 10 }
      let(:first_release_received_date) { date1.to_datetime }
      let(:company) { Factory(:company, name: 'Acme') }

      it "doesn't include unreleased entries in totals" do
        Factory(:entry, importer_id: company.id, first_release_received_date: nil, duty_due_date: date2, total_duty: 600, total_fees: 650)
        h = described_class.new.single_company_unpaid_duty(company, Time.zone.today)
        expect(h).to be_empty
      end

      it "doesn't include in totals entries with duty_due_date before today" do
        Factory(:entry, importer_id: company.id, first_release_received_date: first_release_received_date, duty_due_date: date3,
                        total_duty: 700, total_fees: 750)
        h = described_class.new.single_company_unpaid_duty company, Time.zone.today
        expect(h).to be_empty
      end

      it "doesn't include in totals entries on monthly statement" do
        Factory(:entry, importer_id: company.id, first_release_received_date: first_release_received_date, duty_due_date: date1,
                        monthly_statement_due_date: date2, total_duty: 800, total_fees: 850)
        h = described_class.new.single_company_unpaid_duty company, Time.zone.today
        expect(h).to be_empty
      end
    end

  end

  describe "create_by_release_range_query" do
    let(:us_generator) { described_class.generator_for_country "US" }
    let(:ca_generator) { described_class.generator_for_country "CA" }

    let(:importer) { Factory(:company, importer: true) }

    let!(:e1) do
      Factory(:entry, importer: importer, file_logged_date: "2013-12-20 16:00:00 UTC", first_release_received_date: '2014-01-01 15:00:00 UTC',
                      entry_filed_date: '2013-12-25', import_country_id: us.id, source_system: 'Alliance')
    end

    let!(:e2) do
      Factory(:entry, importer: importer, file_logged_date: "2013-12-20 16:00:00 UTC", first_release_received_date: '2014-01-07 15:00:00 UTC',
                      entry_filed_date: '2013-12-25', import_country_id: us.id, source_system: 'Alliance')
    end

    it "returns a query finding all entries released within 1w" do
      e2.update! first_release_received_date: '2013-12-31 15:00:00 UTC'
      qry = us_generator.create_by_release_range_query importer.id, '1w', Time.zone.parse('2014-01-08 12:00:00 UTC')
      results = qry.all

      expect(results.size).to eq(1)
      expect(results.first.id).to eq e1.id
    end

    it "returns a query finding all CA entries released within 1w" do
      e1.update! import_country: ca, release_date: e1.first_release_received_date
      e2.update! release_date: e2.first_release_received_date

      qry = ca_generator.create_by_release_range_query importer.id, '1w', Time.zone.parse('2014-01-08 12:00:00 UTC')
      results = qry.all

      expect(results.size).to eq(1)
      expect(results.first.id).to eq e1.id
    end

    it "returns a query finding all entries released within 4w" do
      e2.update! first_release_received_date: '2013-12-03 15:00:00 UTC'
      qry = us_generator.create_by_release_range_query importer.id, '4w', Time.zone.parse('2014-01-08 12:00:00 UTC')
      results = qry.all

      expect(results.size).to eq(1)
      expect(results.first.id).to eq e1.id
    end

    it "returns a query finding all entries that are on hold" do
      e1.update on_hold: true, file_logged_date: "2013-12-17 05:00:00 UTC"
      qry = us_generator.create_by_release_range_query importer.id, 'holds', Time.zone.parse('2014-01-08 12:00:00 UTC')
      expect(qry.all).to eq [e1]
    end

    it "returns a query that skips entries over a year old on hold" do
      e1.update on_hold: true, file_logged_date: "2013-12-17 05:00:00 UTC"
      qry = us_generator.create_by_release_range_query importer.id, 'holds', Time.zone.parse('2014-12-17 05:00:01 UTC')
      expect(qry.all.to_a).to eq []
    end

    it "returns a query finding all open entries ytd" do
      e2.update! first_release_received_date: '2013-12-31 15:00:00 UTC'

      qry = us_generator.create_by_release_range_query importer.id, 'ytd', Time.zone.parse('2014-01-08 12:00:00 UTC')
      results = qry.all

      expect(results.size).to eq(1)
      expect(results.first.id).to eq e1.id
    end

    it "returns a query finding all unreleased entries" do
      # unreleased also means the release date is in the future
      e1.update first_release_received_date: nil
      qry = us_generator.create_by_release_range_query importer.id, 'op', Time.zone.parse('2014-01-07 12:00:00 UTC')
      results = qry.all
      expect(results.size).to eq(2)
    end

    it "does not return unreleased entries over a year old" do
      e1.update file_logged_date: "2013-12-17 05:00:00 UTC", first_release_received_date: nil
      qry = us_generator.create_by_release_range_query importer.id, 'op', Time.zone.parse('2014-12-17 05:00:01 UTC')
      expect(qry.all.to_a).to eq []
    end

    it "excludes non-open entries" do
      e1.update! entry_filed_date: nil
      e2.update! tracking_status: Entry::TRACKING_STATUS_CLOSED

      qry = us_generator.create_by_release_range_query importer.id, '1w', Time.zone.parse('2014-01-08 12:00:00 UTC')
      expect(qry.all.size).to eq(0)
    end

    it "excludes entries for other importers" do
      e2.update! importer: Factory(:company)

      qry = us_generator.create_by_release_range_query importer.id, '1w', Time.zone.parse('2014-01-08 12:00:00 UTC')
      expect(qry.all.size).to eq(1)
    end

    it "excludes entries for other countries" do
      e2.update! import_country: ca

      qry = us_generator.create_by_release_range_query importer.id, '1w', Time.zone.parse('2014-01-08 12:00:00 UTC')
      expect(qry.all.size).to eq(1)
    end

    it "excludes FTZ entries" do
      e2.update! entry_type: "06", first_entry_sent_date: nil

      qry = us_generator.create_by_release_range_query importer.id, '1w', Time.zone.parse('2014-01-08 12:00:00 UTC')
      expect(qry.all.size).to eq(1)
    end
  end

  describe "create_by_release_range_download" do
    it "creates spreadsheet of summary detail" do
      stub_master_setup
      date1 = ActiveSupport::TimeZone["UTC"].parse('2013-12-25')
      date2 = ActiveSupport::TimeZone["UTC"].parse('2014-01-01')
      Factory(:entry, importer: (imp = Factory :company, name: "Acme"), import_country: us, entry_filed_date: date1,
                      first_release_received_date: date2, entry_number: "ENTRY NUM", entered_value: 10, customer_references: "CUST REF",
                      po_numbers: "PO NUMs", customer_name: "CUST NAME", source_system: 'Alliance')
      gen = described_class.generator_for_country "US"
      f = gen.create_by_release_range_download imp.id, '1w', ActiveSupport::TimeZone["UTC"].parse('2014-01-05')
      wb = Spreadsheet.open f.path
      sheet = wb.worksheets[0]

      expect(sheet.name).to eq "Released In The Last 7 Days"
      expect(sheet.rows.count).to eq 2
      expect(sheet.row(0)).to eq ["Entry Number", "Entry Filed Date", "First Release Received Date", "Total Entered Value",
                                  "Customer References", "PO Numbers", "Customer Name", "Link"]
      # rows test split up because otherwise dates aren't evaluated correctly
      expect(sheet.row(1)[0]).to eq "ENTRY NUM"
      expect(sheet.row(1)[1]).to eq date1
      expect(sheet.row(1)[2]).to eq date2
      expect(sheet.row(1)[3..7]).to eq [10, "CUST REF", "PO NUMs", "CUST NAME", "Web View"]
    end
  end

  describe "DutyDetail" do
    let(:date1) { Date.new(2018, 2, 15) }
    let(:date2) { date1 + 15 }
    let(:first_release_received_date) { date1.to_datetime }
    let(:company) { Factory(:company, name: 'Acme', master: true) }
    let(:non_master_company) { Factory(:company, name: "Emca") }
    let(:user) { Factory(:user, company: company) }
    let(:port1) { Factory(:port, schedule_d_code: '1234', name: 'Boston') }
    let(:port2) { Factory(:port, schedule_d_code: '4321', name: 'New York') }

    # included in totals
    let(:ent1) do
      Factory(:entry, importer_id: company.id, entry_port_code: port1.schedule_d_code, entry_number: '12345678912',
                      first_release_received_date: first_release_received_date, duty_due_date: date1, total_duty: 100, total_fees: 200)
    end

    let(:ent2) do
      Factory(:entry, importer_id: company.id, entry_port_code: port1.schedule_d_code, entry_number: '21987654321',
                      first_release_received_date: first_release_received_date, duty_due_date: date1, total_duty: 200, total_fees: 250)
    end

    let(:ent3) do
      Factory(:entry, importer_id: company.id, entry_port_code: port1.schedule_d_code, entry_number: '53471126928',
                      first_release_received_date: first_release_received_date, duty_due_date: date2, total_duty: 300, total_fees: 350)
    end

    let(:ent4) do
      Factory(:entry, importer_id: company.id, entry_port_code: port2.schedule_d_code, entry_number: '14215923867',
                      first_release_received_date: first_release_received_date, duty_due_date: date2, total_duty: 400, total_fees: 450)
    end

    let(:ent5) do
      Factory(:entry, importer_id: company.id, entry_port_code: port2.schedule_d_code, entry_number: '59172148623',
                      first_release_received_date: first_release_received_date, duty_due_date: date2, total_duty: 500, total_fees: 550)
    end

    # excluded from totals
    let(:ent6) do
      Factory(:entry, importer_id: company.id, entry_port_code: port2.schedule_d_code, entry_number: '95711284263',
                      first_release_received_date: nil, duty_due_date: date2, total_duty: 600, total_fees: 650)
    end

    let(:ent7) do
      Factory(:entry, importer_id: company.id, entry_port_code: port2.schedule_d_code, entry_number: '36248211759',
                      first_release_received_date: first_release_received_date, duty_due_date: date3, total_duty: 700, total_fees: 750)
    end

    let(:ent8) do
      Factory(:entry, importer_id: company.id, entry_port_code: port2.schedule_d_code, entry_number: '63422811579',
                      first_release_received_date: first_release_received_date, duty_due_date: date1, monthly_statement_due_date: date2,
                      total_duty: 800, total_fees: 850)
    end

    let(:ent9) do
      Factory(:entry, importer_id: non_master_company.id, entry_port_code: port1.schedule_d_code, entry_number: '23821946175',
                      first_release_received_date: first_release_received_date, duty_due_date: date1, total_duty: 900,
                      total_fees: 950)
    end

    let(:ent10) do
      Factory(:entry, importer_id: company.id, entry_port_code: port2.schedule_d_code, entry_number: '7654321987',
                      first_release_received_date: first_release_received_date, duty_due_date: date2, total_duty: 500,
                      total_fees: 550, entry_type: '06', first_entry_sent_date: nil)
    end

    let(:generator) { described_class.generator_for_country "US" }

    describe "create_linked_digests" do
      it "populates an array with digests of an importer's linked companies" do
        allow(company).to receive(:linked_companies) do
          [Company.new(name: 'RiteChoys', importer: true), Company.new(name: 'Super Pow', importer: true), Company.new(name: 'Walshop', importer: true)]
        end
        expect(generator).to receive(:create_digest) { |_usr, comp| {company_name: comp.name} }.exactly(3).times
        expect(generator.create_linked_digests(user, company)).to eq [{company_name: "RiteChoys"}, {company_name: "Super Pow"}, {company_name: "Walshop"}]
      end
    end

    describe "create_digest" do
      it "delegates to build and get_entries" do
        u = instance_double(User)
        c = instance_double(Company)
        e = instance_double(Array)
        expect(generator).to receive(:get_entries).with(u, c).and_return e
        expect(generator).to receive(:build_digest).with(e).and_return 'abc'
        expect(generator.create_digest(u, c)).to eq 'abc'
      end
    end

    describe "build_digest" do
      it "returns empty if entries are empty" do
        allow(company).to receive(:view_vendors?).and_return true
        allow(user).to receive(:view_entries?).and_return true

        entries = []
        expect(generator.build_digest(entries)).to be nil
      end

      it "returns digest for multiple dates, ports" do
        allow(company).to receive(:view_vendors?).and_return true
        allow(user).to receive(:view_entries?).and_return true

        # rubocop:disable Layout/LineLength
        digest = {company_name: "Acme",
                  company_report: {date_hsh: {date1 => {port_hsh: {"Boston" => {port_total_duty: 300,
                                                                                port_total_fees: 450,
                                                                                port_total_duty_and_fees: 750,
                                                                                port_entry_count: 2,
                                                                                entries: [{ent_id: ent1.id, ent_entry_number: "12345678912", ent_entry_type: nil, ent_port_name: "Boston",
                                                                                           ent_first_release_received_date: first_release_received_date, ent_customer_references: nil, ent_duty_due_date: date1,
                                                                                           ent_total_fees: 200, ent_total_duty: 100, ent_total_duty_and_fees: 300},
                                                                                          {ent_id: ent2.id, ent_entry_number: "21987654321", ent_entry_type: nil, ent_port_name: "Boston",
                                                                                           ent_first_release_received_date: first_release_received_date, ent_customer_references: nil, ent_duty_due_date: date1,
                                                                                           ent_total_fees: 250, ent_total_duty: 200, ent_total_duty_and_fees: 450}]}},
                                                        date_total_duty: 300,
                                                        date_total_fees: 450,
                                                        date_total_duty_and_fees: 750,
                                                        date_entry_count: 2},
                                              date2 => {port_hsh: {"Boston" => {port_total_duty: 300,
                                                                                port_total_fees: 350,
                                                                                port_total_duty_and_fees: 650,
                                                                                port_entry_count: 1,
                                                                                entries: [{ent_id: ent3.id, ent_entry_number: "53471126928", ent_entry_type: nil, ent_port_name: "Boston",
                                                                                           ent_first_release_received_date: first_release_received_date, ent_customer_references: nil, ent_duty_due_date: date2,
                                                                                           ent_total_fees: 350, ent_total_duty: 300, ent_total_duty_and_fees: 650}]},
                                                                   "New York" => {port_total_duty: 900,
                                                                                  port_total_fees: 1000,
                                                                                  port_total_duty_and_fees: 1900,
                                                                                  port_entry_count: 2,
                                                                                  entries: [{ent_id: ent4.id, ent_entry_number: "14215923867", ent_entry_type: nil, ent_port_name: "New York",
                                                                                             ent_first_release_received_date: first_release_received_date, ent_customer_references: nil, ent_duty_due_date: date2,
                                                                                             ent_total_fees: 450, ent_total_duty: 400, ent_total_duty_and_fees: 850},
                                                                                           {ent_id: ent5.id, ent_entry_number: "59172148623", ent_entry_type: nil, ent_port_name: "New York",
                                                                                            ent_first_release_received_date: first_release_received_date, ent_customer_references: nil, ent_duty_due_date: date2,
                                                                                            ent_total_fees: 550, ent_total_duty: 500, ent_total_duty_and_fees: 1050}]}},
                                                        date_total_duty: 1200,
                                                        date_total_fees: 1350,
                                                        date_total_duty_and_fees: 2550,
                                                        date_entry_count: 3}},
                                   company_entry_count: 5,
                                   company_total_duty: 1500,
                                   company_total_fees: 1800,
                                   company_total_duty_and_fees: 3300}}
        # rubocop:enable Layout/LineLength

        Timecop.freeze(date1.to_datetime) do
          entries = generator.get_entries user, company
          expect(generator.build_digest(entries)).to eq digest
        end
      end
    end

    describe "get_entries" do

      it "returns results only for specified company" do
        allow(company).to receive(:can_view?).with(user).and_return(true)
        allow(user).to receive(:view_entries?).and_return(true)

        Timecop.freeze(date1.to_datetime) do
          expect(generator.get_entries(user, company).where("importer_id = ? ", non_master_company.id)).to be_empty
        end
      end

      it "returns empty if user cannot view entries" do
        allow(company).to receive(:can_view?).with(user).and_return(true)

        allow(user).to receive(:view_entries?).and_return(false)

        Timecop.freeze(date1.to_datetime) do
          expect(generator.get_entries(user, company)).to be_empty
        end
      end

      it "returns empty if user does not have permission to companies provided" do
        allow(user).to receive(:view_entries?).and_return true

        allow(company).to receive(:can_view?).with(user).and_return(false)

        Timecop.freeze(date1.to_datetime) do
          expect(generator.get_entries(user, company)).to be_empty
        end
      end

      it "doesn't return unreleased entries" do
        allow(company).to receive(:can_view?).with(user).and_return(true)
        allow(user).to receive(:view_entries?).and_return(true)

        Timecop.freeze(date1.to_datetime) do
          expect(generator.get_entries(user, company).where("first_release_received_date IS NULL")).to be_empty
        end
      end

      it "doesn't return where duty_due_date is before today" do
        allow(company).to receive(:can_view?).with(user).and_return(true)
        allow(user).to receive(:view_entries?).and_return(true)

        Timecop.freeze(date1.to_datetime) do
          expect(generator.get_entries(user, company).where("duty_due_date < ?", Time.zone.today)).to be_empty
        end
      end

      it "doesn't return items on monthly statement" do
        allow(company).to receive(:can_view?).with(user).and_return(true)
        allow(user).to receive(:view_entries?).and_return(true)

        Timecop.freeze(date1.to_datetime) do
          expect(generator.get_entries(user, company).where("monthly_statement_due_date IS NOT NULL")).to be_empty
        end
      end

      it "doesn't return FTZ entries" do
        allow(company).to receive(:can_view?).with(user).and_return(true)
        allow(user).to receive(:view_entries?).and_return(true)

        Timecop.freeze(date1.to_datetime) do
          expect(generator.get_entries(user, company).where(entry_type: '06')).to be_empty
        end
      end
    end
  end

  describe OpenChain::ActivitySummary::EntrySummaryDownload do
    let(:summary) do
      # rubocop:disable Layout/LineLength
      {'activity_summary' => {'summary' => {'1w' => {'count' => 1, 'duty' => 2, 'fees' => 3, 'gst' => 3.5, 'duty_gst' => 3.6, 'entered' => 4, 'invoiced' => 5, 'units' => 6},
                                            '4w' => {'count' => 7, 'duty' => 8, 'fees' => 9, 'gst' => 9.5, 'duty_gst' => 9.6, 'entered' => 10, 'invoiced' => 11, 'units' => 12},
                                            '4wa' => {'count' => 13, 'duty' => 14, 'fees' => 15, 'gst' => 15.5, 'duty_gst' => 15.6, 'entered' => 16, 'invoiced' => 17, 'units' => 18},
                                            '4wo' => {'count' => 19, 'duty' => 20, 'fees' => 21, 'gst' => 21.5, 'duty_gst' => 21.6, 'entered' => 22, 'invoiced' => 23, 'units' => 24},
                                            'holds' => {'count' => 25, 'duty' => 26, 'fees' => 27, 'gst' => 27.5, 'duty_gst' => 27.6, 'entered' => 28, 'invoiced' => 29, 'units' => 30},
                                            'open' => {'count' => 31, 'duty' => 32, 'fees' => 33, 'gst' => 33.5, 'duty_gst' => 33.6, 'entered' => 34, 'invoiced' => 35, 'units' => 36},
                                            'ytd' => {'count' => 37, 'duty' => 38, 'fees' => 39, 'gst' => 39.5, 'duty_gst' => 39.6, 'entered' => 40, 'invoiced' => 41, 'units' => 42}},
                              'pms' => [{'importer_name' => 'Super Pow', 'due' => 43, 'paid' => 44, 'amount' => 45}],
                              'by_port' => [{'name' => 'NYC', '1w' => 46, '4w' => 47, 'open' => 48}],
                              'by_hts' => [{'name' => 'chpt', '1w' => 49, '4w' => 50, 'open' => 51}],
                              'vendors_ytd' => [{'name' => 'ACME', 'entered' => 52}],
                              'ports_ytd' => [{'name' => 'LA', 'count' => 53}]}}
      # rubocop:enable Layout/LineLength
    end

    let(:linked_1) { with_customs_management_id(Factory(:company, name: "Super Pow"), "POW") }
    let(:linked_2) { Factory(:company, name: "Walshop") }
    let(:imp)  { with_customs_management_id(Factory(:company, linked_companies: [linked_1, linked_2], system_code: "SYSCODE", name: "Konvenientz"), "KONV") }
    let(:user) { Factory(:user, company: imp, time_zone: "Central Time (US & Canada)") }

    describe "permission?" do
      it "allows users who can view entries for the importer" do
        expect(Entry).to receive(:can_view_importer?).with(imp, user).and_return true
        expect(described_class.permission?(user, imp.id)).to eq true
      end

      it "blocks users who can't view entries for the importer" do
        expect(Entry).to receive(:can_view_importer?).with(imp, user).and_return false
        expect(described_class.permission?(user, imp.id)).to eq false
      end
    end

    describe "find_company" do
      before { imp }

      it "returns company identified by system_code if it exists" do
        expect(described_class.find_company("iso_code" => "US", 'system_code' => "SYSCODE")).to eq imp
      end

      context "without system_code" do
        it "returns company identified by alliance number for 'US' iso code" do
          with_customs_management_id(imp, "ALLIANCE")
          expect(described_class.find_company("iso_code" => "US", "alliance_customer_number" => "ALLIANCE")).to eq imp
        end

        it "returns company identified by cargowise number for 'US' iso code" do
          with_cargowise_id(imp, "CW")
          expect(described_class.find_company("iso_code" => "US", "cargowise_customer_number" => "CW")).to eq imp
        end

        it "returns company identified by fenix number for 'CA' iso code" do
          with_fenix_id(imp, "FENIX")
          expect(described_class.find_company("iso_code" => "CA", "fenix_customer_number" => "FENIX")).to eq imp
        end
      end
    end

    describe "run_report" do
      it "creates US spreadsheet with periodic monthly statement" do
        stub_master_setup
        expect(OpenChain::ActivitySummary).to receive(:generate_us_entry_summary).with(imp.id).and_return summary
        date = DateTime.new(2018, 3, 15)
        file = nil
        Timecop.freeze(date) { file = described_class.run_report user, 'importer_id' => imp.id, 'iso_code' => 'US' }
        file.rewind
        reader = XlsxTestReader.new(file.path).raw_workbook_data
        sheet = reader["Summary"]

        expect(sheet[0]).to eq [MasterSetup.application_name + " Insights", nil, nil, nil, nil, nil, nil]
        expect(sheet[1]).to eq ["US Entry Activity"]
        expect(sheet[2][0]).to eq "Date"
        # Tolerance is needed due to the way the excel lib can be inexact with times
        expect(sheet[2][1]).to be_within(1.minute).of DateTime.new(2018, 3, 14, 19, 0)
        expect(sheet[3]).to eq ["Customer Number", "SYSCODE"]
        expect(sheet[4]).to eq ["View Summary in Real Time", "Link"]
        expect(sheet[7]).to eq ["Summary", nil, nil, nil, nil, nil, nil]
        expect(sheet[8]).to eq [nil, "# of Entries", "Duty", "Fees", "Entered Value", "Invoiced Value", "Units"]
        expect(sheet[9]).to eq ["Released Last 7 Days", 1, 2, 3, 4, 5, 6]
        expect(sheet[10]).to eq ["Released Last 28 Days", 7, 8, 9, 10, 11, 12]
        expect(sheet[11]).to eq ["Filed / Not Released", 31, 32, 33, 34, 35, 36]
        expect(sheet[12]).to eq ["Entries On Hold", 25, 26, 27, 28, 29, 30]
        # column 1
        expect(sheet[15][0..3]).to eq ["Periodic Monthly Statement", nil, nil, nil]
        expect(sheet[16][0..3]).to eq ["Company", "Due", "Paid", "Amount"]
        expect(sheet[17][0..3]).to eq ["Super Pow", 43, 44, 45]
        expect(sheet[20][0..3]).to eq ["Entry Breakouts", nil, nil, nil]
        expect(sheet[21][0..3]).to eq ["Entries by Port", nil, nil, nil]
        expect(sheet[22][0..3]).to eq ["Port", "1 Week", "4 Weeks", "Open"]
        expect(sheet[23][0..3]).to eq ["NYC", 46, 47, 48]
        expect(sheet[25][0..3]).to eq ["Lines by Chapter", nil, nil, nil]
        expect(sheet[26][0..3]).to eq ["Chapter", "1 Week", "4 Weeks", "Open"]
        expect(sheet[27][0..3]).to eq ["chpt", 49, 50, 51]
        expect(sheet[30][0..3]).to eq ["Companies Included", nil, nil, nil]
        expect(sheet[31][0..3]).to eq ["Konvenientz (KONV)"]
        expect(sheet[32][0..3]).to eq ["Super Pow (POW)"]
        # column 2
        expect(sheet[15][5..6]).to eq ["Released Year To Date", nil]
        expect(sheet[16][5..6]).to eq ["Summary", nil]
        expect(sheet[17][5..6]).to eq ["Entries", 37]
        expect(sheet[18][5..6]).to eq ["Duty", 38]
        expect(sheet[19][5..6]).to eq ["Fees", 39]
        expect(sheet[20][5..6]).to eq ["Entered Value", 40]
        expect(sheet[21][5..6]).to eq ["Invoiced Value", 41]
        expect(sheet[22][5..6]).to eq ["Units", 42]
        expect(sheet[24][5..6]).to eq ["Top 5 Vendors", nil]
        expect(sheet[25][5..6]).to eq [nil, "Entered Value"]
        expect(sheet[26][5..6]).to eq ["ACME", 52]
        expect(sheet[28][5..6]).to eq ["Ports", nil]
        expect(sheet[29][5..6]).to eq [nil, "Shipments"]
        expect(sheet[30][5..6]).to eq ["LA", 53]

        file.close
      end

      it "creates US spreadsheet with unpaid duty section" do
        stub_master_setup
        summary['activity_summary'].delete('pms')
        summary['activity_summary']['unpaid_duty'] = [{'customer_name' => 'RiteChoys', 'total_duty' => 54, 'total_fees' => 55, 'total_duty_and_fees' => 56}]
        expect(OpenChain::ActivitySummary).to receive(:generate_us_entry_summary).with(imp.id).and_return summary
        file = described_class.run_report user, 'importer_id' => imp.id, 'iso_code' => 'US'
        file.rewind
        reader = XlsxTestReader.new(file.path).raw_workbook_data
        sheet = reader["Summary"]

        expect(sheet[15][0..3]).to eq ["Unpaid Duty", nil, nil, nil]
        expect(sheet[16][0..3]).to eq ["Company", "Total Duty", "Total Fees", "Total Duty and Fees"]
        expect(sheet[17][0..3]).to eq ["RITECHOYS", 54, 55, 56]

        file.close
      end

      it "creates CA spreadsheet" do
        stub_master_setup
        summary['activity_summary'].delete('pms')
        summary['activity_summary']['k84'] = [{'importer_name' => 'Walshop', 'due' => 57, 'amount' => 58}]
        expect(OpenChain::ActivitySummary).to receive(:generate_ca_entry_summary).with(imp.id).and_return summary
        file = described_class.run_report user, 'importer_id' => imp.id, 'iso_code' => 'CA'
        file.rewind
        reader = XlsxTestReader.new(file.path).raw_workbook_data
        sheet = reader["Summary"]

        expect(sheet[1]).to eq ["CA Entry Activity"]
        expect(sheet[8]).to eq [nil, '# of Entries', 'Duty', 'GST', 'Duty/GST', 'Entered Value', 'Invoiced Value', 'Units']
        expect(sheet[9]).to eq ["Released Last 7 Days", 1, 2, 3.5, 3.6, 4, 5, 6]
        expect(sheet[10]).to eq ["Released Last 28 Days", 7, 8, 9.5, 9.6, 10, 11, 12]
        expect(sheet[11]).to eq ["Filed / Not Released", 31, 32, 33.5, 33.6, 34, 35, 36]
        expect(sheet[12]).to eq ["Entries On Hold", 25, 26, 27.5, 27.6, 28, 29, 30]
        # column 1 (where different from US)
        expect(sheet[15][0..2]).to eq ["Estimated K84 Statement", nil, nil]
        expect(sheet[16][0..2]).to eq ["Name", "Due", "Amount"]
        expect(sheet[17][0..2]).to eq ["Walshop", 57, 58]
        expect(sheet[30][0..3]).to eq ["Companies Included", nil, nil, nil]
        expect(sheet[31][0..3]).to eq ["Konvenientz (KONV)", nil, nil, nil] # not sure why this has trailing nils
        expect(sheet[32][0..3]).to eq ["Super Pow (POW)"]
        # column 2
        expect(sheet[16][6..7]).to eq ["Summary", nil]
        expect(sheet[17][6..7]).to eq ["Entries", 37]
        expect(sheet[18][6..7]).to eq ["Duty", 38]
        expect(sheet[19][6..7]).to eq ["GST", 39.5]
        expect(sheet[20][6..7]).to eq ["Duty/GST", 39.6]
        expect(sheet[21][6..7]).to eq ["Entered Value", 40]
        expect(sheet[22][6..7]).to eq ["Invoiced Value", 41]
        expect(sheet[23][6..7]).to eq ["Units", 42]
        expect(sheet[25][6..7]).to eq ["Top 5 Vendors", nil]
        expect(sheet[26][6..7]).to eq [nil, "Entered Value"]
        expect(sheet[27][6..7]).to eq ["ACME", 52]
        expect(sheet[29][6..7]).to eq ["Ports", nil]
        expect(sheet[30][6..7]).to eq [nil, "Shipments"]
        expect(sheet[31][6..7]).to eq ["LA", 53]

        file.close
      end
    end

    describe "ReportEmailer" do
      subject { described_class::ReportEmailer }

      let(:imp) { with_customs_management_id(Factory(:company, name: "ACME"), "AC") }
      let(:gen) { described_class.new(imp.id, "US") }
      let(:user) { Factory(:user, first_name: "Nigel", last_name: "Tufnel", email: "tufnel@stonehenge.biz", company: imp) }
      let(:mailing_list) { Factory(:mailing_list, user: user, company: imp, email_addresses: 'mailinglist@domain.com')}

      describe "update_args" do
        it "supplies subject and body when both are missing" do
          Timecop.freeze(DateTime.new(2018, 3, 15, 15, 0)) do
            expect(subject.update_args(gen, nil, nil, nil, nil)).to eq [nil, "ACME US entry summary for 2018-03-15", "ACME US entry summary for 2018-03-15 is attached."]
          end
        end

        it "supplies subject if missing" do
          Timecop.freeze(DateTime.new(2018, 3, 15, 15, 0)) do
            expect(subject.update_args(gen, nil, nil, "Hi David, this one's for you!", nil)).to eq [nil, "ACME US entry summary for 2018-03-15", "Hi David, this one's for you!"] # rubocop:disable Layout/LineLength
          end
        end

        it "supplies body if missing" do
          Timecop.freeze(DateTime.new(2018, 3, 15, 15, 0)) do
            expect(subject.update_args(gen, nil, "AMAZING report!!", nil, nil)).to eq [nil, "AMAZING report!!", "ACME US entry summary for 2018-03-15 is attached."]
          end
        end

        it "uses supplied args" do
          Timecop.freeze(DateTime.new(2018, 3, 15, 15, 0)) do
            expect(subject.update_args(gen, nil, "AMAZING report!!", "Hi David, this one's for you!", nil)).to eq [nil, "AMAZING report!!", "Hi David, this one's for you!"]
          end
        end

        context "with user" do
          let(:user) { Factory(:user, first_name: "Nigel", last_name: "Tufnel", email: "tufnel@stonehenge.biz") }

          it "adds header to body with user info" do
            Timecop.freeze(DateTime.new(2018, 3, 15, 15, 0)) do
              out = subject.update_args gen, "st-hubbins@hellhole.co.uk", "AMAZING report!!", "Hi David, this one's for you!", user
              expect(out[0]).to eq "st-hubbins@hellhole.co.uk"
              expect(out[1]).to eq "AMAZING report!!"
              expect(out[2]).to eq "<p>Nigel Tufnel (tufnel@stonehenge.biz) has sent you a report.</p><br>Hi David, this one&#39;s for you!"
            end
          end

          it "subs user's email, omits header, if no email is given" do
            Timecop.freeze(DateTime.new(2018, 3, 15, 15, 0)) do
              out = subject.update_args gen, "", "AMAZING report!!", "Hi me, this one's for you!", user
              expect(out[0]).to eq "tufnel@stonehenge.biz"
              expect(out[1]).to eq "AMAZING report!!"
              expect(out[2]).to eq "Hi me, this one's for you!"
            end
          end
        end
      end
    end

    describe "run_schedulable" do
      it "creates and emails spreadsheet to a mailing list" do
        company = Factory(:company)
        user = Factory(:user, company: company)
        mailing_list = Factory(:mailing_list, name: 'Test', user: user, company: user.company, email_addresses: 'mailinglist@domain.com')
        stub_master_setup
        now = DateTime.new(2018, 3, 15)
        Timecop.freeze(now) do
          described_class.run_schedulable('system_code' => imp.system_code, 'iso_code' => 'US', 'email' => 'tufnel@stonehenge.biz', 'mailing_list' => mailing_list.id)
        end
        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq ['tufnel@stonehenge.biz', 'mailinglist@domain.com']
      end

      it "creates and emails spreadsheet" do
        stub_master_setup
        now = DateTime.new(2018, 3, 15)
        Timecop.freeze(now) { described_class.run_schedulable('system_code' => imp.system_code, 'iso_code' => 'US', 'email' => 'tufnel@stonehenge.biz') }
        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq ['tufnel@stonehenge.biz']
        expect(mail.subject).to eq "Konvenientz US entry summary for 2018-03-14"
        expect(mail.body.raw_source).to match(/Konvenientz US entry summary for 2018-03-14 is attached./)
        att = mail.attachments['Konvenientz_entry_detail.xlsx']
        Tempfile.open("temp") do |t|
          t.binmode
          t << att.read
          t.flush
          reader = XlsxTestReader.new(t.path).raw_workbook_data
          sheet = reader["Summary"]
          expect(sheet[0]).to eq [MasterSetup.application_name + " Insights", nil, nil, nil, nil, nil, nil]
        end
      end
    end
  end

end
