require 'spec_helper'

describe SearchCriterion do
  before :each do 
    @product = Factory(:product)
  end
  context "previous _ months" do
    describe :passes? do
      before :each do
        @sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
      end
      it "should find something from the last month with val = 1" do
        @sc.passes?(1.month.ago).should be_true
      end
      it "should not find something from this month" do
        @sc.passes?(1.second.ago).should be_false
      end
      it "should find something from last month with val = 2" do
        @sc.value = 2
        @sc.passes?(1.month.ago).should be_true
      end
      it "should find something from 2 months ago with val = 2" do
        @sc.value = 2
        @sc.passes?(2.months.ago).should be_true
      end
      it "should not find something from 2 months ago with val = 1" do
        @sc.value = 1
        @sc.passes?(2.months.ago).should be_false
      end
      it "should not find a date in the future" do
        @sc.passes?(1.month.from_now).should be_false
      end
      it "should be false for nil" do
        @sc.passes?(nil).should be_false
      end
    end
    describe :apply do
      context :custom_field do
        it "should find something created last month with val = 1" do
          @definition = Factory(:custom_definition,:data_type=>'date')
          @product.update_custom_value! @definition, 1.month.ago
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"pm",:value=>1)
          v = sc.apply(Product.where("1=1"))
          v.all.should include @product
        end
      end
      context :normal_field do
        it "should find something created last month with val = 1" do
          @product.update_attributes(:created_at=>1.month.ago)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
          v = sc.apply(Product.where("1=1"))
          v.all.should include @product
        end
        it "should not find something created in the future" do
          @product.update_attributes(:created_at=>1.month.from_now)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
          v = sc.apply(Product.where("1=1"))
          v.all.should_not include @product
        end
        it "should not find something created this month with val = 1" do
          @product.update_attributes(:created_at=>0.seconds.ago)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
          sc.apply(Product.where("1=1")).all.should_not include @product
        end
        it "should not find something created two months ago with val = 1" do
          @product.update_attributes(:created_at=>2.months.ago)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
          sc.apply(Product.where("1=1")).all.should_not include @product
        end
        it "should find something created last month with val = 2" do
          @product.update_attributes(:created_at=>1.month.ago)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>2)
          sc.apply(Product.where("1=1")).all.should include @product
        end
        it "should find something created two months ago with val 2" do
          @product.update_attributes(:created_at=>2.months.ago)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>2)
          sc.apply(Product.where("1=1")).all.should include @product
        end
      end
    end
  end

  context "string field IN list" do
    it "should find something using a string field from a list of values using unix newlines" do
      sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"in", :value=>"val\n#{@product.unique_identifier}\nval2")
      sc.apply(Product.where("1=1")).all.should include @product
    end
    
    it "should find something using a string field from a list of values using windows newlines" do
      sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"in", :value=>"val\r\n#{@product.unique_identifier}\r\nval2")
      sc.apply(Product.where("1=1")).all.should include @product
    end
    it "should not add blank strings in the IN list when using windows newlines" do
      sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"in", :value=>"val\r\n#{@product.unique_identifier}\r\nval2")
      sc.apply(Product.where("1=1")).to_sql.should match /\('val',\s?'#{@product.unique_identifier}',\s?'val2'\)/
    end
    it "should find something using a numeric field from a list of values" do
      sc = SearchCriterion.new(:model_field_uid=>:prod_class_count, :operator=>"in", :value=>"1\n0\r\n3")
      sc.apply(Product.where("1=1")).all.should include @product        
    end
  end
  
  context 'date time field' do
    it "should translate datetime values to UTC for lt operator" do
      # Run these as central timezone
      tz = "Hawaii"
      date = "2013-01-01"
      value = date + " " + tz
      expected_value = Time.use_zone(tz) do
        Time.zone.parse(date).utc.to_formatted_s(:db)
      end

      sc = SearchCriterion.new(:model_field_uid=>:prod_created_at, :operator=>"lt", :value=>value)
      sc.apply(Product.where("1=1")).to_sql.should =~ /#{expected_value}/
    end
      
    it "should translate datetime values to UTC for gt operator" do
      # Make sure we're also allowing actual time values as well
      tz = "Hawaii"
      date = "2012-01-01 07:08:09" 
      value = date + " " + tz
      expected_value = Time.use_zone(tz) do
        Time.zone.parse(date).utc.to_formatted_s(:db)
      end
      sc = SearchCriterion.new(:model_field_uid=>:prod_created_at, :operator=>"gt", :value=>value)
      sql = sc.apply(Product.where("1=1")).to_sql
      sql.should =~ /#{expected_value}/ 
    end
      
    it "should translate datetime values to UTC for eq operator" do
      # Make sure that if the timezone is not in the value, that we add eastern timezone to it
      value = "2012-01-01"
      sc = SearchCriterion.new(:model_field_uid=>:prod_created_at, :operator=>"eq", :value=>value)
      expected_value = Time.use_zone("Eastern Time (US & Canada)") do
        Time.zone.parse(value + " 00:00:00").utc.to_formatted_s(:db)
      end

      sc.apply(Product.where("1=1")).to_sql.should =~ /#{expected_value}/ 
      
      #verify the nq operator is translated too
      sc.operator = "nq"
      sc.apply(Product.where("1=1")).to_sql.should =~ /#{expected_value}/ 
    end

    it "should not translate date values to UTC for lt, gt, or eq operators" do
      value = "2012-01-01"
      # There's no actual date field in product, we'll use Entry.duty_due_date instead
      sc = SearchCriterion.new(:model_field_uid=>:ent_duty_due_date, :operator=>"eq", :value=>value)
      sc.apply(Entry.where("1=1")).to_sql.should =~ /#{value}/

      sc.operator = "lt"
      sc.apply(Entry.where("1=1")).to_sql.should =~ /#{value}/

      sc.operator = "gt"
      sc.apply(Entry.where("1=1")).to_sql.should =~ /#{value}/
    end

    it "should not translate datetime values to UTC for any operator other than lt, gt, eq, or nq" do
      sc = SearchCriterion.new(:model_field_uid=>:prod_created_at, :operator=>"bda", :value=>10)
      sc.apply(Entry.where("1=1")).to_sql.should =~ /10/
      
      sc.operator = "ada"
      sc.apply(Entry.where("1=1")).to_sql.should =~ /10/
      
      sc.operator = "bdf"
      sc.apply(Entry.where("1=1")).to_sql.should =~ /10/

      sc.operator = "adf"
      sc.apply(Entry.where("1=1")).to_sql.should =~ /10/

      sc.operator = "pm"
      sc.apply(Entry.where("1=1")).to_sql.should =~ /10/

      sc.operator = "null"
      sc.apply(Entry.where("1=1")).to_sql.should =~ /NULL/

      sc.operator = "notnull"
      sc.apply(Entry.where("1=1")).to_sql.should =~ /NOT NULL/


      
    end
  end

  context 'boolean custom field' do
    before :each do
      @definition = Factory(:custom_definition,:data_type=>'boolean')
      @custom_value = @product.get_custom_value @definition
    end
    context 'Is Empty' do
      before :each do
        @search_criterion = SearchCriterion.create!(
          :model_field_uid=>"*cf_#{@definition.id}",
          :operator => "null",
          :value => ''
        )
      end
      it 'should return for Is Empty and false' do
        @custom_value.value = false
        @custom_value.save!
        @search_criterion.apply(Product).should include @product 
        @search_criterion.passes?(@custom_value.value).should == true
      end
      it 'should return for Is Empty and nil' do
        @custom_value.value = nil
        @custom_value.save!
        @search_criterion.apply(Product).should include @product 
        @search_criterion.passes?(@custom_value.value).should == true
      end

      it 'should not return for Is Empty and true' do
        @custom_value.value = true
        @custom_value.save!
        @search_criterion.apply(Product).should_not include @product 
        @search_criterion.passes?(@custom_value.value).should == false
      end

    end
    context 'Is Not Empty' do
      before :each do
        @search_criterion = SearchCriterion.create!(
          :model_field_uid=>"*cf_#{@definition.id}",
          :operator => "notnull",
          :value => ''
        )
      end
      it 'should return for Is Not Empty and true' do
        @custom_value.value = true
        @custom_value.save!
        @search_criterion.apply(Product).should include @product 
        @search_criterion.passes?(@custom_value.value).should == true
      end

      it 'should not return for Is Not Empty and false' do
        @custom_value.value = false
        @custom_value.save!
        @search_criterion.apply(Product).should_not include @product 
        @search_criterion.passes?(@custom_value.value).should == false
      end

      it 'should not return for Is Not Empty and nil' do
        @custom_value.value = nil
        @custom_value.save!
        @search_criterion.apply(Product).should_not include @product 
        @search_criterion.passes?(@custom_value.value).should == false
      end

    end
  end
end
