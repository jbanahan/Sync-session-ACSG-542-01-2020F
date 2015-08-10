require 'spec_helper'

describe OpenChain::ActivitySummary do
  before :each do
    @us = Factory(:country,iso_code:'US')
    @ca = Factory(:country,iso_code:'CA')
  end

  after :each do
    Country.destroy_all
  end

  describe :generate_us_entry_summary do
    it "should make json" do
      ent = Factory(:entry,import_country_id:@us.id,importer_id:Factory(:company).id,release_date:'2013-12-25 05:00:00 UTC')
      h = described_class.generate_us_entry_summary(ent.importer_id, Time.parse('2013-12-27 16:00:00 UTC'))
      h['activity_summary']['summary']['1w']['count'].should == 1
    end
  end
  describe :generate_ca_entry_summary do
    it "should make json" do
      ent = Factory(:entry,import_country_id:@ca.id,importer_id:Factory(:company).id,release_date:'2013-12-25 05:00:00 UTC')
      h = described_class.generate_ca_entry_summary(ent.importer_id, Time.parse('2013-12-27 16:00:00 UTC'))
      h['activity_summary']['summary']['1w']['count'].should == 1
    end
  end

  describe OpenChain::ActivitySummary::CAEntrySummaryGenerator do

    it "should create summary section" do
      importer = Factory(:company)
      ent = Factory(:entry,import_country_id:@ca.id,importer_id:importer.id,release_date:'2013-12-25 05:00:00 UTC', total_duty:100,total_gst:50,total_duty_gst:150,entered_value:1000,total_invoiced_value:1100,total_units:70)
      ent2 = Factory(:entry,import_country_id:@ca.id,importer_id:importer.id,release_date: '2013-12-15 05:00:00 UTC', total_duty:200,total_gst:75,total_duty_gst:275,entered_value:1500,total_invoiced_value:1600,total_units:40)
      ent3 = Factory(:entry,import_country_id:@ca.id,importer_id:importer.id,file_logged_date:'2013-12-18 05:00:00 UTC',total_duty:50,total_gst:40,total_duty_gst:90,entered_value:60,total_invoiced_value:66,total_units:3)
      ent2 = Factory(:entry,import_country_id:@ca.id,importer_id:importer.id,release_date:'2012-12-25 05:00:00 UTC',total_duty:200,total_gst:75,total_duty_gst:275,entered_value:1500,total_invoiced_value:1600,total_units:40)

      h = described_class::CAEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-27 16:00:00 UTC')
      h['summary']['1w']['count'].should == 1
      h['summary']['1w']['duty'].should == 100 
      h['summary']['1w']['gst'].should == 50
      h['summary']['1w']['duty_gst'].should == 150
      h['summary']['1w']['entered'].should == 1000 
      h['summary']['1w']['invoiced'].should == 1100
      h['summary']['1w']['units'].should == 70
      h['summary']['4w']['count'].should == 2
      h['summary']['4w']['duty'].should == 300
      h['summary']['4w']['gst'].should == 125
      h['summary']['4w']['duty_gst'].should == 425
      h['summary']['4w']['entered'].should == 2500
      h['summary']['4w']['invoiced'].should == 2700
      h['summary']['4w']['units'].should == 110
      h['summary']['open']['count'].should == 1
      h['summary']['open']['duty'].should == 50
      h['summary']['open']['gst'].should == 40
      h['summary']['open']['duty_gst'].should == 90
      h['summary']['open']['entered'].should == 60
      h['summary']['open']['invoiced'].should == 66
      h['summary']['open']['units'].should == 3
      h['summary']['ytd']['count'].should == 2
      h['summary']['ytd']['duty'].should == 300
      h['summary']['ytd']['gst'].should == 125
      h['summary']['ytd']['duty_gst'].should == 425
      h['summary']['ytd']['entered'].should == 2500
      h['summary']['ytd']['invoiced'].should == 2700
      h['summary']['ytd']['units'].should == 110
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
      h = described_class::CAEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-02-25 16:00:00 UTC')
      k = h['k84']
      k.should have(4).results
      k[0]['importer_name'].should == 'IMP'
      k[0]['due'].should == Date.new(2013,3,25)
      k[0]['amount'].should == 400
      k[1]['importer_name'].should == 'IMP'
      k[1]['due'].should == Date.new(2013,2,25)
      k[1]['amount'].should == 300
      k[2]['importer_name'].should == 'IMP'
      k[2]['due'].should == Date.new(2013,1,25)
      k[2]['amount'].should == 300
      k[3]['importer_name'].should == 'IMP'
      k[3]['due'].should == Date.new(2012,12,25)
      k[3]['amount'].should == 100
    end
  end
  describe OpenChain::ActivitySummary::USEntrySummaryGenerator do
    describe :generate_hash do
      it "should create summary section" do
        importer = Factory(:company)

        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:'2013-12-25 05:00:00 UTC',total_duty:100,total_fees:50,entered_value:1000,total_invoiced_value:1100,total_units:70)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:'2013-12-15 05:00:00 UTC',total_duty:200,total_fees:75,entered_value:1500,total_invoiced_value:1600,total_units:40)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_filed_date:'2013-12-18 05:00:00 UTC',total_duty:50,total_fees:40,entered_value:60,total_invoiced_value:66,total_units:3)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:'2012-12-25 05:00:00 UTC',total_duty:200,total_fees:75,entered_value:1500,total_invoiced_value:1600,total_units:40)
        #don't find for wrong country
        Factory(:entry,import_country_id:Factory(:country).id,importer_id:importer.id,release_date:2.day.ago,total_duty:100,total_fees:50,entered_value:1000,total_invoiced_value:1100,total_units:70)
        h = described_class::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-27 16:00:00 UTC')
        h['summary']['1w']['count'].should == 1
        h['summary']['1w']['duty'].should == 100 
        h['summary']['1w']['fees'].should == 50
        h['summary']['1w']['entered'].should == 1000 
        h['summary']['1w']['invoiced'].should == 1100
        h['summary']['1w']['units'].should == 70
        h['summary']['4w']['count'].should == 2
        h['summary']['4w']['duty'].should == 300
        h['summary']['4w']['fees'].should == 125
        h['summary']['4w']['entered'].should == 2500
        h['summary']['4w']['invoiced'].should == 2700
        h['summary']['4w']['units'].should == 110
        h['summary']['open']['count'].should == 1
        h['summary']['open']['duty'].should == 50
        h['summary']['open']['fees'].should == 40
        h['summary']['open']['entered'].should == 60
        h['summary']['open']['invoiced'].should == 66
        h['summary']['open']['units'].should == 3
        h['summary']['ytd']['count'].should == 2
        h['summary']['ytd']['duty'].should == 300
        h['summary']['ytd']['fees'].should == 125
        h['summary']['ytd']['entered'].should == 2500
        h['summary']['ytd']['invoiced'].should == 2700
        h['summary']['ytd']['units'].should == 110
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
        h = described_class::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-11-25 16:00:00 UTC')
        statements = h['pms']
        statements.should have(4).records
        statements[0]['importer_name'].should == 'IMP'
        statements[0]['due'].should == Date.new(2013,12,25)
        statements[0]['paid'].should be_nil
        statements[0]['amount'].should == 150
        statements[1]['importer_name'].should == 'IMP'
        statements[1]['due'].should == Date.new(2013,11,25)
        statements[1]['paid'].should == Date.new(2013,11,24)
        statements[1]['amount'].should == 600
        statements[2]['importer_name'].should == 'IMP'
        statements[2]['due'].should == Date.new(2013,10,25)
        statements[2]['paid'].should == Date.new(2013,10,24)
        statements[2]['amount'].should == 300
        statements[3]['importer_name'].should == 'IMP'
        statements[3]['paid'].should == Date.new(2013,9,24)
        statements[3]['amount'].should == 300
      end

      it "should create separate lines per importer_id" do
        imp1 = Factory(:company,name:'imp1')
        Factory(:entry,import_country_id:@us.id,importer_id:imp1.id,monthly_statement_due_date:Date.new(2013,11,25),monthly_statement_paid_date:Date.new(2013,11,24),total_duty:200,total_fees:100)
        imp2 = Factory(:company,name:'imp2') #linked
        Factory(:entry,import_country_id:@us.id,importer_id:imp2.id,monthly_statement_due_date:Date.new(2013,11,25),monthly_statement_paid_date:Date.new(2013,11,24),total_duty:200,total_fees:100)
        imp3 = Factory(:company,name:'imp3') #not linked
        Factory(:entry,import_country_id:@us.id,importer_id:imp3.id,monthly_statement_due_date:Date.new(2013,11,25),monthly_statement_paid_date:Date.new(2013,11,24),total_duty:200,total_fees:100)
        imp1.linked_companies << imp2
        h = described_class::USEntrySummaryGenerator.new.generate_hash imp1.id, Time.parse('2013-11-25 16:00:00 UTC')
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
        h = described_class::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-25 16:00:00 UTC')
        v = h['vendors_ytd']
        v.should have(2).records
        v[0]['name'].should == 'V1'
        v[0]['entered'].should == 350
        v[1]['name'].should == 'V2'
        v[1]['entered'].should == 100
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
        h = described_class::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-27 16:00:00 UTC')
        p = h['ports_ytd']
        p.should have(2).entries
        p[0]['name'].should == 'P1'
        p[0]['count'].should == 2
        p[0]['code'].should == '0001'
        p[1]['name'].should == 'P2'
        p[1]['count'].should == 1
        p[1]['code'].should == '0002'
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
        h = described_class::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-27 16:00:00 UTC')
        bp = h['by_port']
        bp.should have(3).ports
        bp.first['name'].should == 'P1'
        bp.first['1w'].should == 1
        bp.first['4w'].should == 2
        bp.first['open'].should == 1
        bp.first['code'].should == '0001'
        bp[1]['name'].should == 'P2'
        bp[1]['1w'].should be_nil
        bp[1]['4w'].should == 1
        bp[1]['open'].should be_nil
        bp[1]['code'].should == '0002'
        bp.last['name'].should == 'TOTAL'
        bp.last['1w'].should == 1
        bp.last['4w'].should == 3
        bp.last['open'].should == 1
        bp.last['code'].should be_nil
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
        h = described_class::USEntrySummaryGenerator.new.generate_hash importer.id, Time.parse('2013-12-27 16:00:00 UTC')
        bh = h['by_hts']
        bh.should have(4).records
        bh[0]['name'].should == '61'
        bh[0]['1w'].should == 3
        bh[0]['4w'].should == 5
        bh[0]['open'].should == 1
        bh[1]['name'].should == '70'
        bh[1]['1w'].should == 2
        bh[1]['4w'].should == 3
        bh[1]['open'].should be_nil
        bh[2]['name'].should == '84'
        bh[2]['1w'].should == 1
        bh[2]['4w'].should == 1 
        bh[2]['open'].should be_nil
        bh[3]['name'].should == 'TOTAL'
        bh[3]['1w'].should == 6
        bh[3]['4w'].should == 9
        bh[3]['open'].should == 1
      end
      it "should create unpaid duty breakouts" do
        date = Date.today + 10
        release_date = date.to_datetime
        company = Factory(:company, name: 'Acme')
        company.update_attributes(linked_companies: [company])
        Factory(:entry, importer_id: company.id, release_date: release_date, duty_due_date: date, total_duty: 100, total_fees: 200)
        Factory(:entry, importer_id: company.id, release_date: release_date, duty_due_date: date, total_duty: 200, total_fees: 250)
        
        h = described_class::USEntrySummaryGenerator.new.generate_hash company.id, Time.parse('2013-12-27 16:00:00 UTC')
        unpaid_duty = h['unpaid_duty']
        expect(unpaid_duty[0]['name']).to eq 'Acme'
        expect(unpaid_duty[0]['total_duty']).to eq 300
        expect(unpaid_duty[0]['total_fees']).to eq 450
        expect(unpaid_duty[0]['total_duty_and_fees']).to eq 750
        expect(unpaid_duty[1]['name']).to eq 'Acme'
        expect(unpaid_duty[1]['total_duty']).to eq 300
        expect(unpaid_duty[1]['total_fees']).to eq 450
        expect(unpaid_duty[1]['total_duty_and_fees']).to eq 750
      end
    end

    describe :generate_unpaid_duty_section do
      it "should delegate to #single_company_unpaid_duty and #linked_companies_unpaid_duty, producing joined/flattened list" do
        c = double('company').as_null_object
        single_total = [double('single_total').as_null_object]
        linked_total_1 = [double('linked_total_1').as_null_object]
        linked_total_2 = [double('linked_total_2').as_null_object]
        linked_total_3 = [double('linked_total_3').as_null_object]

        described_class::USEntrySummaryGenerator.any_instance.should_receive(:single_company_unpaid_duty).with(c).and_return single_total
        described_class::USEntrySummaryGenerator.any_instance.should_receive(:linked_companies_unpaid_duty).with(c).and_return [linked_total_1, linked_total_2, linked_total_3]
        expect(described_class::USEntrySummaryGenerator.new.generate_unpaid_duty_section(c)).to eq [single_total[0], linked_total_1[0], linked_total_2[0], linked_total_3[0]]
      end
    end

    describe :linked_companies_unpaid_duty do
      it "should populate an array with the totals of an importer's linked companies" do
        company = Factory(:company, name: 'Acme')
        company.stub(:linked_companies) {[Company.new(name: 'RiteChoys'), Company.new(name: 'Super Pow'), Company.new(name: 'Walshop')]}
        described_class::USEntrySummaryGenerator.any_instance.should_receive(:single_company_unpaid_duty) {|c| [company_name: c.name]}.exactly(3).times
        expect(described_class::USEntrySummaryGenerator.new.linked_companies_unpaid_duty company).to eq [[{company_name: "RiteChoys"}], [{company_name: "Super Pow"}], [{company_name: "Walshop"}]]
      end
    end

    describe :single_company_unpaid_duty do
      before(:each) do
        @date1 = Date.today + 10
        @date2 = Date.today + 15
        @date3 = Date.today - 10
        @release_date = @date1.to_datetime
        @company = Factory(:company, name: 'Acme')     
      end

      it "should not include unreleased entries in totals" do
        Factory(:entry, importer_id: @company.id, release_date: nil, duty_due_date: @date2, total_duty: 600, total_fees: 650)
        h = described_class::USEntrySummaryGenerator.new.single_company_unpaid_duty @company
        expect(h).to be_empty
      end

      it "should not include in totals entries with duty_due_date before today" do
        Factory(:entry, importer_id: @company.id, release_date: @release_date, duty_due_date: @date3, total_duty: 700, total_fees: 750)
        h = described_class::USEntrySummaryGenerator.new.single_company_unpaid_duty @company 
        expect(h).to be_empty
      end
    
      it "should not include in totals entries on monthly statement" do
        Factory(:entry, importer_id: @company.id, release_date: @release_date, duty_due_date: @date1, monthly_statement_due_date: @date2, total_duty: 800, total_fees: 850)
        h = described_class::USEntrySummaryGenerator.new.single_company_unpaid_duty @company
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

      expect(results).to have(1).item
      expect(results.first.id).to eq @e1.id
    end

    it "returns a query finding all CA entries released within 1w" do
      @e1.update_attributes! import_country: @ca
      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'CA', '1w', Time.parse('2014-01-08 12:00:00 UTC')
      results = qry.all

      expect(results).to have(1).item
      expect(results.first.id).to eq @e1.id
    end

    it "returns a query finding all entries released within 4w" do
      @e2.update_attributes! release_date: '2013-12-03 15:00:00 UTC'
      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', '4w', Time.parse('2014-01-08 12:00:00 UTC')
      results = qry.all

      expect(results).to have(1).item
      expect(results.first.id).to eq @e1.id
    end

    it "returns a query finding all open entries ytd" do
      @e2.update_attributes! release_date: '2013-12-31 15:00:00 UTC'

      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', 'ytd', Time.parse('2014-01-08 12:00:00 UTC')
      results = qry.all

      expect(results).to have(1).item
      expect(results.first.id).to eq @e1.id
    end

    it "returns a query finding all unreleased entries" do
      # unreleased also means the release date is in the future
      @e1.update_attributes release_date: nil
      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', 'op', Time.parse('2014-01-07 12:00:00 UTC')
      results = qry.all
      expect(results).to have(2).items
    end

    it "excludes non-open entries" do
      @e1.update_attributes! entry_filed_date: nil
      @e2.update_attributes! tracking_status: Entry::TRACKING_STATUS_CLOSED

      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', '1w', Time.parse('2014-01-08 12:00:00 UTC')
      expect(qry.all).to have(0).items
    end

    it "excludes entries for other importers" do
      @e2.update_attributes! importer: Factory(:company)

      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', '1w', Time.parse('2014-01-08 12:00:00 UTC')
      expect(qry.all).to have(1).item
    end

    it "excludes entries for other countries" do
      @e2.update_attributes! import_country: @ca

      qry = OpenChain::ActivitySummary.create_by_release_range_query @importer.id, 'US', '1w', Time.parse('2014-01-08 12:00:00 UTC')
      expect(qry.all).to have(1).item
    end
  end

  describe OpenChain::ActivitySummary::DutyDetail do
    before(:each) do
          @date1 = Date.today + 10
          @date2 = Date.today + 15
          date3 = Date.today - 10
          @release_date = @date1.to_datetime
         
          @company = Factory(:company, name: 'Acme')
          @user = Factory(:user, company: @company)
          port1 = Factory(:port, schedule_d_code: '1234', name: 'Boston')
          port2 = Factory(:port, schedule_d_code: '4321', name: 'New York')
          Factory(:entry, importer_id: @company.id, entry_port_code: port1.schedule_d_code, entry_number: '12345678912', release_date: @release_date, duty_due_date: @date1, total_duty: 100, total_fees: 200)
          Factory(:entry, importer_id: @company.id, entry_port_code: port1.schedule_d_code, entry_number: '21987654321', release_date: @release_date, duty_due_date: @date1, total_duty: 200, total_fees: 250)
          Factory(:entry, importer_id: @company.id, entry_port_code: port1.schedule_d_code, entry_number: '53471126928', release_date: @release_date, duty_due_date: @date2, total_duty: 300, total_fees: 350)
          Factory(:entry, importer_id: @company.id, entry_port_code: port2.schedule_d_code, entry_number: '14215923867', release_date: @release_date, duty_due_date: @date2, total_duty: 400, total_fees: 450)
          Factory(:entry, importer_id: @company.id, entry_port_code: port2.schedule_d_code, entry_number: '59172148623', release_date: @release_date, duty_due_date: @date2, total_duty: 500, total_fees: 550)
          Factory(:entry, importer_id: @company.id, entry_port_code: port2.schedule_d_code, entry_number: '95711284263', release_date: nil, duty_due_date: @date2, total_duty: 600, total_fees: 650)
          Factory(:entry, importer_id: @company.id, entry_port_code: port2.schedule_d_code, entry_number: '36248211759', release_date: @release_date, duty_due_date: date3, total_duty: 700, total_fees: 750)
          Factory(:entry, importer_id: @company.id, entry_port_code: port2.schedule_d_code, entry_number: '63422811579', release_date: @release_date, duty_due_date: @date1, monthly_statement_due_date: @date2, total_duty: 800, total_fees: 850)

        end

      describe :create_linked_digests do
        it "should populate an array with digests of an importer's linked companies" do
          @company.stub(:linked_companies) {[Company.new(name: 'RiteChoys'), Company.new(name: 'Super Pow'), Company.new(name: 'Walshop')]}
          described_class::DutyDetail.should_receive(:create_digest) { |u, c| {company_name: c.name} }.exactly(3).times
          expect(described_class::DutyDetail.create_linked_digests(@user, @company)).to eq [{company_name: "RiteChoys"}, {company_name: "Super Pow"}, {company_name: "Walshop"}]   
        end
      end

      describe :create_digest do
        it "should delegate to build and get_entries" do
          u = double('user')
          c = double('company')
          e = double('entries')
          described_class::DutyDetail.should_receive(:get_entries).with(u, c).and_return e
          described_class::DutyDetail.should_receive(:build_digest).with(e).and_return 'abc'
          expect(described_class::DutyDetail.create_digest(u, c)).to eq 'abc'
        end
      end

      describe :build_digest do
        it "should return empty if entries are empty" do
          @company.stub(:view_vendors?).with(@user) {true}
          @user.stub(:view_entries?) {true}

          entries = []
          expect(described_class::DutyDetail.build_digest(entries)).to be_empty
        end
        
        it "should return digest for multiple dates, ports" do
          @company.stub(:view_vendors?) {true}
          @user.stub(:view_entries?) {true}
          
          entries = described_class::DutyDetail.get_entries @user, @company
          digest = {:company_name=>"Acme",
                    :company_report=>{:date_hsh=>{@date1=>{:port_hsh=>{"Boston"=>{:port_total_duty=>300, 
                                                                                  :port_total_fees=>450, 
                                                                                  :port_total_duty_and_fees=>750, 
                                                                                  :port_entry_count=> 2,                                                                                  
                                                                                  :entries=>[{ent_entry_number: "12345678912", ent_entry_type: nil, ent_port_name: "Boston", 
                                                                                              ent_release_date: @release_date, ent_customer_references: nil, ent_duty_due_date: @date1, 
                                                                                              ent_total_fees: 200, ent_total_duty: 100, ent_total_duty_and_fees: 300}, 
                                                                                             {ent_entry_number: "21987654321", ent_entry_type: nil, ent_port_name: "Boston", 
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
                                                                                 :entries=>[{ent_entry_number: "53471126928", ent_entry_type: nil, ent_port_name: "Boston", 
                                                                                             ent_release_date: @release_date, ent_customer_references: nil, ent_duty_due_date: @date2, 
                                                                                             ent_total_fees: 350, ent_total_duty: 300, ent_total_duty_and_fees: 650}]}, 
                                                                       "New York"=>{:port_total_duty=>900,
                                                                                    :port_total_fees=>1000,
                                                                                    :port_total_duty_and_fees=>1900,
                                                                                    :port_entry_count=>2,                                                                                    
                                                                                    :entries=>[{ent_entry_number: "14215923867", ent_entry_type: nil, ent_port_name: "New York", 
                                                                                                ent_release_date: @release_date, ent_customer_references: nil, ent_duty_due_date: @date2, 
                                                                                                ent_total_fees: 450, ent_total_duty: 400, ent_total_duty_and_fees: 850}, 
                                                                                               {ent_entry_number: "59172148623", ent_entry_type: nil, ent_port_name: "New York", 
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
          expect(described_class::DutyDetail.build_digest(entries)).to eq digest
        end
      end

      describe :get_entries do

        it "should return empty if user cannot view entries" do
          @company.stub(:can_view?).with(anything()).and_return(true)
          
          @user.stub(:view_entries?).and_return(false)
          expect(described_class::DutyDetail.get_entries(@user, @company)).to be_empty
        end
        
        it "should return empty if user does not have permission to companies provided" do
          @user.stub(:view_entries?) {true}
          
          @company.stub(:can_view?).with(anything()).and_return(false)
          expect(described_class::DutyDetail.get_entries(@user, @company)).to be_empty
        end
        
        it "should not return unreleased entries" do
          @company.stub(:can_view?).with(anything()).and_return(true)
          @user.stub(:view_entries?).and_return(true)
          
          expect(described_class::DutyDetail.get_entries(@user, @company).where("release_date IS NULL")).to be_empty
        end
        
        it "should not return where duty_due_date is before today" do
          @company.stub(:can_view?).with(anything()).and_return(true)
          @user.stub(:view_entries?).and_return(true)

          expect(described_class::DutyDetail.get_entries(@user, @company).where("duty_due_date < ?", Date.today)).to be_empty
        end
        
        it "should not return items on monthly statement" do
          @company.stub(:can_view?).with(anything()).and_return(true)
          @user.stub(:view_entries?).and_return(true)

          expect(described_class::DutyDetail.get_entries(@user, @company).where("monthly_statement_due_date IS NOT NULL")).to be_empty 
        end

      end

    end

end
