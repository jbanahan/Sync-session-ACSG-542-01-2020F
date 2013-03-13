require 'spec_helper'

describe SearchQuery do
  before :each do
    Product.stub(:search_where).and_return("1=1")
    @ss = SearchSetup.new(:module_type=>"Product")
    @ss.search_columns.build(:model_field_uid=>'prod_uid',:rank=>0)
    @ss.search_columns.build(:model_field_uid=>'prod_name',:rank=>1)
    @ss.sort_criterions.build(:model_field_uid=>'prod_name',:rank=>0)
    @ss.search_criterions.build(:model_field_uid=>'prod_name',:operator=>'in',:value=>"A\nB")
    @sq = SearchQuery.new @ss, User.new
    @p1 = Factory(:product,:name=>'B')
    @p2 = Factory(:product,:name=>'A')
    @p3 = Factory(:product,:name=>'C')
  end
  describe :execute do
    it "should return array of arrays" do
      r = @sq.execute
      r.should have(2).results
      r[0][:row_key].should == @p2.id
      r[0][:result][0].should == @p2.unique_identifier
      r[0][:result][1].should == @p2.name
      r[1][:row_key].should == @p1.id
      r[1][:result][0].should == @p1.unique_identifier
      r[1][:result][1].should == @p1.name
    end
    it "should yield with loop of arrays and return nil" do
      r = []
      @sq.execute {|row_hash| r << row_hash}.should be_nil
      r[0][:row_key].should == @p2.id
      r[0][:result][0].should == @p2.unique_identifier
      r[0][:result][1].should == @p2.name
      r[1][:row_key].should == @p1.id
      r[1][:result][0].should == @p1.unique_identifier
      r[1][:result][1].should == @p1.name
    end
    it "should process values via ModelField#process_query_result" do
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p1))
      @ss.search_columns.build(:model_field_uid=>'hts_hts_1',:rank=>2)
      r = @sq.execute
      r[1][:result][2].should == "1234.56.7890"
    end
    it "should handle multi-level queries" do
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p1))
      @ss.search_columns.build(:model_field_uid=>'hts_hts_1',:rank=>2)
      r = @sq.execute
      r[1][:result][2].should == "1234.56.7890"
    end
    it "should secure query" do
      Product.should_receive(:search_where).and_return("products.name = 'B'")
      r = @sq.execute
      r.size.should == 1
      r[0][:row_key].should == @p1.id
    end
    context :custom_values do
      before :each do
        @cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>:string)
      end
      it "should support columns"
      it "should support criterions" do
        @ss.search_criterion.build(:model_field_uid=>"*cf_#{@cd.id}",:operator=>"eq",:value=>"MYVAL")
      end
      it "should support sorts"
    end
    context :pagination do
      it "should paginate" do
        crit = @ss.search_criterions.first
        crit.operator = "sw"
        crit.value = "D"
        10.times do |i|
          Factory(:product,:name=>"D#{i}")
        end
        r = @sq.execute :per_page=>2, :page=>2
        r.size.should == 2
        r[0][:result][1].should == "D2"
        r[1][:result][1].should == "D3"
      end
    end
  end

  describe :count do
    it "should return row count for multi level query" do
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p1))
      @ss.search_columns.build(:model_field_uid=>'hts_hts_1',:rank=>2)
      @sq.count.should == 2
    end
  end
end
