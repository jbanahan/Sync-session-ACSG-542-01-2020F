require 'spec_helper'

describe CsvMaker do
  it "should strip newline characters" do
    val = "abc\ndef"
    Factory(:product,:unique_identifier=>val)
    ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
    ss.search_columns.create!(:model_field_uid=>'prod_uid')
    r = CsvMaker.new.make_from_search(ss,ss.search)
    arrays = CSV.parse r
    arrays[1][0].should == "abc def"
  end
end
