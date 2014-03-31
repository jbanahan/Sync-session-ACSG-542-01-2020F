require 'spec_helper'

describe DrawbackImportLine do
  describe "unallocated" do
    it "should return if no allocations" do
      d = Factory(:drawback_import_line,quantity:10)
      expect(DrawbackImportLine.unallocated.to_a).to eql([d])
    end
    it "should return if unallocated quantity" do
      d = Factory(:drawback_import_line,quantity:10)
      d.drawback_allocations.create!(quantity:9)
      expect(DrawbackImportLine.unallocated.to_a).to eql([d])
    end
    it "should not return if fully allocated" do
      d = Factory(:drawback_import_line,quantity:10)
      d.drawback_allocations.create!(quantity:10)
      expect(DrawbackImportLine.unallocated.to_a).to be_empty
    end
  end
  describe "unallocated_quantity" do
    it "should return difference between quantities and allocations" do
      d = Factory(:drawback_import_line,quantity:10)
      d.drawback_allocations.create!(quantity:9)
      expect(d.unallocated_quantity).to eql(1)
    end
  end
  describe "not_in_duty_calc_file" do
    it "should find line not linked" do
      d1 = Factory(:drawback_import_line) 
      d2 = Factory(:drawback_import_line) 
      dcl = DutyCalcImportFileLine.create!(:drawback_import_line_id=>d2.id)

      DrawbackImportLine.not_in_duty_calc_file.all.should == [d1]
    end
  end
  describe "duty_calc_line" do
    it "should generate line" do
      d = DrawbackImportLine.create!(
        :product=>Factory(:product,:unique_identifier=>"123456"),
        :entry_number=>'12345678901',
        :quantity=>BigDecimal("10.04"),
        :part_number=>"123456",
        :hts_code=>"1234567890",
        :import_date=>Date.new(2010,4,1),
        :received_date=>Date.new(2010,4,2),
        :port_code=>"4601",
        :box_37_duty=>BigDecimal("100.10"),
        :box_40_duty=>BigDecimal("101.10"),
        :total_invoice_value=>BigDecimal("5000.01"),
        :total_mpf=>BigDecimal("485.00"),
        :country_of_origin_code=>"CN",
        :description=>"MERCH DESC",
        :unit_of_measure=>"EA",
        :unit_price=>BigDecimal("2.045"),
        :rate=>BigDecimal("0.03"),
        :duty_per_unit=>BigDecimal(".153"),
        :compute_code=>"7",
        :ocean=>true
      )
      line = d.duty_calc_line
      csv = CSV.parse(line).first
      [d.entry_number,"04/01/2010","04/02/2010","","4601","100.10","101.10","","5000.01","485.00","1","",d.id.to_s,"","",d.country_of_origin_code,"","",
      d.part_number,d.part_number,d.hts_code,d.description,d.unit_of_measure,"","10.040000000","10.040000000","","2.0450000","","","","0.030000000","","","","0.153000000","7","","Y"].each_with_index do |v,i|
        csv[i].should == v
      end
    end
  end
end
