require 'spec_helper'

describe DutyCalcExportFileLine do
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
      :ref_4,:destination_country,:quantity,:schedule_b_code,:hts_code,:description,
      :uom,:exporter,:status,:action_code,:nafta_duty,:nafta_us_equiv_duty,:nafta_duty_rate
      ].each_with_index do |v,i|
        a[i].should == (line[v].respond_to?(:strftime) ? line[v].strftime("%m/%d/%Y") : line[v].to_s)
      end
    end
  end
end
