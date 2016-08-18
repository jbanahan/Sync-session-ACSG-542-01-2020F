require 'tempfile'
require 'spec_helper'

describe OpenChain::CustomHandler::JCrew::JCrewBorderfreeDrawbackExportParser do
  describe :parse_csv_file do
    before :each do
      @f = Tempfile.new('foo')
    end
    after :each do
      @f.unlink
    end
    it 'should handle pipe delimited line' do
      imp = double('importer')
      data = "a\n1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17"
      described_class.should_receive(:parse_csv_line).with((1..17).map{|i| i.to_s},1,imp)
      @f.write data
      @f.flush
      described_class.parse_csv_file @f.path, imp
    end
  end
  describe :parse_csv_line do
    def default_vals
      {
        export_date: '8/23/2011 2:15:32 PM' ,
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
      expect{described_class.parse_csv_line r, 1, @imp}.to raise_error(/Line 1 had 18 elements/)
    end
    it "should create line" do
      vals = default_vals

      # this mock could probably be eliminated and replaced with a Factory(:product, ...) if necessary
      OpenChain::TariffFinder.any_instance.should_receive(:find_by_style).with('123456789-ABCDEF').and_return "1234567890"
      d = described_class.parse_csv_line(make_row,1,@imp)

      expect(d.class).to eq DutyCalcExportFileLine
      expect(d.export_date.strftime("%Y-%m-%d")).to eq "2011-08-23"
      expect(d.ship_date.strftime("%Y-%m-%d")).to eq "2011-08-23"
      expect(d.part_number).to eq "123456789-ABCDEF"
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
    it 'should handle short date format' do
      OpenChain::TariffFinder.any_instance.should_receive(:find_by_style).with('123456789-ABCDEF').and_return "1234567890"
      d = described_class.parse_csv_line(make_row(export_date:'1/13/2014'),1,@imp)
      expect(d.export_date.strftime("%Y-%m-%d")).to eq "2014-01-13"
    end
    it 'should handle short date format' do
      OpenChain::TariffFinder.any_instance.should_receive(:find_by_style).with('123456789-ABCDEF').and_return "1234567890"
      d = described_class.parse_csv_line(make_row(export_date:'1/7/2015 20:46:49'),1,@imp)
      expect(d.export_date.strftime("%Y-%m-%d")).to eq "2015-01-07"
    end
  end
end
