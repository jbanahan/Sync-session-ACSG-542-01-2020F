require 'spec_helper'

describe OpenChain::ActivitySummary do
  before :each do
    @us = Factory(:country,iso_code:'US')
    @ca = Factory(:country,iso_code:'CA')
  end

  after :each do
    Country.destroy_all
  end

  describe "generate_us_entry_summary" do
    it "should make json" do
      ent = Factory(:entry,import_country_id:@us.id,importer_id:Factory(:company).id,release_date:'2013-12-25 05:00:00 UTC')
      h = described_class.generate_us_entry_summary(ent.importer_id, Time.parse('2013-12-27 16:00:00 UTC'))
      expect(h['activity_summary']['summary']['1w']['count']).to eq(1)
    end
  end
  describe "generate_ca_entry_summary" do
    it "should make json" do
      ent = Factory(:entry,import_country_id:@ca.id,importer_id:Factory(:company).id,release_date:'2013-12-25 05:00:00 UTC')
      h = described_class.generate_ca_entry_summary(ent.importer_id, Time.parse('2013-12-27 16:00:00 UTC'))
      expect(h['activity_summary']['summary']['1w']['count']).to eq(1)
    end
  end

  describe OpenChain::ActivitySummary::CAEntrySummaryGenerator do

    it "should create summary section" do
      importer = Factory(:company)
      ent = Factory(:entry,import_country_id:@ca.id,importer_id:importer.id,release_date:'2013-12-25 05:00:00 UTC', total_duty:100,total_gst:50,total_duty_gst:150,entered_value:1000,total_invoiced_value:1100,total_units:70)
      ent2 = Factory(:entry,import_country_id:@ca.id,importer_id:importer.id,release_date: '2013-12-15 05:00:00 UTC', total_duty:200,total_gst:75,total_duty_gst:275,entered_value:1500,total_invoiced_value:1600,total_units:40)
      ent3 = Factory(:entry,import_country_id:@ca.id,importer_id:importer.id,file_logged_date:'2013-12-18 05:00:00 UTC',total_duty:50,total_gst:40,total_duty_gst:90,entered_value:60,total_invoiced_value:66,total_units:3)
      ent2 = Factory(:entry,import_country_id:@ca.id,importer_id:importer.id,release_date:'2012-12-25 05:00:00 UTC',total_duty:200,total_gst:75,total_duty_gst:275,entered_value:1500,total_invoiced_value:1600,total_units:40)

      h = OpenChain::ActivitySummary::CAEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-27 16:00:00 UTC')
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
    it "should create k84 section" do
      importer = Factory(:company,name:'IMP')
      Factory(:entry,k84_due_date:Date.new(2012,12,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      Factory(:entry,k84_due_date:Date.new(2013,1,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      Factory(:entry,k84_due_date:Date.new(2013,1,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      Factory(:entry,k84_due_date:Date.new(2013,1,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      Factory(:entry,k84_due_date:Date.new(2013,2,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      Factory(:entry,k84_due_date:Date.new(2013,2,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      Factory(:entry,k84_due_date:Date.new(2013,2,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      Factory(:entry,k84_due_date:Date.new(2013,3,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      Factory(:entry,k84_due_date:Date.new(2013,3,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      Factory(:entry,k84_due_date:Date.new(2013,3,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      Factory(:entry,k84_due_date:Date.new(2013,3,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      #only find last 3, so don't find this one
      Factory(:entry,k84_due_date:Date.new(2012,1,25),total_duty_gst:100,import_country_id:@ca.id,importer_id:importer.id)
      h = OpenChain::ActivitySummary::CAEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-02-25 16:00:00 UTC')
      k = h['k84']
      expect(k.size).to eq(4)
      expect(k[0]['importer_name']).to eq('IMP')
      expect(k[0]['due']).to eq(Date.new(2013,3,25))
      expect(k[0]['amount']).to eq(400)
      expect(k[1]['importer_name']).to eq('IMP')
      expect(k[1]['due']).to eq(Date.new(2013,2,25))
      expect(k[1]['amount']).to eq(300)
      expect(k[2]['importer_name']).to eq('IMP')
      expect(k[2]['due']).to eq(Date.new(2013,1,25))
      expect(k[2]['amount']).to eq(300)
      expect(k[3]['importer_name']).to eq('IMP')
      expect(k[3]['due']).to eq(Date.new(2012,12,25))
      expect(k[3]['amount']).to eq(100)
    end
  end
  describe OpenChain::ActivitySummary::USEntrySummaryGenerator do
    describe "generate_hash" do
      it "should create summary section" do
        importer = Factory(:company)

        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:'2013-12-25 05:00:00 UTC',total_duty:100,total_fees:50,entered_value:1000,total_invoiced_value:1100,total_units:70)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:'2013-12-15 05:00:00 UTC',total_duty:200,total_fees:75,entered_value:1500,total_invoiced_value:1600,total_units:40)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_filed_date:'2013-12-18 05:00:00 UTC',total_duty:50,total_fees:40,entered_value:60,total_invoiced_value:66,total_units:3)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:'2012-12-25 05:00:00 UTC',total_duty:200,total_fees:75,entered_value:1500,total_invoiced_value:1600,total_units:40)
        #don't find for wrong country
        Factory(:entry,import_country_id:Factory(:country).id,importer_id:importer.id,release_date:2.day.ago,total_duty:100,total_fees:50,entered_value:1000,total_invoiced_value:1100,total_units:70)
        h = OpenChain::ActivitySummary::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-27 16:00:00 UTC')
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

      it "should create statments section" do
        importer = Factory(:company,name:'IMP')
        not_paid = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,12,25),monthly_statement_paid_date:nil,total_duty:100,total_fees:50)
        paid1 = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,11,25),monthly_statement_paid_date:Date.new(2013,11,24),total_duty:200,total_fees:100)
        paid2 = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,11,25),monthly_statement_paid_date:Date.new(2013,11,24),total_duty:200,total_fees:100)
        paid3 = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,10,25),monthly_statement_paid_date:Date.new(2013,10,24),total_duty:200,total_fees:100)
        paid4 = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,9,25),monthly_statement_paid_date:Date.new(2013,9,24),total_duty:200,total_fees:100)
        #next line won't be included since we only return record from next month and last 3
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,8,25),monthly_statement_paid_date:Date.new(2013,8,24),total_duty:200,total_fees:100)
        #don't find for wrong country
        Factory(:entry,import_country_id:Factory(:country).id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,10,25),monthly_statement_paid_date:Date.new(2013,10,24),total_duty:200,total_fees:100)
        h = OpenChain::ActivitySummary::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-11-25 16:00:00 UTC')
        statements = h['pms']
        expect(statements.size).to eq(4)
        expect(statements[0]['importer_name']).to eq('IMP')
        expect(statements[0]['due']).to eq(Date.new(2013,12,25))
        expect(statements[0]['paid']).to be_nil
        expect(statements[0]['amount']).to eq(150)
        expect(statements[1]['importer_name']).to eq('IMP')
        expect(statements[1]['due']).to eq(Date.new(2013,11,25))
        expect(statements[1]['paid']).to eq(Date.new(2013,11,24))
        expect(statements[1]['amount']).to eq(600)
        expect(statements[2]['importer_name']).to eq('IMP')
        expect(statements[2]['due']).to eq(Date.new(2013,10,25))
        expect(statements[2]['paid']).to eq(Date.new(2013,10,24))
        expect(statements[2]['amount']).to eq(300)
        expect(statements[3]['importer_name']).to eq('IMP')
        expect(statements[3]['paid']).to eq(Date.new(2013,9,24))
        expect(statements[3]['amount']).to eq(300)
      end

      it "should create separate lines per importer_id" do
        imp1 = Factory(:company,name:'imp1')
        Factory(:entry,import_country_id:@us.id,importer_id:imp1.id,monthly_statement_due_date:Date.new(2013,11,25),monthly_statement_paid_date:Date.new(2013,11,24),total_duty:200,total_fees:100)
        imp2 = Factory(:company,name:'imp2') #linked
        Factory(:entry,import_country_id:@us.id,importer_id:imp2.id,monthly_statement_due_date:Date.new(2013,11,25),monthly_statement_paid_date:Date.new(2013,11,24),total_duty:200,total_fees:100)
        imp3 = Factory(:company,name:'imp3') #not linked
        Factory(:entry,import_country_id:@us.id,importer_id:imp3.id,monthly_statement_due_date:Date.new(2013,11,25),monthly_statement_paid_date:Date.new(2013,11,24),total_duty:200,total_fees:100)
        imp1.linked_companies << imp2
        h = OpenChain::ActivitySummary::USEntrySummaryGenerator.new.generate_hash imp1.id, Time.parse('2013-11-25 16:00:00 UTC')
        statements = h['pms']
        expect(statements.length).to eq 2
        expect(statements[0]['importer_name']).to eq 'imp1'
        expect(statements[0]['amount']).to eq 300
        expect(statements[1]['importer_name']).to eq 'imp2'
        expect(statements[1]['amount']).to eq 300
      end

      it "should create top 5 vendors YTD" do
        importer = Factory(:company)
        Factory(:commercial_invoice_tariff,entered_value:100,
          commercial_invoice_line:Factory(:commercial_invoice_line,vendor_name:'V1',
            commercial_invoice:Factory(:commercial_invoice,
              entry:Factory(:entry,import_country_id:@us.id,release_date:"2013-12-01",importer_id:importer.id)
            )
          )
        ).commercial_invoice_line.commercial_invoice_tariffs.create!(entered_value:150)
        Factory(:commercial_invoice_tariff,entered_value:100,
          commercial_invoice_line:Factory(:commercial_invoice_line,vendor_name:'V1',
            commercial_invoice:Factory(:commercial_invoice,
              entry:Factory(:entry,import_country_id:@us.id,release_date:"2013-11-01",importer_id:importer.id)
            )
          )
        )
        Factory(:commercial_invoice_tariff,entered_value:100,
          commercial_invoice_line:Factory(:commercial_invoice_line,vendor_name:'V2',
            commercial_invoice:Factory(:commercial_invoice,
              entry:Factory(:entry,import_country_id:@us.id,release_date:"2013-12-01",importer_id:importer.id)
            )
          )
        )
        Factory(:commercial_invoice_tariff,entered_value:100,
          commercial_invoice_line:Factory(:commercial_invoice_line,vendor_name:'V1',
            commercial_invoice:Factory(:commercial_invoice,
              entry:Factory(:entry,import_country_id:@us.id,release_date:"2012-11-01",importer_id:importer.id)
            )
          )
        )
        # don't find for wrong country
        Factory(:commercial_invoice_tariff,entered_value:100,
          commercial_invoice_line:Factory(:commercial_invoice_line,vendor_name:'V1',
            commercial_invoice:Factory(:commercial_invoice,
              entry:Factory(:entry,import_country_id:Factory(:country).id,release_date:"2013-12-01",importer_id:importer.id)
            )
          )
        )
        h = OpenChain::ActivitySummary::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-25 16:00:00 UTC')
        v = h['vendors_ytd']
        expect(v.size).to eq(2)
        expect(v[0]['name']).to eq('V1')
        expect(v[0]['entered']).to eq(350)
        expect(v[1]['name']).to eq('V2')
        expect(v[1]['entered']).to eq(100)
      end
      it "should create port YTD" do
        importer = Factory(:company)
        Port.create!(:name=>'P1',schedule_d_code:'0001')
        Port.create!(:name=>'P2',schedule_d_code:'0002')
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:100,release_date:'2013-12-25 16:00:00 UTC')
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:50,release_date:'2013-12-18 16:00:00 UTC')
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0002',total_units:75,release_date:'2013-12-18 16:00:00 UTC')
        # don't find not released
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:60,entry_filed_date:'2013-12-25 16:00:00 UTC',release_date:nil)
        # don't find for wrong country
        Factory(:entry,import_country_id:Factory(:country).id,importer_id:importer.id,entry_port_code:'0001',total_units:100,release_date:'2013-12-24 16:00:00 UTC')
        h = OpenChain::ActivitySummary::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-27 16:00:00 UTC')
        p = h['ports_ytd']
        expect(p.entries.size).to eq(2)
        expect(p[0]['name']).to eq('P1')
        expect(p[0]['count']).to eq(2)
        expect(p[0]['code']).to eq('0001')
        expect(p[1]['name']).to eq('P2')
        expect(p[1]['count']).to eq(1)
        expect(p[1]['code']).to eq('0002')
      end
      it "should create port breakouts" do
        importer = Factory(:company)
        Port.create!(:name=>'P1',schedule_d_code:'0001')
        Port.create!(:name=>'P2',schedule_d_code:'0002')
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:100,release_date:'2013-12-25 16:00:00 UTC')
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:50,release_date:'2013-12-18 16:00:00 UTC')
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0002',total_units:75,release_date:'2013-12-18 16:00:00 UTC')
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:60,entry_filed_date:'2013-12-25 16:00:00 UTC',release_date:nil)
        #don't find for wrong country
        Factory(:entry,import_country_id:Factory(:country).id,importer_id:importer.id,entry_port_code:'0001',total_units:60,entry_filed_date:'2013-12-24 16:00:00 UTC',release_date:nil)
        h = OpenChain::ActivitySummary::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-27 16:00:00 UTC')
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
      it "should create hts by line breakouts" do
        importer = Factory(:company)
        hts_codes = ['6112345','6154321','6112345','700000','700000','8412311']
        hts_codes.each_with_index do |h,i|
          Factory(:commercial_invoice_tariff,hts_code:h,
            #everything for 1 week
            commercial_invoice_line: Factory(:commercial_invoice_line,
              commercial_invoice:Factory(:commercial_invoice,entry:
                Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:'2013-12-25 16:00:00 UTC')
              )
            )
          )
          Factory(:commercial_invoice_tariff,hts_code:h,
            #every other for 4 week
            commercial_invoice_line: Factory(:commercial_invoice_line,
              commercial_invoice:Factory(:commercial_invoice,entry:
                Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:'2013-12-18 16:00:00 UTC')
              )
            )
          ) if i%2 == 0
          Factory(:commercial_invoice_tariff,hts_code:h,
            #first for open
            commercial_invoice_line:Factory(:commercial_invoice_line,
              commercial_invoice:Factory(:commercial_invoice,entry:
                Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_filed_date:'2013-12-26 16:00:00 UTC')
              )
            )
          ) if i == 0
          Factory(:commercial_invoice_tariff,hts_code:h,
            #wrong country
            commercial_invoice_line:Factory(:commercial_invoice_line,
              commercial_invoice:Factory(:commercial_invoice,entry:
                Factory(:entry,import_country_id:Factory(:country).id,importer_id:importer.id,entry_filed_date:'2013-12-26 16:00:00 UTC')
              )
            )
          ) if i == 0
        end
        h = OpenChain::ActivitySummary::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-27 16:00:00 UTC')
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
      it "should create unpaid duty breakouts" do
        date = Date.today + 10
        release_date = date.to_datetime
        company = Factory(:company, name: 'Acme', importer: true)
        company.update_attributes(linked_companies: [company])
        Factory(:entry, importer_id: company.id, customer_name: company.name, release_date: release_date, duty_due_date: date, total_duty: 100, total_fees: 200)
        Factory(:entry, importer_id: company.id, customer_name: company.name, release_date: release_date, duty_due_date: date, total_duty: 200, total_fees: 250)

        h = OpenChain::ActivitySummary::USEntrySummaryGenerator.new.generate_hash company.id, Time.parse('2013-12-27 16:00:00 UTC')
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
      it "should delegate to #single_company_unpaid_duty and #linked_companies_unpaid_duty, producing joined/flattened list" do
        c = double('company')
        single_total = [double('single_total')]
        linked_total_1 = [double('linked_total_1')]
        linked_total_2 = [double('linked_total_2')]
        linked_total_3 = [double('linked_total_3')]

        expect_any_instance_of(OpenChain::ActivitySummary::USEntrySummaryGenerator).to receive(:single_company_unpaid_duty).with(c, Date.today).and_return single_total
        expect_any_instance_of(OpenChain::ActivitySummary::USEntrySummaryGenerator).to receive(:linked_companies_unpaid_duty).with(c, Date.today).and_return [linked_total_1, linked_total_2, linked_total_3]
        expect(OpenChain::ActivitySummary::USEntrySummaryGenerator.new.generate_unpaid_duty_section(c, Date.today)).to eq [single_total[0], linked_total_1[0], linked_total_2[0], linked_total_3[0]]
      end
    end

    describe "linked_companies_unpaid_duty" do
      it "should populate an array with the totals of an importer's linked companies" do
        company = Factory(:company, name: 'Acme')
        allow(company).to receive(:linked_companies) {[Company.new(name: 'RiteChoys', importer: true), Company.new(name: 'Super Pow', importer: true), Company.new(name: 'Walshop', importer: true)]}
        expect_any_instance_of(OpenChain::ActivitySummary::USEntrySummaryGenerator).to receive(:single_company_unpaid_duty) {|instance, c, date| [company_name: c.name]}.exactly(3).times
        expect(OpenChain::ActivitySummary::USEntrySummaryGenerator.new.linked_companies_unpaid_duty company, Date.today).to eq [[{company_name: "RiteChoys"}], [{company_name: "Super Pow"}], [{company_name: "Walshop"}]]
      end
    end

    describe "single_company_unpaid_duty" do
      before(:each) do
        @date1 = Date.today
        @date2 = Date.today + 15
        @date3 = Date.today - 10
        @release_date = @date1.to_datetime
        @company = Factory(:company, name: 'Acme')
      end

      it "should not include unreleased entries in totals" do
        Factory(:entry, importer_id: @company.id, release_date: nil, duty_due_date: @date2, total_duty: 600, total_fees: 650)
        h = OpenChain::ActivitySummary::USEntrySummaryGenerator.new.single_company_unpaid_duty @company, Date.today
        expect(h).to be_empty
      end

      it "should not include in totals entries with duty_due_date before today" do
        Factory(:entry, importer_id: @company.id, release_date: @release_date, duty_due_date: @date3, total_duty: 700, total_fees: 750)
        h = OpenChain::ActivitySummary::USEntrySummaryGenerator.new.single_company_unpaid_duty @company, Date.today
        expect(h).to be_empty
      end

      it "should not include in totals entries on monthly statement" do
        Factory(:entry, importer_id: @company.id, release_date: @release_date, duty_due_date: @date1, monthly_statement_due_date: @date2, total_duty: 800, total_fees: 850)
        h = OpenChain::ActivitySummary::USEntrySummaryGenerator.new.single_company_unpaid_duty @company, Date.today
        expect(h).to be_empty
      end
    end

  end

  describe "create_by_release_range_query" do

    before :each do
      @importer = Factory(:company, importer: true)
      @e1 = Factory(:entry, importer: @importer, release_date: '2014-01-01 15:00:00 UTC', entry_filed_date: '2013-12-25', import_country_id: @us.id, source_system: 'Alliance')
      @e2 = Factory(:entry, importer: @importer, release_date: '2014-01-07 15:00:00 UTC', entry_filed_date: '2013-12-25', import_country_id: @us.id, source_system: 'Alliance')
    end

    it "returns a query finding all entries released within 1w" do
      @e2.update_attributes! release_date: '2013-12-31 15:00:00 UTC'
      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', '1w', Time.parse('2014-01-08 12:00:00 UTC')
      results = qry.all

      expect(results.size).to eq(1)
      expect(results.first.id).to eq @e1.id
    end

    it "returns a query finding all CA entries released within 1w" do
      @e1.update_attributes! import_country: @ca
      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'CA', '1w', Time.parse('2014-01-08 12:00:00 UTC')
      results = qry.all

      expect(results.size).to eq(1)
      expect(results.first.id).to eq @e1.id
    end

    it "returns a query finding all entries released within 4w" do
      @e2.update_attributes! release_date: '2013-12-03 15:00:00 UTC'
      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', '4w', Time.parse('2014-01-08 12:00:00 UTC')
      results = qry.all

      expect(results.size).to eq(1)
      expect(results.first.id).to eq @e1.id
    end

    it "returns a query finding all open entries ytd" do
      @e2.update_attributes! release_date: '2013-12-31 15:00:00 UTC'

      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', 'ytd', Time.parse('2014-01-08 12:00:00 UTC')
      results = qry.all

      expect(results.size).to eq(1)
      expect(results.first.id).to eq @e1.id
    end

    it "returns a query finding all unreleased entries" do
      # unreleased also means the release date is in the future
      @e1.update_attributes release_date: nil
      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', 'op', Time.parse('2014-01-07 12:00:00 UTC')
      results = qry.all
      expect(results.size).to eq(2)
    end

    it "excludes non-open entries" do
      @e1.update_attributes! entry_filed_date: nil
      @e2.update_attributes! tracking_status: Entry::TRACKING_STATUS_CLOSED

      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', '1w', Time.parse('2014-01-08 12:00:00 UTC')
      expect(qry.all.size).to eq(0)
    end

    it "excludes entries for other importers" do
      @e2.update_attributes! importer: Factory(:company)

      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', '1w', Time.parse('2014-01-08 12:00:00 UTC')
      expect(qry.all.size).to eq(1)
    end

    it "excludes entries for other countries" do
      @e2.update_attributes! import_country: @ca

      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', '1w', Time.parse('2014-01-08 12:00:00 UTC')
      expect(qry.all.size).to eq(1)
    end
  end

  describe OpenChain::ActivitySummary::DutyDetail do
    before(:each) do
          @date1 = Date.today
          @date2 = Date.today + 15
          date3 = Date.today - 10
          @release_date = @date1.to_datetime

          @company = Factory(:company, name: 'Acme', master: true)
          @non_master_company = Factory(:company, name: "Emca")
          @user = Factory(:user, company: @company)
          port1 = Factory(:port, schedule_d_code: '1234', name: 'Boston')
          port2 = Factory(:port, schedule_d_code: '4321', name: 'New York')

          #included in totals
          @ent1 = Factory(:entry, importer_id: @company.id, entry_port_code: port1.schedule_d_code, entry_number: '12345678912', release_date: @release_date, duty_due_date: @date1, total_duty: 100, total_fees: 200)
          @ent2 = Factory(:entry, importer_id: @company.id, entry_port_code: port1.schedule_d_code, entry_number: '21987654321', release_date: @release_date, duty_due_date: @date1, total_duty: 200, total_fees: 250)
          @ent3 = Factory(:entry, importer_id: @company.id, entry_port_code: port1.schedule_d_code, entry_number: '53471126928', release_date: @release_date, duty_due_date: @date2, total_duty: 300, total_fees: 350)
          @ent4 = Factory(:entry, importer_id: @company.id, entry_port_code: port2.schedule_d_code, entry_number: '14215923867', release_date: @release_date, duty_due_date: @date2, total_duty: 400, total_fees: 450)
          @ent5 = Factory(:entry, importer_id: @company.id, entry_port_code: port2.schedule_d_code, entry_number: '59172148623', release_date: @release_date, duty_due_date: @date2, total_duty: 500, total_fees: 550)

          #excluded from totals
          @ent6 = Factory(:entry, importer_id: @company.id, entry_port_code: port2.schedule_d_code, entry_number: '95711284263', release_date: nil, duty_due_date: @date2, total_duty: 600, total_fees: 650)
          @ent7 = Factory(:entry, importer_id: @company.id, entry_port_code: port2.schedule_d_code, entry_number: '36248211759', release_date: @release_date, duty_due_date: date3, total_duty: 700, total_fees: 750)
          @ent8 = Factory(:entry, importer_id: @company.id, entry_port_code: port2.schedule_d_code, entry_number: '63422811579', release_date: @release_date, duty_due_date: @date1, monthly_statement_due_date: @date2, total_duty: 800, total_fees: 850)
          @ent9 = Factory(:entry, importer_id: @non_master_company.id, entry_port_code: port1.schedule_d_code, entry_number: '23821946175', release_date: @release_date, duty_due_date: @date1, total_duty: 900, total_fees: 950)
        end

      describe "create_linked_digests" do
        it "should populate an array with digests of an importer's linked companies" do
          allow(@company).to receive(:linked_companies) {[Company.new(name: 'RiteChoys', importer: true), Company.new(name: 'Super Pow', importer: true), Company.new(name: 'Walshop', importer: true)]}
          expect(OpenChain::ActivitySummary::DutyDetail).to receive(:create_digest) { |u, c| {company_name: c.name} }.exactly(3).times
          expect(OpenChain::ActivitySummary::DutyDetail.create_linked_digests(@user, @company)).to eq [{company_name: "RiteChoys"}, {company_name: "Super Pow"}, {company_name: "Walshop"}]
        end
      end

      describe "create_digest" do
        it "should delegate to build and get_entries" do
          u = double('user')
          c = double('company')
          e = double('entries')
          expect(OpenChain::ActivitySummary::DutyDetail).to receive(:get_entries).with(u, c).and_return e
          expect(OpenChain::ActivitySummary::DutyDetail).to receive(:build_digest).with(e).and_return 'abc'
          expect(OpenChain::ActivitySummary::DutyDetail.create_digest(u, c)).to eq 'abc'
        end
      end

      describe "build_digest" do
        it "should return empty if entries are empty" do
          allow(@company).to receive(:view_vendors?).with(@user) {true}
          allow(@user).to receive(:view_entries?) {true}

          entries = []
          expect(OpenChain::ActivitySummary::DutyDetail.build_digest(entries)).to be nil
        end

        it "should return digest for multiple dates, ports" do
          allow(@company).to receive(:view_vendors?) {true}
          allow(@user).to receive(:view_entries?) {true}

          entries = OpenChain::ActivitySummary::DutyDetail.get_entries @user, @company
          digest = {:company_name=>"Acme",
                    :company_report=>{:date_hsh=>{@date1=>{:port_hsh=>{"Boston"=>{:port_total_duty=>300,
                                                                                  :port_total_fees=>450,
                                                                                  :port_total_duty_and_fees=>750,
                                                                                  :port_entry_count=> 2,
                                                                                  :entries=>[{ent_id: @ent1.id, ent_entry_number: "12345678912", ent_entry_type: nil, ent_port_name: "Boston",
                                                                                              ent_release_date: @release_date, ent_customer_references: nil, ent_duty_due_date: @date1,
                                                                                              ent_total_fees: 200, ent_total_duty: 100, ent_total_duty_and_fees: 300},
                                                                                             {ent_id: @ent2.id, ent_entry_number: "21987654321", ent_entry_type: nil, ent_port_name: "Boston",
                                                                                              ent_release_date: @release_date, ent_customer_references: nil, ent_duty_due_date: @date1,
                                                                                              ent_total_fees: 250, ent_total_duty: 200, ent_total_duty_and_fees: 450}]}},
                                                          :date_total_duty=>300,
                                                          :date_total_fees=>450,
                                                          :date_total_duty_and_fees=>750,
                                                          :date_entry_count=>2},
                                                 @date2=>{:port_hsh=>{"Boston"=>{:port_total_duty=>300,
                                                                                 :port_total_fees=>350,
                                                                                 :port_total_duty_and_fees=>650,
                                                                                 :port_entry_count=> 1,
                                                                                 :entries=>[{ent_id: @ent3.id, ent_entry_number: "53471126928", ent_entry_type: nil, ent_port_name: "Boston",
                                                                                             ent_release_date: @release_date, ent_customer_references: nil, ent_duty_due_date: @date2,
                                                                                             ent_total_fees: 350, ent_total_duty: 300, ent_total_duty_and_fees: 650}]},
                                                                       "New York"=>{:port_total_duty=>900,
                                                                                    :port_total_fees=>1000,
                                                                                    :port_total_duty_and_fees=>1900,
                                                                                    :port_entry_count=>2,
                                                                                    :entries=>[{ent_id: @ent4.id, ent_entry_number: "14215923867", ent_entry_type: nil, ent_port_name: "New York",
                                                                                                ent_release_date: @release_date, ent_customer_references: nil, ent_duty_due_date: @date2,
                                                                                                ent_total_fees: 450, ent_total_duty: 400, ent_total_duty_and_fees: 850},
                                                                                               {ent_id: @ent5.id, ent_entry_number: "59172148623", ent_entry_type: nil, ent_port_name: "New York",
                                                                                                ent_release_date: @release_date, ent_customer_references: nil, ent_duty_due_date: @date2,
                                                                                                ent_total_fees: 550, ent_total_duty: 500, ent_total_duty_and_fees: 1050}]}},
                                                          :date_total_duty=>1200,
                                                          :date_total_fees=>1350,
                                                          :date_total_duty_and_fees=>2550,
                                                          :date_entry_count=> 3}},
                                     :company_entry_count=> 5,
                                     :company_total_duty=>1500,
                                     :company_total_fees=>1800,
                                     :company_total_duty_and_fees=>3300}}
          expect(OpenChain::ActivitySummary::DutyDetail.build_digest(entries)).to eq digest
        end
      end

      describe "get_entries" do

        it "should return results only for specified company" do
          allow(@company).to receive(:can_view?).with(@user).and_return(true)
          allow(@user).to receive(:view_entries?).and_return(true)

          expect(OpenChain::ActivitySummary::DutyDetail.get_entries(@user, @company).where("importer_id = ? ", @non_master_company.id)).to be_empty
        end

        it "should return empty if user cannot view entries" do
          allow(@company).to receive(:can_view?).with(@user).and_return(true)

          allow(@user).to receive(:view_entries?).and_return(false)
          expect(OpenChain::ActivitySummary::DutyDetail.get_entries(@user, @company)).to be_empty
        end

        it "should return empty if user does not have permission to companies provided" do
          allow(@user).to receive(:view_entries?) {true}

          allow(@company).to receive(:can_view?).with(@user).and_return(false)
          expect(OpenChain::ActivitySummary::DutyDetail.get_entries(@user, @company)).to be_empty
        end

        it "should not return unreleased entries" do
          allow(@company).to receive(:can_view?).with(@user).and_return(true)
          allow(@user).to receive(:view_entries?).and_return(true)

          expect(OpenChain::ActivitySummary::DutyDetail.get_entries(@user, @company).where("release_date IS NULL")).to be_empty
        end

        it "should not return where duty_due_date is before today" do
          allow(@company).to receive(:can_view?).with(@user).and_return(true)
          allow(@user).to receive(:view_entries?).and_return(true)

          expect(OpenChain::ActivitySummary::DutyDetail.get_entries(@user, @company).where("duty_due_date < ?", Date.today)).to be_empty
        end

        it "should not return items on monthly statement" do
          allow(@company).to receive(:can_view?).with(@user).and_return(true)
          allow(@user).to receive(:view_entries?).and_return(true)

          expect(OpenChain::ActivitySummary::DutyDetail.get_entries(@user, @company).where("monthly_statement_due_date IS NOT NULL")).to be_empty
        end

      end

    end

end
