require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UnderArmourStoExportV2Parser do
  describe :parse do
    before :each do
      @imp = Company.where(master:true).first_or_create!(name:'ua')
      Factory(:country,iso_code:'CA')
      @a1_value = '05/01/2015'
      @a2_value = 'REFNUM'
      @a3_value = 'CA' #export country
      @body_rows = [
        ['1235484 - 001 - 3XL','ID',10,'UA StormFront Jacket-BLK//STO'],
        ['1230364 - 100 - XL','KH',72,'The Original 6 BoxerJock-WHT//RED']
      ]
      @prep_xl_client = lambda { |path|
        xlc = double('xlclient')
        OpenChain::XLClient.should_receive(:new).with(path).and_return xlc
        xlc.stub(:get_cell).with(0,0,0).and_return @a1_value
        xlc.stub(:get_cell).with(0,1,0).and_return @a2_value
        xlc.stub(:get_cell).with(0,2,0).and_return @a3_value
        body_yield = xlc.stub(:all_row_values).with(0,3)
        @body_rows.each {|br| body_yield = body_yield.and_yield(br)}
      }
      @base_path = 'a/abc'
    end
    it "should validate that cell A1 is the export date" do
      @a1_value = ''
      @prep_xl_client.call(@base_path)
      expect{described_class.parse(@base_path)}.to raise_error(/export date/)
    end
    it "should validate that cell A2 is a reference number" do
      @a2_value = ''
      @prep_xl_client.call(@base_path)
      expect{described_class.parse(@base_path)}.to raise_error(/reference number/)
    end
    it "should validate that cell A3 is the country of export" do
      @a3_value = ''
      @prep_xl_client.call(@base_path)
      expect{described_class.parse(@base_path)}.to raise_error(/country of origin/)
    end
    it "should validate that cell A3 is the country of export" do
      @a3_value = ''
      @prep_xl_client.call(@base_path)
      expect{described_class.parse(@base_path)}.to raise_error(/country of origin/)
    end
    it "should validate that cell A3 is a valid ISO code" do
      @a3_value = 'ZZ'
      @prep_xl_client.call(@base_path)
      expect{described_class.parse(@base_path)}.to raise_error(/country of origin/)
    end
    it "should validate that remaining lines are 4 cells" do
      @body_rows.first << 'otherdata'
      @prep_xl_client.call(@base_path)
      expect{described_class.parse(@base_path)}.to raise_error(/must be 4 columns/)
    end
    it "should validate that column C is a number" do
      @body_rows.first[2] = 'x'
      @prep_xl_client.call(@base_path)
      expect{described_class.parse(@base_path)}.to raise_error(/must be a number/)
    end
    it "should create records" do
      @prep_xl_client.call(@base_path)
      expect{described_class.parse(@base_path)}.to change(DutyCalcExportFileLine,:count).from(0).to(2)
      d = DutyCalcExportFileLine.first
      expect(d.export_date).to eq  Date.new(2015,5,1)
      expect(d.ship_date).to eq  Date.new(2015,5,1)
      expect(d.carrier).to eq  'FedEx'
      expect(d.ref_1).to eq  @a2_value
      expect(d.ref_2).to eq  "abc - 4"
      expect(d.destination_country).to eq  "CA"
      expect(d.quantity).to eq  10
      expect(d.description).to eq  'UA StormFront Jacket-BLK//STO'
      expect(d.uom).to eq  'EA'
      expect(d.exporter).to eq  'Under Armour'
      expect(d.action_code).to eq  'E'
      expect(d.importer).to eq  @imp
      expect(d.part_number).to eq '1235484-001-3XL+ID'
    end
  end
end
