require 'spec_helper'

describe CsvMaker do
  before :each do 
    Time.zone = 'Etc/UTC'
  end
  context :make_from_search_query do
    before :each do
      @logged_date = 1.minute.ago
      @entry = Factory(:entry,:first_it_date=>1.day.ago,:file_logged_date=>@logged_date)
      @u = Factory(:master_user,:entry_view=>true)
      @search = SearchSetup.create!(:name=>'t',:user=>@u,:module_type=>'Entry')
      @search.search_columns.create!(:model_field_uid=>'ent_first_it_date',:rank=>1)
      @search.search_columns.create!(:model_field_uid=>'ent_file_logged_date',:rank=>2)
      @query = SearchQuery.new @search, @u
      MasterSetup.any_instance.stub(:request_host).and_return "localhost"
    end

    it "should build a csv file from a search query" do
      csv = CSV.parse CsvMaker.new.make_from_search_query(@query)
      csv.length.should eq 2
      csv[0].should eq [ModelField.find_by_uid(:ent_first_it_date).label, ModelField.find_by_uid(:ent_file_logged_date).label]
      csv[1].should eq [@entry.first_it_date.strftime("%Y-%m-%d"), @entry.file_logged_date.strftime("%Y-%m-%d %H:%M")]
    end

    it "should add web links" do
      csv = CSV.parse CsvMaker.new(include_links: true).make_from_search_query(@query)
      csv.length.should eq 2
      csv[0].should eq [ModelField.find_by_uid(:ent_first_it_date).label, ModelField.find_by_uid(:ent_file_logged_date).label, "Links"]
      csv[1].should eq [@entry.first_it_date.strftime("%Y-%m-%d"), @entry.file_logged_date.strftime("%Y-%m-%d %H:%M"), @entry.view_url]
    end

    it "should not include time" do
      csv = CSV.parse CsvMaker.new(no_time: true).make_from_search_query(@query)
      csv.length.should eq 2
      csv[0].should eq [ModelField.find_by_uid(:ent_first_it_date).label, ModelField.find_by_uid(:ent_file_logged_date).label]
      csv[1].should eq [@entry.first_it_date.strftime("%Y-%m-%d"), @entry.file_logged_date.strftime("%Y-%m-%d")]
    end

    it "should strip newline characters" do
      val = "abc\ndef"
      Factory(:product,:unique_identifier=>val)
      ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
      ss.search_columns.create!(:model_field_uid=>'prod_uid')
      r = CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user))
      arrays = CSV.parse r
      arrays[1][0].should == "abc def"
    end
    it "should strip carriage return characters" do
      val = "abc\rdef"
      Factory(:product,:unique_identifier=>val)
      ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
      ss.search_columns.create!(:model_field_uid=>'prod_uid')
      r = CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user))
      arrays = CSV.parse r
      arrays[1][0].should == "abc def"
    end
    it "should strip crlf" do
      val = "abc\r\ndef"
      Factory(:product,:unique_identifier=>val)
      ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
      ss.search_columns.create!(:model_field_uid=>'prod_uid')
      r = CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user))
      arrays = CSV.parse r
      arrays[1][0].should == "abc  def"
    end

    it "should output nil values as blank" do
      @entry.update_attributes first_it_date: nil
      csv = CSV.parse CsvMaker.new.make_from_search_query(@query)
      csv.length.should eq 2
      csv[1].should eq ["", @entry.file_logged_date.strftime("%Y-%m-%d %H:%M")]
    end
  end
end
