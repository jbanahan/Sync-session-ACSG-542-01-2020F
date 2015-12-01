require 'spec_helper'

describe CsvMaker do
  context :make_from_search_query do
    before :each do
      @logged_date = DateTime.civil_from_format(:utc,2014,7,15,12,26,22)
      @entry = Factory(:entry,:first_it_date=>Date.new(2014,7,30),:file_logged_date=>@logged_date, :broker_reference => "x")
      @entry.reload #get right rails date objects
      @u = Factory(:master_user,:entry_view=>true, :time_zone=>"Hawaii")
      @search = SearchSetup.create!(:name=>'t',:user=>@u,:module_type=>'Entry')
      @search.search_columns.create!(:model_field_uid=>'ent_first_it_date',:rank=>1)
      @search.search_columns.create!(:model_field_uid=>'ent_file_logged_date',:rank=>2)
      @search.search_criterions.create! model_field_uid: 'ent_brok_ref', operator: "eq", value: "x"
      @query = SearchQuery.new @search, @u
      MasterSetup.any_instance.stub(:request_host).and_return "localhost"
    end

    it "should build a csv file from a search query" do
      raw_csv, data_row_count = CsvMaker.new.make_from_search_query(@query)
      csv = CSV.parse raw_csv
      data_row_count.should eq 1
      csv.length.should eq 2
      csv[0].should eq [ModelField.find_by_uid(:ent_first_it_date).label, ModelField.find_by_uid(:ent_file_logged_date).label]
      csv[1].should eq [@entry.first_it_date.strftime("%Y-%m-%d"), @entry.file_logged_date.in_time_zone("Hawaii").strftime("%Y-%m-%d %H:%M")]
    end

    it "should count 0 rows when csv is empty" do
      @entry.destroy
      *, data_row_count = CsvMaker.new.make_from_search_query(@query)
      data_row_count.should eq 0
    end

    it "should add web links" do
      csv = CSV.parse CsvMaker.new(include_links: true).make_from_search_query(@query).first
      csv.length.should eq 2
      csv[0].should eq [ModelField.find_by_uid(:ent_first_it_date).label, ModelField.find_by_uid(:ent_file_logged_date).label, "Links"]
      csv[1].should eq [@entry.first_it_date.strftime("%Y-%m-%d"), @entry.file_logged_date.in_time_zone("Hawaii").strftime("%Y-%m-%d %H:%M"), @entry.view_url]
    end

    it "should not include time" do
      csv = CSV.parse CsvMaker.new(no_time: true).make_from_search_query(@query).first
      csv.length.should eq 2
      csv[0].should eq [ModelField.find_by_uid(:ent_first_it_date).label, ModelField.find_by_uid(:ent_file_logged_date).label]
      csv[1].should eq [@entry.first_it_date.strftime("%Y-%m-%d"), @entry.file_logged_date.in_time_zone("Hawaii").strftime("%Y-%m-%d")]
    end

    it "should strip newline characters" do
      val = "abc\ndef"
      Factory(:product,:unique_identifier=>val)
      ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
      ss.search_criterions.create! model_field_uid: "prod_uid", operator: "notnull"
      ss.search_columns.create!(:model_field_uid=>'prod_uid')
      r = CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user)).first
      arrays = CSV.parse r
      arrays[1][0].should == "abc def"
    end
    it "should strip carriage return characters" do
      val = "abc\rdef"
      Factory(:product,:unique_identifier=>val)
      ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
      ss.search_criterions.create! model_field_uid: "prod_uid", operator: "notnull"
      ss.search_columns.create!(:model_field_uid=>'prod_uid')
      r = CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user)).first
      arrays = CSV.parse r
      arrays[1][0].should == "abc def"
    end
    it "should strip crlf" do
      val = "abc\r\ndef"
      Factory(:product,:unique_identifier=>val)
      ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
      ss.search_criterions.create! model_field_uid: "prod_uid", operator: "notnull"
      ss.search_columns.create!(:model_field_uid=>'prod_uid')
      r = CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user)).first
      arrays = CSV.parse r
      arrays[1][0].should == "abc  def"
    end

    it "should output nil values as blank" do
      @entry.update_attributes first_it_date: nil
      csv = CSV.parse CsvMaker.new.make_from_search_query(@query).first
      csv.length.should eq 2
      csv[1].should eq ["", @entry.file_logged_date.in_time_zone("Hawaii").strftime("%Y-%m-%d %H:%M")]
    end

    it "raises an error if the report is not downloadable" do
      ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
      ss.should_receive(:downloadable?) {|e| e << "Error!"; false}

      expect {CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user))}.to raise_error "Error!"
    end

    it "raises an error if the report exceeds maximum row size" do
      Factory(:product)
      ss = Factory(:search_setup,:module_type=>"Product",:user=>Factory(:master_user))
      ss.search_criterions.create! model_field_uid: "prod_uid", operator: "notnull"
      ss.search_columns.create!(:model_field_uid=>'prod_uid')
      
      ss.stub(:max_results).and_return 0
      expect {CsvMaker.new.make_from_search_query(SearchQuery.new(ss, ss.user))}.to raise_error "Your report has over 0 rows.  Please adjust your parameter settings to limit the size of the report."
    end
  end
end
