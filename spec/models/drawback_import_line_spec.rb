require 'spec_helper'

describe DrawbackImportLine do
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
      line[0,11].should == d.entry_number
      line[11,10].should == "04/01/2010"
      line[21,10].should == "04/02/2010"
      line[31,10].should == "00/00/0000"
      line[41,4].should == "4601"
      line[45,11].should == "00000100.10"
      line[56,11].should == "00000101.10"
      line[67,10].should == "00/00/0000"
      line[77,11].should == "00005000.01"
      line[88,11].should == "00000485.00"
      line[99,9].should == "01.000000"
      line[108,5].should == "     "
      line[113,30].should == d.id.to_s.rjust(30)
      line[143,60].should == "".ljust(60)
      line[203,2].should == "CN"
      line[205,2].should == "  "
      line[207,11].should == "".ljust(11)
      line[218,30].should == "123456".ljust(30)
      line[248,30].should == "123456".ljust(30)
      line[278,10].should == "1234567890"
      line[288,30].should == "MERCH DESC".ljust(30)
      line[318,3].should == "EA "
      line[321,9].should == "01.000000"
      line[330,19].should == "000000010.040000000"
      line[349,19].should == "000000010.040000000"
      line[368,19].should == "".ljust(19)
      line[387,17].should == "000000002.0450000"
      line[404,51].should == "".ljust(51)
      line[455,13].should == "0000.03000000"
      line[468,39].should == "".ljust(39)
      line[507,17].should == "0000000.153000000"
      line[524].should == "7"
      line[525].should == " "
      line[526].should == "Y"
    end
  end
end
