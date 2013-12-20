require 'spec_helper'

describe OpenChain::CustomHandler::JCrew::JCrewDrawbackExportParser do
  describe :parse_csv_line do
    def default_vals
      {
        export_date: '01/31/2011' ,
        ship_date: '02/01/2011',
        part_number: 'ABC',
        ref_1:'R1',
        ref_2:'R2',
        quantity:'20',
        desc:'DE',
        hts:'1234567890'
      }
    end
    def make_row opts={}
      inner_opts = default_vals.merge opts
      r = Array.new 167
      r[8] = inner_opts[:ref_2]
      r[116] = inner_opts[:ref_1]
      r[105] = inner_opts[:ship_date]
      r[106] = inner_opts[:export_date]
      r[120] = inner_opts[:hts]
      r[121] = inner_opts[:quantity] 
      r[122] = inner_opts[:desc]
      r[164] = inner_opts[:part_number]
      r
    end
    before :each do
      @imp = Factory(:company)
    end
    it 'should check for 167 columns' do
      r = make_row
      r << 'another column'
      lambda {described_class.parse_csv_line r, 1, @imp}.should raise_error /Line 1 had 168 elements/
    end
    it "should create line" do
      vals = default_vals
      d = described_class.parse_csv_line(make_row,1,@imp)
      d.class.should == DutyCalcExportFileLine
      d.export_date.strftime("%m/%d/%Y").should == vals[:export_date]
      d.ship_date.strftime("%m/%d/%Y").should == vals[:ship_date]
      d.part_number.should == vals[:part_number]
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
