require 'spec_helper'

describe OpenChain::ActivitySummary do
  describe :generate_entry_summary do
    it "should make json" do
      @us = Factory(:country,iso_code:'US')
      ent = Factory(:entry,import_country_id:@us.id,importer_id:Factory(:company).id,release_date:1.day.ago)
      h = described_class.generate_entry_summary(ent.importer_id)
      h['activity_summary']['summary']['1w']['count'].should == 1
    end
  end

  describe OpenChain::ActivitySummary::USEntrySummaryGenerator do
    before :each do 
      @us = Factory(:country,iso_code:'US')
    end
    describe :generate_hash do
      it "should create summary section" do
        importer = Factory(:company)
        ent = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:2.day.ago,total_duty:100,total_fees:50,entered_value:1000,total_invoiced_value:1100,total_units:70)
        ent2 = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:10.days.ago,total_duty:200,total_fees:75,entered_value:1500,total_invoiced_value:1600,total_units:40)
        ent3 = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_filed_date:1.week.ago,total_duty:50,total_fees:40,entered_value:60,total_invoiced_value:66,total_units:3)
        ent2 = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:367.days.ago,total_duty:200,total_fees:75,entered_value:1500,total_invoiced_value:1600,total_units:40)
        h = described_class::USEntrySummaryGenerator.generate_hash importer.id, 0.days.ago.to_date
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
        h['summary']['ytd']['count'].should == 3
        h['summary']['ytd']['duty'].should == 350
        h['summary']['ytd']['fees'].should == 165
        h['summary']['ytd']['entered'].should == 2560
        h['summary']['ytd']['invoiced'].should == 2766
        h['summary']['ytd']['units'].should == 113
      end

      it "should create statments section" do
        importer = Factory(:company)
        not_paid = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,12,25),monthly_statement_paid_date:nil,total_duty:100,total_fees:50)
        paid1 = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,11,25),monthly_statement_paid_date:Date.new(2013,11,24),total_duty:200,total_fees:100)
        paid2 = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,11,25),monthly_statement_paid_date:Date.new(2013,11,24),total_duty:200,total_fees:100)
        paid3 = Factory(:entry,import_country_id:@us.id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,10,25),monthly_statement_paid_date:Date.new(2013,10,24),total_duty:200,total_fees:100)
        #next line won't be included since we only return 3 records
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,monthly_statement_due_date:Date.new(2013,9,25),monthly_statement_paid_date:Date.new(2013,9,24),total_duty:200,total_fees:100)
        h = described_class::USEntrySummaryGenerator.generate_hash importer.id, 0.days.ago.to_date
        statements = h['pms']
        statements.should have(3).records
        statements[0]['due'].should == Date.new(2013,12,25)
        statements[0]['paid'].should be_nil
        statements[0]['amount'].should == 150
        statements[1]['due'].should == Date.new(2013,11,25)
        statements[1]['paid'].should == Date.new(2013,11,24)
        statements[1]['amount'].should == 600
        statements[2]['due'].should == Date.new(2013,10,25)
        statements[2]['paid'].should == Date.new(2013,10,24)
        statements[2]['amount'].should == 300
      end

      it "should create top 5 vendors YTD" do
        importer = Factory(:company)
        Factory(:commercial_invoice_tariff,entered_value:100,
          commercial_invoice_line:Factory(:commercial_invoice_line,vendor_name:'V1',
            commercial_invoice:Factory(:commercial_invoice,
              entry:Factory(:entry,import_country_id:@us.id,release_date:1.week.ago,importer_id:importer.id)
            )
          )
        ).commercial_invoice_line.commercial_invoice_tariffs.create!(entered_value:150)
        Factory(:commercial_invoice_tariff,entered_value:100,
          commercial_invoice_line:Factory(:commercial_invoice_line,vendor_name:'V1',
            commercial_invoice:Factory(:commercial_invoice,
              entry:Factory(:entry,import_country_id:@us.id,release_date:2.week.ago,importer_id:importer.id)
            )
          )
        )
        Factory(:commercial_invoice_tariff,entered_value:100,
          commercial_invoice_line:Factory(:commercial_invoice_line,vendor_name:'V2',
            commercial_invoice:Factory(:commercial_invoice,
              entry:Factory(:entry,import_country_id:@us.id,release_date:2.week.ago,importer_id:importer.id)
            )
          )
        )
        Factory(:commercial_invoice_tariff,entered_value:100,
          commercial_invoice_line:Factory(:commercial_invoice_line,vendor_name:'V1',
            commercial_invoice:Factory(:commercial_invoice,
              entry:Factory(:entry,import_country_id:@us.id,release_date:2.years.ago,importer_id:importer.id)
            )
          )
        )
        h = described_class::USEntrySummaryGenerator.generate_hash importer.id, 0.days.ago.to_date
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
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:100,release_date:3.days.ago)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:50,release_date:10.days.ago)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0002',total_units:75,release_date:10.days.ago)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:60,entry_filed_date:2.days.ago,release_date:nil)
        h = described_class::USEntrySummaryGenerator.generate_hash importer.id, 0.days.ago.to_date
        p = h['ports_ytd']
        p.should have(2).entries
        p[0]['name'].should == 'P1'
        p[0]['count'].should == 3
        p[0]['code'].should == '0001'
        p[1]['name'].should == 'P2'
        p[1]['count'].should == 1
        p[1]['code'].should == '0002'
      end
      it "should create port breakouts" do
        importer = Factory(:company)
        Port.create!(:name=>'P1',schedule_d_code:'0001')
        Port.create!(:name=>'P2',schedule_d_code:'0002')
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:100,release_date:3.days.ago)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:50,release_date:10.days.ago)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0002',total_units:75,release_date:10.days.ago)
        Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_port_code:'0001',total_units:60,entry_filed_date:2.days.ago,release_date:nil)
        h = described_class::USEntrySummaryGenerator.generate_hash importer.id, 0.days.ago.to_date
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
                Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:2.days.ago)
              )
            )
          )
          Factory(:commercial_invoice_tariff,hts_code:h,
            #every other for 4 week
            commercial_invoice_line: Factory(:commercial_invoice_line,
              commercial_invoice:Factory(:commercial_invoice,entry:
                Factory(:entry,import_country_id:@us.id,importer_id:importer.id,release_date:10.days.ago)
              )
            )
          ) if i%2 == 0
          Factory(:commercial_invoice_tariff,hts_code:h,
            #first for open
            commercial_invoice_line:Factory(:commercial_invoice_line,
              commercial_invoice:Factory(:commercial_invoice,entry:
                Factory(:entry,import_country_id:@us.id,importer_id:importer.id,entry_filed_date:1.day.ago)
              )
            )
          ) if i == 0
        end
        h = described_class::USEntrySummaryGenerator.generate_hash importer.id, 0.days.ago.to_date
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
    end
  end
end
