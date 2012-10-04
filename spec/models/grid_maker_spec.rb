require 'spec_helper' 

describe GridMaker do
  context "max_details" do
    before :each do 
      @u = Factory(:master_user)
    end
    it "should truncate entry lines at 3" do
      ci = Factory(:commercial_invoice)
      5.times do |i|
        ci.commercial_invoice_lines.create!(:line_number=>i,:part_number=>"p#{i}",:quantity=>i)
      end
      objs = []
      GridMaker.new([Entry.first],[SearchColumn.new(:model_field_uid=>:cil_part_number)],[],CoreModule::ENTRY.default_module_chain,@u,3).go do |row,obj|
        objs << obj
      end
      objs.size.should == 3
    end
    it "should process all parent objects when truncation is turned on" do
      2.times do |x|
        ci = Factory(:commercial_invoice)
        5.times do |i|
          ci.commercial_invoice_lines.create!(:line_number=>i,:part_number=>"p#{i}",:quantity=>i)
        end
      end
      objs = []
      GridMaker.new(Entry.all,[SearchColumn.new(:model_field_uid=>:cil_part_number)],[],CoreModule::ENTRY.default_module_chain,@u,3).go do |row,obj|
        objs << obj
      end
      objs.size.should == 6
    end
  end
end
