require 'spec_helper'

describe XlsMaker do
  context "date handling" do
    before :each do
      @entry = Factory(:entry,:first_it_date=>1.day.ago,:file_logged_date=>1.minute.ago)
      @u = Factory(:master_user,:entry_view=>true)
      @search = SearchSetup.create!(:name=>'t',:user=>@u,:module_type=>'Entry')
      @search.search_columns.create!(:model_field_uid=>'ent_first_it_date',:rank=>1)
      @search.search_columns.create!(:model_field_uid=>'ent_file_logged_date',:rank=>2)
      @wb = XlsMaker.new.make_from_search(@search,@search.search)
    end
    it "should format dates with DATE_FORMAT" do
      @wb.worksheet(0).row(1).format(0).should == XlsMaker::DATE_FORMAT
    end
    it "should format date_time with DATE_TIME_FORMAT" do
      @wb.worksheet(0).row(1).format(1).should == XlsMaker::DATE_TIME_FORMAT 
    end
    it "should format date_time with DATE_FORMAT if no_time option is set" do
      @wb = XlsMaker.new(:no_time=>true).make_from_search(@search,@search.search)
      @wb.worksheet(0).row(1).format(1).should == XlsMaker::DATE_FORMAT
    end
  end
end

