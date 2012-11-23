require 'spec_helper'

describe DutyCalcExportFileLine do
  describe :not_in_imports do
    before :each do
      @imp = Factory(:company)
      p = Factory(:product,:unique_identifier=>"ABC")
      @exp = DutyCalcExportFileLine.create!(:importer_id=>@imp.id,:part_number=>'ABC',:export_date=>1.month.ago)
      @imp_line = DrawbackImportLine.create!(:importer_id=>@imp.id,:part_number=>@exp.part_number,:import_date=>1.year.ago,:product_id=>p.id)
    end
    it "should eliminate lines with imports by part number where import is before export and same importer" do
      DutyCalcExportFileLine.not_in_imports.should be_empty
    end
    it "should not eliminate lines from different importer" do
      @imp_line.update_attributes(:importer_id=>Factory(:company).id)
      DutyCalcExportFileLine.not_in_imports.first.should == @exp
    end
    it "should not eliminate lines where import is before export" do
      @imp_line.update_attributes(:import_date=>1.day.from_now)
      DutyCalcExportFileLine.not_in_imports.first.should == @exp
    end
    it "should not eliminate lines where part number not in imports" do
      @imp_line.update_attributes(:part_number=>'SOMETHINGELSE')
      DutyCalcExportFileLine.not_in_imports.first.should == @exp
    end
  end
  describe :make_line_array do
    it "should make array" do
      line = DutyCalcExportFileLine.new(:export_date=>1.day.ago,:ship_date=>2.days.ago,
        :part_number => "123", :carrier=>"APLL", :ref_1=>"R1", :ref_2=>"R2",
        :ref_3=>"R3", :ref_4=>"R4", :destination_country=>"CA", :quantity=>1.2,
        :schedule_b_code=>"1234456789", :hts_code=>"4949494949", :description=>"DESC",
        :uom=>"EA",:exporter=>"UA",:action_code=>"E", :nafta_duty=>1, 
        :nafta_us_equiv_duty=>1.1, :nafta_duty_rate=>0.1
      )
      a = line.make_line_array
      [:export_date,:ship_date,:part_number,:carrier,:ref_1,:ref_2,:ref_3,
      :ref_4,:destination_country,:quantity,:schedule_b_code,:description,
      :uom,:exporter,:status,:action_code,:nafta_duty,:nafta_us_equiv_duty,:nafta_duty_rate
      ].each_with_index do |v,i|
        a[i].should == (line[v].respond_to?(:strftime) ? line[v].strftime("%m/%d/%Y") : line[v].to_s)
      end
    end
    it "should fill in hts code if schedule b is missing" do
      line = DutyCalcExportFileLine.new(:export_date=>1.day.ago,:ship_date=>2.days.ago,
        :part_number => "123", :carrier=>"APLL", :ref_1=>"R1", :ref_2=>"R2",
        :ref_3=>"R3", :ref_4=>"R4", :destination_country=>"CA", :quantity=>1.2,
        :schedule_b_code=>"", :hts_code=>"4949494949", :description=>"DESC",
        :uom=>"EA",:exporter=>"UA",:action_code=>"E", :nafta_duty=>1, 
        :nafta_us_equiv_duty=>1.1, :nafta_duty_rate=>0.1
      )
      a = line.make_line_array
      a[10].should == "4949494949"
    end
  end
end
