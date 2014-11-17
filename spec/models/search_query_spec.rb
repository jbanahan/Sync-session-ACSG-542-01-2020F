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
      r = @sq.execute(per_page: 1000)
      r.should have(2).results
      r[0][:row_key].should == @p2.id
      r[0][:result][0].should == @p2.unique_identifier
      r[0][:result][1].should == @p2.name
      r[1][:row_key].should == @p1.id
      r[1][:result][0].should == @p1.unique_identifier
      r[1][:result][1].should == @p1.name
    end
    it "should add extra_where clause" do
      @sq = SearchQuery.new @ss, User.new, :extra_where=>"products.id = #{@p1.id}"
      r = @sq.execute
      r.should have(1).result
      r[0][:row_key].should == @p1.id
    end
    it "should yield with loop of arrays and return nil" do
      r = []
      @sq.execute(per_page: 1000) {|row_hash| r << row_hash}.should be_nil
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
      r = @sq.execute per_page: 1000
      r[1][:result][2].should == "1234.56.7890"
    end
    it "should handle multi-level queries" do
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p1))
      @ss.search_columns.build(:model_field_uid=>'hts_hts_1',:rank=>2)
      r = @sq.execute per_page: 1000
      r[1][:result][2].should == "1234.56.7890"
    end
    it "should prevent DISTINCT from combining child level values in a multi-level query" do
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p1))
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p1))

      @ss.search_columns.build(:model_field_uid=>'hts_hts_1',:rank=>2)
      r = @sq.execute per_page: 1000
      r[1][:result][2].should == "1234.56.7890"
      r[1][:row_key].should == r[2][:row_key]
      r[2][:result][2].should == "1234.56.7890"
    end
    it "should combine child level values in a multi-level query if no child level column is selected" do
      @ss.search_criterions.first.value = "#{@p1.name}"
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p1))
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p1))
      r = @sq.execute per_page: 1000
      r.size.should == 1
      r[0][:result][1].should == @p1.name
      r[0][:row_key].should == @p1.id
    end
    it "should show a blank value for null child values when a column is selected for it by the user" do
      @ss.search_columns.build(:model_field_uid=>'class_cntry_iso',:rank=>2)
      @ss.search_criterions.first.value = "#{@p1.name}"
      r = @sq.execute per_page: 1000
      r.size.should == 1
      r[0][:row_key].should == @p1.id
      r[0][:result][2].should == ""
    end
    it "should handle _blank columns" do
      @ss.search_columns.build(:model_field_uid=>'_blank',:rank=>2)
      r = @sq.execute
      r[1][:result][2].should == ""
    end
    it "should secure query" do
      Product.stub(:search_where).and_return("products.name = 'B'")
      r = @sq.execute per_page: 1000
      r.size.should == 1
      r[0][:row_key].should == @p1.id
    end
    it "should sort at multiple levels" do
      # When multi level sorting, if the parent level doesn't have a sort
      # use the id column to ensure that lines are always grouped together
      # by their parent level

      @ss.sort_criterions.first.model_field_uid='hts_hts_1'
      @ss.sort_criterions.build(:model_field_uid=>'class_cntry_iso',:rank=>2)
      @ss.search_columns.build(:model_field_uid=>'class_cntry_iso',:rank=>2)
      @ss.search_columns.build(:model_field_uid=>'hts_hts_1',:rank=>3)

      country_ax = Factory(:country,:iso_code=>'AX')
      country_bx = Factory(:country,:iso_code=>'BX')
      #building these in a jumbled order so the test can properly sort them
      @tr2_a_3 = Factory(:tariff_record,:hts_1=>'311111111',:classification=>Factory(:classification,:country=>country_ax,:product=>@p2))
      @tr1_b_9 = Factory(:tariff_record,:hts_1=>'911111111',:classification=>Factory(:classification,:country=>country_bx,:product=>@p1))
      @tr1_b_5 = Factory(:tariff_record,:hts_1=>'511111111',:classification=>@tr1_b_9.classification,:line_number=>2)
      @tr1_a_9 = Factory(:tariff_record,:hts_1=>'911111111',:classification=>Factory(:classification,:country=>country_ax,:product=>@p1))
      @tr1_a_5 = Factory(:tariff_record,:hts_1=>'511111111',:classification=>@tr1_a_9.classification,:line_number=>2)
      @tr2_a_1 = Factory(:tariff_record,:hts_1=>'111111111',:classification=>@tr2_a_3.classification,:line_number=>2)

      r = @sq.execute per_page: 1000
      r.size.should == 6
      4.times { |i| r[i][:row_key].should == @p1.id }
      (4..5).each { |i| r[i][:row_key].should == @p2.id }
      (0..1).each { |i| r[i][:result][2].should == 'AX' }
      (2..3).each { |i| r[i][:result][2].should == 'BX' }
      (4..5).each { |i| r[i][:result][2].should == 'AX' }
      r[0][:result][3].should start_with '5'
      r[1][:result][3].should start_with '9'
      r[2][:result][3].should start_with '5'
      r[3][:result][3].should start_with '9'
      r[4][:result][3].should start_with '1'
      r[5][:result][3].should start_with '3'
    end

    it "should not bomb on IN lists with blank values" do
      @p3.update_attributes :name => ""
      @ss.search_criterions[0].value = ""
      r = @sq.execute per_page: 1000
      r.should have(1).results

      r[0][:row_key].should == @p3.id
    end

    it "should handle relative fields referencing different core modules" do
      # Make sure that the search criterion's value is the only thing referencing a different module level so 
      # that we're sure that we're testing the code that handles collecting this field's core module
      classfication = Factory(:classification,:product=>@p1)
      classfication.update_attributes :updated_at => 1.day.from_now
      @ss.search_criterions.clear
      @ss.search_criterions.build(:model_field_uid=>'prod_created_at', :operator=>'bfld', :value=>"class_updated_at")
      r = @sq.execute per_page: 1000
      r[0][:result][0].should == @p1.unique_identifier
    end

    it "adds an inner join optimization when pagination options exist" do
      expect(@sq.to_sql(per_page: 100)).to include "AS inner_opt ON "
    end

    it "defaults to using the max_results from search_setup as the query LIMIT" do
      expect(@sq.to_sql).to include "LIMIT #{@sq.search_setup.max_results}"
    end

    it "handles search_columns that have been removed/disabled" do
      # We can simulate a disabled column by just using a bogus model field uid
      @ss.search_columns.build(:model_field_uid=>'prod_not_a_field',:rank=>2)

      r = @sq.execute(per_page: 1000)
      expect(r.size).to eq 2
      expect(r[0][:result][2]).to eq ""
    end

    it "handles search_criterions that have been removed/disabled" do
      # We can simulate a disabled column by just using a bogus model field uid
      @ss.search_criterions.build(:model_field_uid=>'prod_not_a_field',:operator=>'in',:value=>"A\nB")

      r = @sq.execute(per_page: 1000)
      expect(r.size).to eq 0
    end

    it "handles sorts that have been removed/disabled" do
      @ss.sort_criterions.build(:model_field_uid=>'prod_not_a_field',:rank=>0)
      r = @sq.execute(per_page: 1000)
      expect(r.size).to eq 2
    end
    
    context :custom_values do
      before :each do
        @cd = Factory(:custom_definition,:module_type=>"Product",:data_type=>:string)
        @p1.update_custom_value! @cd, "MYVAL"
      end
      it "should support columns" do
        @ss.search_columns.build(:model_field_uid=>"*cf_#{@cd.id}",:rank=>2)
        r = @sq.execute
        r[0][:result][2].should == ""
        r[1][:result][2].should == "MYVAL"
      end
      it "should support criterions" do
        @ss.search_criterions.build(:model_field_uid=>"*cf_#{@cd.id}",:operator=>"eq",:value=>"MYVAL")
        r = @sq.execute
        r.size.should == 1
        r[0][:row_key].should == @p1.id
      end
      it "should support sorts" do
        @p2.update_custom_value! @cd, "AVAL"
        @ss.sort_criterions.first.model_field_uid = "*cf_#{@cd.id}"
        r = @sq.execute
        r.size.should == 2
        r[0][:row_key].should == @p2.id
        r[1][:row_key].should == @p1.id
      end
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

      it "should paginate child items across multiple pages" do
        @ss.search_columns.build(:model_field_uid=>'class_cntry_iso',:rank=>2)
        @ss.sort_criterions.build(:model_field_uid=>'class_cntry_iso',:rank=>1)

        crit = @ss.search_criterions.first
        crit.operator = "eq"
        crit.value = @p1.name

        6.times do |i|
          @p1.classifications.create! country: Factory(:country)
        end

        c = @p1.classifications.joins(:country).order("countries.iso_code ASC")

        r = @sq.execute :per_page=>2, :page=>2
        r.size.should == 2
        r[0][:row_key].should == @p1.id
        r[0][:result][2].should == c[2].country.iso_code
        r[1][:row_key].should == @p1.id
        r[1][:result][2].should == c[3].country.iso_code

        r = @sq.execute :per_page=>2, :page=>3
        r.size.should == 2
        r[0][:row_key].should == @p1.id
        r[0][:result][2].should == c[4].country.iso_code
        r[1][:row_key].should == @p1.id
        r[1][:result][2].should == c[5].country.iso_code
      end
    end
  end

  describe :count do
    it "should return row count for multi level query" do
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p1))
      @ss.search_columns.build(:model_field_uid=>'hts_hts_1',:rank=>2)
      @sq.count.should == 2
    end
    it "should handle multiple blanks" do
      @ss.search_columns.build(:model_field_uid=>'_blank',:rank=>10)
      @ss.search_columns.build(:model_field_uid=>'_blank',:rank=>11)
      @sq.count.should == 2
    end
  end
  describe :result_keys do
    it "should return unique key list for multi level query" do
      tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p1))
      tr2 = Factory(:tariff_record,:hts_1=>'9876543210',:line_number=>2,:classification=>tr.classification)
      @ss.search_columns.build(:model_field_uid=>'hts_hts_1',:rank=>2)
      keys = @sq.result_keys
      keys.should == [@p2.id,@p1.id]
    end
  end
  describe :unique_parent_count do
    it "should return parent count when there are details" do
      @ss.search_columns.build(:model_field_uid=>'class_cntry_iso',:rank=>2)
      2.times {|i| Factory(:classification,:product=>@p1)}
      @sq.count.should == 3 #confirming we're setup properly
      @sq.unique_parent_count.should == 2 #the real test
    end
  end
end
