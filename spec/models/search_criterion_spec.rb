require 'spec_helper'

describe SearchCriterion do
  before :each do 
    @product = Factory(:product)
  end
  context "after (field)" do
    before :each do
      @u = Factory(:master_user)
      @ss = SearchSetup.new(module_type:'Entry',user:@u)
      @sc = @ss.search_criterions.new(model_field_uid:'ent_release_date',operator:'afld',value:'ent_arrival_date')
    end
    it "should pass if field is after other field's value" do
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>1.days.ago)
      @sc.test?(ent).should be_true
      ents = @sc.apply(Entry.scoped).all
      ents.first.should == ent
    end
    it "should fail if field is same as other field's value" do
      ent = Factory(:entry,:arrival_date=>1.day.ago,:release_date=>1.days.ago)
      @sc.test?(ent).should be_false
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should fail if field is before other field's value" do
      ent = Factory(:entry,:arrival_date=>1.day.ago,:release_date=>2.days.ago)
      @sc.test?(ent).should be_false
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should fail if field is null" do
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>nil)
      @sc.test?(ent).should be_false
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should fail if other field is null" do
      ent = Factory(:entry,:arrival_date=>nil,:release_date=>2.day.ago)
      @sc.test?(ent).should be_false
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should pass if field is null and include empty is true" do
      @sc.include_empty = true
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>nil)
      @sc.test?(ent).should be_true
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should pass if field is not null and other field is true and include empty is true" do
      @sc.include_empty = true
      ent = Factory(:entry,:arrival_date=>nil,:release_date=>2.days.ago)
      @sc.test?(ent).should be_true
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should pass for custom date fields before another custom date field" do
      # There's no real logic differences in search criterion for handling custom fields
      # for the before fields, but there is some backend stuff behind it that I want to make sure
      # don't cause regressions if they're modified.
      @def1 = Factory(:custom_definition,:data_type=>'date', :module_type=>'Entry')
      @def2 = Factory(:custom_definition,:data_type=>'date', :module_type=>'Entry')
      @sc.model_field_uid = SearchCriterion.make_field_name @def1
      @sc.value = SearchCriterion.make_field_name @def2
      
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>nil)
      ent.update_custom_value! @def1, 1.months.ago
      ent.update_custom_value! @def2, 2.month.ago

      @sc.test?(ent).should be_true
      ents = @sc.apply(Entry.scoped).all
      ents.first.should == ent
    end
    it "should pass when comparing fields across multiple module levels" do
      # This tests that we get the entry back if the release date is after the invoice date
      inv = Factory(:commercial_invoice, :invoice_date => 2.months.ago)
      ent = inv.entry
      ent.update_attributes :release_date => 1.month.ago
      @sc.value = "ci_invoice_date"

      @sc.test?([ent, inv]).should be_true
      ents = @sc.apply(Entry.scoped).all
      ents.first.should == ent
    end
  end

  context "before (field)" do
    before :each do
      @u = Factory(:master_user)
      @ss = SearchSetup.new(module_type:'Entry',user:@u)
      @sc = @ss.search_criterions.new(model_field_uid:'ent_release_date',operator:'bfld',value:'ent_arrival_date')
    end
    it "should pass if field is before other field's value" do
      ent = Factory(:entry,:arrival_date=>1.day.ago,:release_date=>2.days.ago)
      @sc.test?(ent).should be_true
      ents = @sc.apply(Entry.scoped).all
      ents.first.should == ent
    end
    it "should fail if field is same as other field's value" do
      ent = Factory(:entry,:arrival_date=>1.day.ago,:release_date=>1.days.ago)
      @sc.test?(ent).should be_false
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should fail if field is after other field's value" do
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>1.days.ago)
      @sc.test?(ent).should be_false
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should fail if field is null" do
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>nil)
      @sc.test?(ent).should be_false
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should fail if other field is null" do
      ent = Factory(:entry,:arrival_date=>nil,:release_date=>2.day.ago)
      @sc.test?(ent).should be_false
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should pass if field is null and include empty is true" do
      @sc.include_empty = true
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>nil)
      @sc.test?(ent).should be_true
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should pass if field is not null and other field is true and include empty is true" do
      @sc.include_empty = true
      ent = Factory(:entry,:arrival_date=>nil,:release_date=>2.days.ago)
      @sc.test?(ent).should be_true
      ents = @sc.apply(Entry.scoped).all
      ents.should be_empty
    end
    it "should pass for custom date fields before another custom date field" do
      # There's no real logic differences in search criterion for handling custom fields
      # for the before fields, but there is some backend stuff behind it that I want to make sure
      # don't cause regressions if they're modified.
      @def1 = Factory(:custom_definition,:data_type=>'date')
      @def2 = Factory(:custom_definition,:data_type=>'date')
      @sc.model_field_uid = SearchCriterion.make_field_name @def1
      @sc.value = SearchCriterion.make_field_name @def2
      
      @product.update_custom_value! @def1, 2.months.ago
      @product.update_custom_value! @def2, 1.month.ago

      @sc.test?(@product).should be_true
      prods = @sc.apply(Product.scoped).all
      prods.first.should == @product
    end
    it "should pass when comparing fields across multiple module levels" do
      # This tests that we get the entry back if the release date is before the invoice date
      inv = Factory(:commercial_invoice, :invoice_date => 1.months.ago)
      ent = inv.entry
      ent.update_attributes :release_date => 2.month.ago
      @sc.value = "ci_invoice_date"

      @sc.test?([ent, inv]).should be_true
      ents = @sc.apply(Entry.scoped).all
      ents.first.should == ent
    end
  end
  context "previous _ months" do
    describe :test? do
      before :each do
        @sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
      end
      it "should find something from the last month with val = 1" do
        @product.created_at = 1.month.ago
        @sc.test?(@product).should be_true
      end
      it "should not find something from this month" do
        @product.created_at = 1.second.ago
        @sc.test?(@product).should be_false
      end
      it "should find something from last month with val = 2" do
        @product.created_at = 1.month.ago
        @sc.value = 2
        @sc.test?(@product).should be_true
      end
      it "should find something from 2 months ago with val = 2" do
        @product.created_at = 2.months.ago
        @sc.value = 2
        @sc.test?(@product).should be_true
      end
      it "should not find something from 2 months ago with val = 1" do
        @product.created_at = 2.months.ago
        @sc.value = 1
        @sc.test?(@product).should be_false
      end
      it "should not find a date in the future" do
        @product.created_at = 1.month.from_now
        @sc.test?(@product).should be_false
      end
      it "should be false for nil" do
        @product.created_at = nil
        @sc.test?(@product).should be_false
      end
      it "should be true for nil with include_empty for date fields" do
        @product.created_at = nil
        crit = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
        crit.include_empty = true
        crit.test?(@product).should be_true
      end
      it "should be true for nil and blank values with include_empty for string fields" do
        @product.name = nil
        crit = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"eq",:value=>"1")
        crit.include_empty = true
        crit.test?(@product).should be_true
        @product.name = ""
        crit.test?(@product).should be_true
        # Make sure we consider nothing but whitespace as empty
        @product.name = "\n  \t  \r"
        crit.test?(@product).should be_true
      end
      it "should be true for nil and 0 with include_empty for numeric fields" do
        e = Entry.new
        crit = SearchCriterion.new(:model_field_uid=>:ent_total_fees,:operator=>"eq",:value=>"1")
        crit.include_empty = true
        crit.test?(e).should be_true
        e.total_fees = 0
        crit.test?(e).should be_true
        e.total_fees = 0.0
        crit.test?(e).should be_true
      end
      it "should be true for nil and false with include_empty for boolean fields" do
        e = Entry.new
        crit = SearchCriterion.new(:model_field_uid=>:ent_paperless_release,:operator=>"notnull",:value=>nil)
        crit.include_empty = true
        crit.test?(e).should be_true
        e.paperless_release = true
        crit.test?(e).should be_true
        e.paperless_release = false
        crit.test?(e).should be_false
      end
      it "should not consider trailing whitespce for = operator" do
        @product.name = "ABC   "
        crit = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"eq",:value=>"ABC")
        crit.test?(@product).should be_true
        crit.value = "ABC   "
        @product.name = "ABC"
        crit.test?(@product).should be_true

        #Make sure we are considering leading whitespace
        @product.name = "   ABC"
        crit.test?(@product).should be_false
        crit.value = "   ABC"
        @product.name = "ABC"
        crit.test?(@product).should be_false
      end
      it "should not consider trailing whitespce for != operator" do
        @product.name = "ABC   "
        crit = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"nq",:value=>"ABC")
        crit.test?(@product).should be_false
        crit.value = "ABC   "
        @product.name = "ABC"
        crit.test?(@product).should be_false

        #Make sure we are considering leading whitespace
        @product.name = "   ABC"
        crit.test?(@product).should be_true
        crit.value = "   ABC"
        @product.name = "ABC"
        crit.test?(@product).should be_true
      end
      it "should not consider trailing whitespce for IN operator" do
        crit = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"in",:value=>"ABC\nDEF")
        @product.name = "ABC   "
        crit.test?(@product).should be_true
        @product.name = "DEF    "
        crit.test?(@product).should be_true
        crit.value = "ABC   \nDEF   \n"
        crit.test?(@product).should be_true

        #Make sure we are considering leading whitespace
        @product.name = "   ABC"
        crit.test?(@product).should be_false
        @product.name = "   DEF"
        crit.test?(@product).should be_false
      end
      it "should find something with a NOT IN operator" do
        crit = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"notin",:value=>"ABC\nDEF")
        @product.name = "A"
        crit.test?(@product).should be_true
        @product.name = "ABC"
        crit.test?(@product).should be_false
        @product.name = "ABC   "
        crit.test?(@product).should be_false
        @product.name = "DEF   "
        crit.test?(@product).should be_false

        @product.name = "  ABC"
        crit.test?(@product).should be_true
        @product.name = "  DEF"
        crit.test?(@product).should be_true
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

        it "should find something with nil date and include_empty" do
          @definition = Factory(:custom_definition,:data_type=>'date')
          @product.update_custom_value! @definition, nil
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"pm",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          v.all.should include @product
        end

        it "should find something with nil string and include_empty" do
          @definition = Factory(:custom_definition,:data_type=>'string')
          @product.update_custom_value! @definition, nil
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"eq",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          v.all.should include @product
        end

        it "should find something with blank string and include_empty" do
          @definition = Factory(:custom_definition,:data_type=>'string')
          # MySQL only trims out spaces (not other whitespace), that's good enough for our use
          # as the actual vetting of the model fields will catch any additional whitespace and reject
          # the model
          @product.update_custom_value! @definition, "   "
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"eq",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          v.all.should include @product
        end

        it "should find something with nil text and include_empty" do
          @definition = Factory(:custom_definition,:data_type=>'text')
          @product.update_custom_value! @definition, nil
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"eq",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          v.all.should include @product
        end

        it "should find something with blank text and include_empty" do
          @definition = Factory(:custom_definition,:data_type=>'text')
          @product.update_custom_value! @definition, " "
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"eq",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          v.all.should include @product
        end

        it "should find something with 0 and include_empty" do
          @definition = Factory(:custom_definition,:data_type=>'integer')
          @product.update_custom_value! @definition, 0
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"eq",:value=>1)
          sc.include_empty = true
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

        it "should find something with a nil date and include_empty" do
          @product.update_attributes(:created_at=>nil)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>2)
          sc.include_empty = true
          sc.apply(Product.where("1=1")).all.should include @product
        end

        it "should find something with a nil string and include_empty" do
          @product.update_attributes(:name=>nil)
          sc = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"eq",:value=>"1")
          sc.include_empty = true
          sc.apply(Product.where("1=1")).all.should include @product
        end

        it "should find something with a blank string and include_empty" do
          @product.update_attributes(:name=>'   ')
          sc = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"eq",:value=>"1")
          sc.include_empty = true
          sc.apply(Product.where("1=1")).all.should include @product
        end

        it "should find something with 0 integer value and include_empty" do
          entry = Factory(:entry)
          entry.update_attributes(:total_packages=> 0)
          sc = SearchCriterion.new(:model_field_uid=>:ent_total_packages,:operator=>"eq",:value=>"1")
          sc.include_empty = true
          sc.apply(Entry.where("1=1")).all.should include entry
        end

        it "should find something with 0 decimal value and include_empty" do
          entry = Factory(:entry)
          entry.update_attributes(:total_fees=> 0.0)
          sc = SearchCriterion.new(:model_field_uid=>:ent_total_fees,:operator=>"eq",:value=>"1")
          sc.include_empty = true
          sc.apply(Entry.where("1=1")).all.should include entry
        end

        it "should find something with blank text value and include_empty" do
          entry = Factory(:entry)
          entry.update_attributes(:sub_house_bills_of_lading=> '   ')
          sc = SearchCriterion.new(:model_field_uid=>:ent_sbols,:operator=>"eq",:value=>"1")
          sc.include_empty = true
          sc.apply(Entry.where("1=1")).all.should include entry
        end

        it "should find something with NOT IN operator" do
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"notin", :value=>"val\nval2")
          sc.apply(Product.where("1=1")).all.should include @product
        end

        it "should not find something with NOT IN operator" do
          #Leave some whitespace in so we know it's getting trimmed out
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"notin", :value=>"#{@product.unique_identifier}   ")
          sc.apply(Product.where("1=1")).all.should_not include @product
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
    it "should find something with a blank value provided a blank IN list value" do
      # Without the added code backing what's in this test, the query produced for a blank IN list value would be IN (null),
      # but after the change it's IN (''), which is more in line with what the user is requesting if they left the value blank.
      @product.update_attributes :name => ""
      sc = SearchCriterion.new(:model_field_uid=>:prod_name, :operator=>"in", :value=>"")
      sc.apply(Product.where("1=1")).all.should include @product
    end
  end
  
  context 'date time field' do
    it "should properly handle not null" do
      u = Factory(:master_user)
      cd = Factory(:custom_definition,module_type:'Product',data_type:'date') 
      @product.update_custom_value! cd, Time.now
      p2 = Factory(:product)
      p3 = Factory(:product)
      p3.custom_values.create!(:custom_definition_id=>cd.id)
      ss = SearchSetup.new(module_type:'Product',user:u)
      sc = ss.search_criterions.new(model_field_uid:"*cf_#{cd.id}",operator:'notnull')
      sq = SearchQuery.new ss, u
      h = sq.execute
      h.collect {|r| r[:row_key]}.should == [@product.id]
    end
    it "should properly handle null" do
      u = Factory(:master_user)
      cd = Factory(:custom_definition,module_type:'Product',data_type:'date') 
      @product.update_custom_value! cd, Time.now
      p2 = Factory(:product)
      p3 = Factory(:product)
      p3.custom_values.create!(:custom_definition_id=>cd.id)
      ss = SearchSetup.new(module_type:'Product',user:u)
      sc = ss.search_criterions.new(model_field_uid:"*cf_#{cd.id}",operator:'null')
      sq = SearchQuery.new ss, u
      h = sq.execute
      h.collect {|r| r[:row_key]}.sort.should == [p2.id,p3.id]
    end
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

    it "should use current timezone to compare object field" do
      tz = "Hawaii"
      date = "2013-01-01"
      value = date + " " + tz
      

      sc = SearchCriterion.new(:model_field_uid=>:prod_created_at, :operator=>"gt", :value=>value)
      p = Product.new
      # Hawaii is 10 hours behind UTC so adjust our created at to make sure 
      # the offset is being calculated
      p.created_at = ActiveSupport::TimeZone["UTC"].parse "2013-01-01 10:01"

      Time.use_zone(tz) do
        sc.test?(p).should be_true
        p.created_at = ActiveSupport::TimeZone["UTC"].parse "2013-01-01 09:59"
        sc.test?(p).should be_false
      end
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
        @search_criterion.test?(@product).should == true
      end
      it 'should return for Is Empty and nil' do
        @custom_value.value = nil
        @custom_value.save!
        @search_criterion.apply(Product).should include @product 
        @search_criterion.test?(@product).should == true
      end

      it 'should not return for Is Empty and true' do
        @custom_value.value = true
        @custom_value.save!
        @search_criterion.apply(Product).should_not include @product 
        @search_criterion.test?(@product).should == false
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
        @search_criterion.test?(@product).should == true
      end

      it 'should not return for Is Not Empty and false' do
        @custom_value.value = false
        @custom_value.save!
        @search_criterion.apply(Product).should_not include @product 
        @search_criterion.test?(@product).should == false
      end

      it 'should not return for Is Not Empty and nil' do
        @custom_value.value = nil
        @custom_value.save!
        @search_criterion.apply(Product).should_not include @product 
        @search_criterion.test?(@product).should == false
      end

      it 'should return for Is Not Empty, include_empty and nil' do
        @custom_value.value = nil
        @custom_value.save!
        @search_criterion.include_empty = true
        @search_criterion.apply(Product).should include @product 
        @search_criterion.test?(@product).should == true
      end

    end
  end
end
