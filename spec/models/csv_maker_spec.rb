require 'spec_helper'

describe CsvMaker do
  context "Dates" do
    before :each do
      @logged_date = 1.minute.ago
      @entry = Factory(:entry,:first_it_date=>1.day.ago,:file_logged_date=>@logged_date)
      @u = Factory(:master_user,:entry_view=>true)
      @search = SearchSetup.create!(:name=>'t',:user=>@u,:module_type=>'Entry')
      @search.search_columns.create!(:model_field_uid=>'ent_first_it_date',:rank=>1)
      @search.search_columns.create!(:model_field_uid=>'ent_file_logged_date',:rank=>2)
      @r = CSV.parse CsvMaker.new.make_from_search(@search,@search.search)
    end
    it "should format date" do
      @r[1][0].should == 1.day.ago.strftime("%Y-%m-%d")
    end
    it "should format datetime" do
      @r[1][1].should == @logged_date.strftime("%Y-%m-%d %H:%M")
    end
    it "should format datetime as date if no_time option set" do
      @r = CSV.parse CsvMaker.new(:no_time=>true).make_from_search(@search,@search.search)
      @r[1][1].should == @logged_date.strftime("%Y-%m-%d")
    end
  end
  it "should strip newline characters" do
    val = "abc\ndef"
    Factory(:product,:unique_identifier=>val)
    ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
    ss.search_columns.create!(:model_field_uid=>'prod_uid')
    r = CsvMaker.new.make_from_search(ss,ss.search)
    arrays = CSV.parse r
    arrays[1][0].should == "abc def"
  end
  it "should strip carriage return characters" do
    val = "abc\rdef"
    Factory(:product,:unique_identifier=>val)
    ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
    ss.search_columns.create!(:model_field_uid=>'prod_uid')
    r = CsvMaker.new.make_from_search(ss,ss.search)
    arrays = CSV.parse r
    arrays[1][0].should == "abc def"
  end
  it "should strip crlf" do
    val = "abc\r\ndef"
    Factory(:product,:unique_identifier=>val)
    ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
    ss.search_columns.create!(:model_field_uid=>'prod_uid')
    r = CsvMaker.new.make_from_search(ss,ss.search)
    arrays = CSV.parse r
    arrays[1][0].should == "abc  def"
  end
end
