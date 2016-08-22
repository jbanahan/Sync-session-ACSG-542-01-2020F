require 'spec_helper'

describe OpenChain::CustomHandler::JCrew::JCrewDrawbackExportParser do
  describe "parse_csv_line" do
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
      expect {described_class.parse_csv_line r, 1, @imp}.to raise_error(/Line 1 had 168 elements/)
    end
    it "should create line" do
      vals = default_vals
      d = described_class.parse_csv_line(make_row,1,@imp)
      expect(d.class).to eq DutyCalcExportFileLine
      expect(d.export_date.strftime("%m/%d/%Y")).to eq vals[:export_date]
      expect(d.ship_date.strftime("%m/%d/%Y")).to eq vals[:ship_date]
      expect(d.part_number).to eq vals[:part_number]
      expect(d.ref_1).to eq vals[:ref_1]
      expect(d.ref_2).to eq vals[:ref_2]
      expect(d.quantity.to_s).to eq vals[:quantity]
      expect(d.description).to eq vals[:desc]
      expect(d.uom).to eq 'EA'
      expect(d.destination_country).to eq 'CA'
      expect(d.exporter).to eq 'J Crew'
      expect(d.action_code).to eq 'E'
      expect(d.hts_code).to eq vals[:hts]
      expect(d.importer).to eq @imp
    end
  end
end
