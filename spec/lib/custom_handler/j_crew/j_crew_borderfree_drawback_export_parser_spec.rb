require 'spec_helper'

describe OpenChain::CustomHandler::JCrew::JCrewBorderfreeDrawbackExportParser do
  describe :parse_csv_line do
    def default_vals
      {
        export_date: '8/23/2011 2:15:32 PM' ,
        ship_date: '8/23/2011 2:15:32 PM',
        part_number: 'Short Description - 123456789-ABCDEF - KEYWORDS',
        ref_1:'R1',
        ref_2:'R2',
        carrier: 'Test Carrier',
        destination_country: 'CA',
        uom: 'EA',
        quantity:'20',
        desc:'DE',
        hts:'1234567890'
      }
    end
    def make_row opts={}
      inner_opts = default_vals.merge opts
      r = Array.new 17
      r[2] = inner_opts[:ship_date]
      r[2] = inner_opts[:export_date]
      r[4] = inner_opts[:ref_1]
      r[6] = inner_opts[:ref_2]
      r[8] = inner_opts[:destination_country]
      r[11] = inner_opts[:desc]
      r[12] = inner_opts[:part_number]
      r[15] = inner_opts[:quantity] 
      r[16] = inner_opts[:uom]
      r
    end
    before :each do
      @imp = Factory(:company)
      @usa = Factory(:country, iso_code: 'US')
      @jc1 = Factory(:company, alliance_customer_number: 'J0000')
      @jc2 = Factory(:company, alliance_customer_number: 'JCREW')
    end
    it 'should check for 17 columns (A through Q)' do
      r = make_row
      r << 'another column'
      lambda {described_class.parse_csv_line r, 1, @imp}.should raise_error /Line 1 had 18 elements/
    end
    it "should create line" do
      vals = default_vals

      # this mock could probably be eliminated and replaced with a Factory(:product, ...) if necessary
      OpenChain::TariffFinder.any_instance.should_receive(:find_by_style).with('123456789-ABCDEF').and_return "1234567890"
      d = described_class.parse_csv_line(make_row,1,@imp)

      d.class.should == DutyCalcExportFileLine
      d.export_date.strftime("%Y-%m-%d").should == "2011-08-23"
      d.ship_date.strftime("%Y-%m-%d").should == "2011-08-23"
      d.part_number.should == "123456789-ABCDEF"
      d.ref_1.should == vals[:ref_1]
      d.ref_2.should == vals[:ref_2]
      d.quantity.to_s.should == vals[:quantity]
      d.description.should == vals[:desc]
      d.uom.should == 'EA'
      d.destination_country.should == 'CA'
      d.exporter.should == 'J Crew'
      d.action_code.should == 'E'


      d.hts_code.should == vals[:hts]
      d.importer.should == @imp
    end
  end
end
