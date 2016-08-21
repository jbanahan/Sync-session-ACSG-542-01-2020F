require 'spec_helper'

describe SearchCriterion do
  before :each do
    @product = Factory(:product)
  end
  describe "core_module" do
    it "should return core module based on module type" do
      expect(SearchCriterion.new(model_field_uid:'ent_release_date').core_module.klass).to eq Entry
    end
  end
  context "after (field)" do
    before :each do
      @u = Factory(:master_user)
      @ss = SearchSetup.new(module_type:'Entry',user:@u)
      @sc = @ss.search_criterions.new(model_field_uid:'ent_release_date',operator:'afld',value:'ent_arrival_date')
    end
    it "should pass if field is after other field's value" do
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>1.days.ago)
      expect(@sc.test?(ent)).to be_truthy
      ents = @sc.apply(Entry.scoped).all
      expect(ents.first).to eq(ent)
    end
    it "should fail if field is same as other field's value" do
      ent = Factory(:entry,:arrival_date=>1.day.ago,:release_date=>1.days.ago)
      expect(@sc.test?(ent)).to be_falsey
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
    end
    it "should fail if field is before other field's value" do
      ent = Factory(:entry,:arrival_date=>1.day.ago,:release_date=>2.days.ago)
      expect(@sc.test?(ent)).to be_falsey
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
    end
    it "should fail if field is null" do
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>nil)
      expect(@sc.test?(ent)).to be_falsey
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
    end
    it "should fail if other field is null" do
      ent = Factory(:entry,:arrival_date=>nil,:release_date=>2.day.ago)
      expect(@sc.test?(ent)).to be_falsey
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
    end
    it "should pass if field is null and include empty is true" do
      @sc.include_empty = true
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>nil)
      expect(@sc.test?(ent)).to be_truthy
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
    end
    it "should pass if field is not null and other field is true and include empty is true" do
      @sc.include_empty = true
      ent = Factory(:entry,:arrival_date=>nil,:release_date=>2.days.ago)
      expect(@sc.test?(ent)).to be_truthy
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
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

      expect(@sc.test?(ent)).to be_truthy
      ents = @sc.apply(Entry.scoped).all
      expect(ents.first).to eq(ent)
    end
    it "should pass when comparing fields across multiple module levels" do
      # This tests that we get the entry back if the release date is after the invoice date
      inv = Factory(:commercial_invoice, :invoice_date => 2.months.ago)
      ent = inv.entry
      ent.update_attributes :release_date => 1.month.ago
      @sc.value = "ci_invoice_date"

      expect(@sc.test?([ent, inv])).to be_truthy
      ents = @sc.apply(Entry.scoped).all
      expect(ents.first).to eq(ent)
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
      expect(@sc.test?(ent)).to be_truthy
      ents = @sc.apply(Entry.scoped).all
      expect(ents.first).to eq(ent)
    end
    it "should fail if field is same as other field's value" do
      ent = Factory(:entry,:arrival_date=>1.day.ago,:release_date=>1.days.ago)
      expect(@sc.test?(ent)).to be_falsey
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
    end
    it "should fail if field is after other field's value" do
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>1.days.ago)
      expect(@sc.test?(ent)).to be_falsey
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
    end
    it "should fail if field is null" do
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>nil)
      expect(@sc.test?(ent)).to be_falsey
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
    end
    it "should fail if other field is null" do
      ent = Factory(:entry,:arrival_date=>nil,:release_date=>2.day.ago)
      expect(@sc.test?(ent)).to be_falsey
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
    end
    it "should pass if field is null and include empty is true" do
      @sc.include_empty = true
      ent = Factory(:entry,:arrival_date=>2.day.ago,:release_date=>nil)
      expect(@sc.test?(ent)).to be_truthy
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
    end
    it "should pass if field is not null and other field is true and include empty is true" do
      @sc.include_empty = true
      ent = Factory(:entry,:arrival_date=>nil,:release_date=>2.days.ago)
      expect(@sc.test?(ent)).to be_truthy
      ents = @sc.apply(Entry.scoped).all
      expect(ents).to be_empty
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

      expect(@sc.test?(@product)).to be_truthy
      prods = @sc.apply(Product.scoped).all
      expect(prods.first).to eq(@product)
    end
    it "should pass when comparing fields across multiple module levels" do
      # This tests that we get the entry back if the release date is before the invoice date
      inv = Factory(:commercial_invoice, :invoice_date => 1.months.ago)
      ent = inv.entry
      ent.update_attributes :release_date => 2.month.ago
      @sc.value = "ci_invoice_date"

      expect(@sc.test?([ent, inv])).to be_truthy
      ents = @sc.apply(Entry.scoped).all
      expect(ents.first).to eq(ent)
    end
  end
  context "previous _ months" do
    describe "test?" do
      before :each do
        @sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
      end
      it "should find something from the last month with val = 1" do
        @product.created_at = 1.month.ago
        expect(@sc.test?(@product)).to be_truthy
      end
      it "should not find something from this month" do
        @product.created_at = 1.second.ago
        expect(@sc.test?(@product)).to be_falsey
      end
      it "should find something from last month with val = 2" do
        @product.created_at = 1.month.ago
        @sc.value = 2
        expect(@sc.test?(@product)).to be_truthy
      end
      it "should find something from 2 months ago with val = 2" do
        @product.created_at = 2.months.ago
        @sc.value = 2
        expect(@sc.test?(@product)).to be_truthy
      end
      it "should not find something from 2 months ago with val = 1" do
        @product.created_at = 2.months.ago
        @sc.value = 1
        expect(@sc.test?(@product)).to be_falsey
      end
      it "should not find a date in the future" do
        @product.created_at = 1.month.from_now
        expect(@sc.test?(@product)).to be_falsey
      end
      it "should be false for nil" do
        @product.created_at = nil
        expect(@sc.test?(@product)).to be_falsey
      end
      it "should be true for nil with include_empty for date fields" do
        @product.created_at = nil
        crit = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
        crit.include_empty = true
        expect(crit.test?(@product)).to be_truthy
      end
      it "should be true for nil and blank values with include_empty for string fields" do
        @product.name = nil
        crit = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"eq",:value=>"1")
        crit.include_empty = true
        expect(crit.test?(@product)).to be_truthy
        @product.name = ""
        expect(crit.test?(@product)).to be_truthy
        # Make sure we consider nothing but whitespace as empty
        @product.name = "\n  \t  \r"
        expect(crit.test?(@product)).to be_truthy
      end
      it "should be true for nil and 0 with include_empty for numeric fields" do
        e = Entry.new
        crit = SearchCriterion.new(:model_field_uid=>:ent_total_fees,:operator=>"eq",:value=>"1")
        crit.include_empty = true
        expect(crit.test?(e)).to be_truthy
        e.total_fees = 0
        expect(crit.test?(e)).to be_truthy
        e.total_fees = 0.0
        expect(crit.test?(e)).to be_truthy
      end
      it "should be true for nil and false with include_empty for boolean fields" do
        e = Entry.new
        crit = SearchCriterion.new(:model_field_uid=>:ent_paperless_release,:operator=>"notnull",:value=>nil)
        crit.include_empty = true
        expect(crit.test?(e)).to be_truthy
        e.paperless_release = true
        expect(crit.test?(e)).to be_truthy
        e.paperless_release = false
        expect(crit.test?(e)).to be_falsey
      end
      it "should not consider trailing whitespce for = operator" do
        @product.name = "ABC   "
        crit = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"eq",:value=>"ABC")
        expect(crit.test?(@product)).to be_truthy
        crit.value = "ABC   "
        @product.name = "ABC"
        expect(crit.test?(@product)).to be_truthy

        #Make sure we are considering leading whitespace
        @product.name = "   ABC"
        expect(crit.test?(@product)).to be_falsey
        crit.value = "   ABC"
        @product.name = "ABC"
        expect(crit.test?(@product)).to be_falsey
      end
      it "should not consider trailing whitespce for != operator" do
        @product.name = "ABC   "
        crit = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"nq",:value=>"ABC")
        expect(crit.test?(@product)).to be_falsey
        crit.value = "ABC   "
        @product.name = "ABC"
        expect(crit.test?(@product)).to be_falsey

        #Make sure we are considering leading whitespace
        @product.name = "   ABC"
        expect(crit.test?(@product)).to be_truthy
        crit.value = "   ABC"
        @product.name = "ABC"
        expect(crit.test?(@product)).to be_truthy
      end
      it "should not consider trailing whitespce for IN operator" do
        crit = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"in",:value=>"ABC\nDEF")
        @product.name = "ABC   "
        expect(crit.test?(@product)).to be_truthy
        @product.name = "DEF    "
        expect(crit.test?(@product)).to be_truthy
        crit.value = "ABC   \nDEF   \n"
        expect(crit.test?(@product)).to be_truthy

        #Make sure we are considering leading whitespace
        @product.name = "   ABC"
        expect(crit.test?(@product)).to be_falsey
        @product.name = "   DEF"
        expect(crit.test?(@product)).to be_falsey
      end
      it "should find something with a NOT IN operator" do
        crit = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"notin",:value=>"ABC\nDEF")
        @product.name = "A"
        expect(crit.test?(@product)).to be_truthy
        @product.name = "ABC"
        expect(crit.test?(@product)).to be_falsey
        @product.name = "ABC   "
        expect(crit.test?(@product)).to be_falsey
        @product.name = "DEF   "
        expect(crit.test?(@product)).to be_falsey

        @product.name = "  ABC"
        expect(crit.test?(@product)).to be_truthy
        @product.name = "  DEF"
        expect(crit.test?(@product)).to be_truthy
      end
    end
    describe "apply" do
      context :custom_field do
        it "should find something created last month with val = 1" do
          @definition = Factory(:custom_definition,:data_type=>'date')
          @product.update_custom_value! @definition, 1.month.ago
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"pm",:value=>1)
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include @product
        end

        it "should find something with nil date and include_empty" do
          @definition = Factory(:custom_definition,:data_type=>'date')
          @product.update_custom_value! @definition, nil
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"pm",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include @product
        end

        it "should find something with nil string and include_empty" do
          @definition = Factory(:custom_definition,:data_type=>'string')
          @product.update_custom_value! @definition, nil
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"eq",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include @product
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
          expect(v.all).to include @product
        end

        it "should find something with nil text and include_empty" do
          @definition = Factory(:custom_definition,:data_type=>'text')
          @product.update_custom_value! @definition, nil
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"eq",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include @product
        end

        it "should find something with blank text and include_empty" do
          @definition = Factory(:custom_definition,:data_type=>'text')
          @product.update_custom_value! @definition, " "
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"eq",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include @product
        end

        it "should find something with 0 and include_empty" do
          @definition = Factory(:custom_definition,:data_type=>'integer')
          @product.update_custom_value! @definition, 0
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"eq",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include @product
        end

        it "should find something with include_empty that doesn't have a custom value record for custom field" do
          @definition = Factory(:custom_definition,:data_type=>'integer')
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"eq",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include @product
        end

        it "should find something with include_empty that doesn't have a custom value record for the child object's custom field" do
          @definition = Factory(:custom_definition,:data_type=>'integer', :module_type=>"Classification")
          sc = SearchCriterion.new(:model_field_uid=>"*cf_#{@definition.id}",:operator=>"eq",:value=>1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include @product
        end
      end
      context :normal_field do
        it "should process value before search" do
          t = Factory(:tariff_record, hts_1: "9801001010")
          sc = SearchCriterion.new(:model_field_uid=>:hts_hts_1,:operator=>"eq",:value=>"9801.00.1010")
          v = sc.apply(TariffRecord.where("1=1"))
          expect(v.all).to include t
        end
  
        it "should find something created last month with val = 1" do
          @product.update_attributes(:created_at=>1.month.ago)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include @product
        end
        it "should not find something created in the future" do
          @product.update_attributes(:created_at=>1.month.from_now)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
          v = sc.apply(Product.where("1=1"))
          expect(v.all).not_to include @product
        end
        it "should not find something created this month with val = 1" do
          @product.update_attributes(:created_at=>0.seconds.ago)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
          expect(sc.apply(Product.where("1=1")).all).not_to include @product
        end
        it "should not find something created two months ago with val = 1" do
          @product.update_attributes(:created_at=>2.months.ago)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>1)
          expect(sc.apply(Product.where("1=1")).all).not_to include @product
        end
        it "should find something created last month with val = 2" do
          @product.update_attributes(:created_at=>1.month.ago)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>2)
          expect(sc.apply(Product.where("1=1")).all).to include @product
        end
        it "should find something created two months ago with val 2" do
          @product.update_attributes(:created_at=>2.months.ago)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>2)
          expect(sc.apply(Product.where("1=1")).all).to include @product
        end

        it "should find something with a nil date and include_empty" do
          @product.update_attributes(:created_at=>nil)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"pm",:value=>2)
          sc.include_empty = true
          expect(sc.apply(Product.where("1=1")).all).to include @product
        end

        it "should find a product when there is a regex match on the appropriate text field" do
          @product.update_attributes(unique_identifier: "Blue jeans")
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid,:operator=>"regexp",:value=>"jean")
          expect(sc.apply(Product.where("1=1")).all).to include @product
          expect(sc.test?(@product)).to be_truthy
        end

        it "should not find a product when there is not a regex match on the appropriate text field" do
          @product.update_attributes(unique_identifier: "Blue jeans")
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid,:operator=>"regexp",:value=>"khaki")
          expect(sc.apply(Product.where("1=1")).all).not_to include @product
          expect(sc.test?(@product)).to be_falsey
        end

        it "should find a product when there is a NOT regex match on the appropriate text field" do
          @product.update_attributes(unique_identifier: "Blue jeans")
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid,:operator=>"notregexp",:value=>"shirt")
          expect(sc.apply(Product.where("1=1")).all).to include @product
          expect(sc.test?(@product)).to be_truthy
        end

        it "should not find a product when there is a NOT regex match on the appropriate text field" do
          @product.update_attributes(unique_identifier: "Blue shirt")
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid,:operator=>"notregexp",:value=>"shirt")
          expect(sc.apply(Product.where("1=1")).all).not_to include @product
          expect(sc.test?(@product)).to be_falsey
        end

        it "should find an entry when there is a regex match on the appropriate date field" do
          # Using entry because it has an actual date field in it
          e = Factory(:entry, eta_date: '2013-02-03')

          sc = SearchCriterion.new(:model_field_uid=>:ent_eta_date,:operator=>"dt_regexp",:value=>"-02-")
          expect(sc.apply(Entry.where("1=1")).all).to include e
          expect(sc.test?(e)).to be_truthy

          sc = SearchCriterion.new(:model_field_uid=>:ent_eta_date,:operator=>"dt_regexp",:value=>"[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}")
          expect(sc.apply(Entry.where("1=1")).all).to include e
          expect(sc.test?(e)).to be_truthy
        end

        it "should find an entry when there is a not regex match on the appropriate date field" do
          # Using entry because it has an actual date field in it
          e = Factory(:entry, eta_date: '2013-02-03')

          sc = SearchCriterion.new(:model_field_uid=>:ent_eta_date,:operator=>"dt_notregexp",:value=>"1999")
          expect(sc.apply(Entry.where("1=1")).all).to include e
          expect(sc.test?(e)).to be_truthy
        end

        it "should not find an entry when there is a not regex match on the appropriate date field" do
          # Using entry because it has an actual date field in it
          e = Factory(:entry, eta_date: '2013-02-03')

          sc = SearchCriterion.new(:model_field_uid=>:ent_eta_date,:operator=>"dt_notregexp",:value=>"2013")
          expect(sc.apply(Entry.where("1=1")).all).not_to include e
          expect(sc.test?(e)).to be_falsey
        end

        it "finds a product when regex on datetime field" do
          # Because of the way we use the mysql function convert_tz (which only works in prod due to having to setup the full timezone support in the database)
          # we're only testing the test? method for this.
          @product.update_attributes(created_at: Time.zone.now)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"dt_regexp",:value=>Time.now.year.to_s)
          expect(sc.test?(@product)).to be_truthy

          Time.use_zone("Eastern Time (US & Canada)") do
            @product.update_attributes(created_at: ActiveSupport::TimeZone["UTC"].parse("2013-02-03 04:05"))
            # Note the day in the regex is the day before what we set in the created_at attribute
            sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"dt_regexp",:value=>"02-02")
            expect(sc.test?(@product)).to be_truthy
          end
        end

        it "finds a product when notregex on datetime field" do
          # Because of the way we use the mysql function convert_tz (which only works in prod due to having to setup the full timezone support in the database)
          # we're only testing the test? method for this
          @product.update_attributes(created_at: Time.zone.now)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"dt_notregexp",:value=>"1999")
          expect(sc.test?(@product)).to be_truthy

          Time.use_zone("Eastern Time (US & Canada)") do
            @product.update_attributes(created_at: ActiveSupport::TimeZone["UTC"].parse("2013-02-03 04:05"))
            sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"dt_notregexp",:value=>"02-03")
            expect(sc.test?(@product)).to be_truthy
          end
        end

        it "does not find a product when notregex on datetime field" do
          # Because of the way we use the mysql function convert_tz (which only works in prod due to having to setup the full timezone support in the database)
          # we're only testing the test? method for this
          @product.update_attributes(created_at: Time.zone.now)
          sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"dt_notregexp",:value=>Time.now.year.to_s)
          expect(sc.test?(@product)).to be_falsey

          Time.use_zone("Eastern Time (US & Canada)") do
            @product.update_attributes(created_at: ActiveSupport::TimeZone["UTC"].parse("2013-02-03 04:05"))
            sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"dt_notregexp",:value=>"02-02")
            expect(sc.test?(@product)).to be_falsey
          end
        end

        it "should find a product when there is a regex match on the appropriate integer field" do
          @product.attachments << Factory(:attachment)
          sc = SearchCriterion.new(:model_field_uid=>:prod_attachment_count,:operator=>"regexp",:value=>"1")
          expect(sc.apply(Product.where("1=1")).all).to include @product
          expect(sc.test?(@product)).to be_truthy
        end

        it "should find a product when there is a regex match on the appropriate integer field" do
          @product.attachments << Factory(:attachment)
          sc = SearchCriterion.new(:model_field_uid=>:prod_attachment_count,:operator=>"notregexp",:value=>"0")
          expect(sc.apply(Product.where("1=1")).all).to include @product
          expect(sc.test?(@product)).to be_truthy
        end

        it "should find something with a nil string and include_empty" do
          @product.update_attributes(:name=>nil)
          sc = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"eq",:value=>"1")
          sc.include_empty = true
          expect(sc.apply(Product.where("1=1")).all).to include @product
        end

        it "should find something with a blank string and include_empty" do
          @product.update_attributes(:name=>'   ')
          sc = SearchCriterion.new(:model_field_uid=>:prod_name,:operator=>"eq",:value=>"1")
          sc.include_empty = true
          expect(sc.apply(Product.where("1=1")).all).to include @product
        end

        it "should find something with 0 integer value and include_empty" do
          entry = Factory(:entry)
          entry.update_attributes(:total_packages=> 0)
          sc = SearchCriterion.new(:model_field_uid=>:ent_total_packages,:operator=>"eq",:value=>"1")
          sc.include_empty = true
          expect(sc.apply(Entry.where("1=1")).all).to include entry
        end

        it "should find an entry with a decimal value and a regex match" do
          entry = Factory(:entry)
          entry.update_attributes(:total_fees => 123.45)
          sc = SearchCriterion.new(:model_field_uid => :ent_total_fees, :operator=>"regexp",:value=>"123")
          sql_stm = sc.apply(Entry.where("1=1")).to_sql
          expect(sc.apply(Entry.where("1=1")).all).to include entry
          expect(sc.test?(entry)).to be_truthy
        end

        it "should find something with 0 decimal value and include_empty" do
          entry = Factory(:entry)
          entry.update_attributes(:total_fees=> 0.0)
          sc = SearchCriterion.new(:model_field_uid=>:ent_total_fees,:operator=>"eq",:value=>"1")
          sc.include_empty = true
          expect(sc.apply(Entry.where("1=1")).all).to include entry
        end

        it "should find something with blank text value and include_empty" do
          entry = Factory(:entry)
          entry.update_attributes(:sub_house_bills_of_lading=> '   ')
          sc = SearchCriterion.new(:model_field_uid=>:ent_sbols,:operator=>"eq",:value=>"1")
          sc.include_empty = true
          expect(sc.apply(Entry.where("1=1")).all).to include entry
        end

        it "should find something with NOT IN operator" do
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"notin", :value=>"val\nval2")
          expect(sc.apply(Product.where("1=1")).all).to include @product
        end

        it "should not find something with NOT IN operator" do
          #Leave some whitespace in so we know it's getting trimmed out
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"notin", :value=>"#{@product.unique_identifier}   ")
          expect(sc.apply(Product.where("1=1")).all).not_to include @product
        end

        it "should find something with an include empty search parameter on a child object, even if the child object doesn't exist" do
          entry = Factory(:entry)
          sc = SearchCriterion.new(:model_field_uid=>:ci_invoice_number,:operator=>"eq",:value=>"1")
          sc.include_empty = true
          expect(sc.apply(Entry.where("1=1")).all).to include entry
        end
        it "finds something with doesn't start with parameter" do
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"nsw", :value=>"ABC123")
          expect(sc.apply(Product.where("1=1")).all).to include @product
        end
        it "doesn't find something with doesn't start with parameter" do
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"nsw", :value=>@product.unique_identifier[0..2])
          expect(sc.apply(Product.where("1=1")).all).to_not include @product
        end
        it "finds something with doesn't end with parameter" do
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"new", :value=>"ABC123")
          expect(sc.apply(Product.where("1=1")).all).to include @product
        end
        it "doesn't find something with doesn't start with parameter" do
          sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"new", :value=>@product.unique_identifier[-3..-1])
          expect(sc.apply(Product.where("1=1")).all).to_not include @product
        end
      end
    end
  end

  context "Before _ Months Ago" do
    before :each do
      @sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"bma",:value=>1)
    end

    context "test?" do
      it "accepts product created prior to first of the previous month" do
        @product.created_at = 2.months.ago.end_of_month
        expect(@sc.test?(@product)).to be_truthy
      end

      it "does not accept product created on first of the previous month" do
        @product.created_at = 1.months.ago.beginning_of_month.at_midnight
        expect(@sc.test?(@product)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created prior to first of the previous month" do
        @product.update_column :created_at, 2.months.ago.end_of_month
        expect(@sc.apply(Product.where("1=1")).all).to include @product
      end

      it "does not find product created on the first of the previous month" do
        @product.update_column :created_at, 1.months.ago.beginning_of_month.at_midnight
        expect(@sc.apply(Product.where("1=1")).all).to_not include @product
      end
    end
  end

  context "After _ Months Ago" do
    before :each do
      @sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"ama",:value=>1)
    end

    context "test?" do
      it "accepts product created after the first of the previous month" do
        @product.created_at = Time.zone.now.beginning_of_month.at_midnight
        expect(@sc.test?(@product)).to be_truthy
      end

      it "does not accept product created prior to the first of the previous month" do
        @product.created_at = (Time.zone.now.beginning_of_month.at_midnight - 1.second)
        expect(@sc.test?(@product)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created prior to first of the previous month" do
        @product.update_column :created_at, Time.zone.now.beginning_of_month.at_midnight
        expect(@sc.apply(Product.where("1=1")).all).to include @product
      end

      it "does not find product created prior to the first of the previous month" do
        @product.update_column :created_at, (Time.zone.now.beginning_of_month.at_midnight - 1.second)
        expect(@sc.apply(Product.where("1=1")).all).to_not include @product
      end
    end
  end

  context "After _ Months From Now" do
    before :each do
      @sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"amf",:value=>1)
    end

    context "test?" do
      it "accepts product created after 1 month from now" do
        @product.created_at = (Time.zone.now.beginning_of_month + 2.month).at_midnight
        expect(@sc.test?(@product)).to be_truthy
      end

      it "does not accept product created on last of the next month" do
        @product.created_at = ((Time.zone.now.beginning_of_month + 2.month).at_midnight - 1.second)
        expect(@sc.test?(@product)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created after 1 month from now" do
        @product.update_column :created_at, (Time.zone.now.beginning_of_month + 2.month).at_midnight
        expect(@sc.apply(Product.where("1=1")).all).to include @product
      end

      it "does not find product created on last of the next month" do
        @product.update_column :created_at, ((Time.zone.now.beginning_of_month + 2.month).at_midnight - 1.second)
        expect(@sc.apply(Product.where("1=1")).all).to_not include @product
      end
    end
  end

  context "Before _ Months From Now" do
    before :each do
      @sc = SearchCriterion.new(:model_field_uid=>:prod_created_at,:operator=>"bmf",:value=>1)
    end

    context "test?" do
      it "accepts product created before 1 month from now" do
        @product.created_at = ((Time.zone.now.beginning_of_month + 1.month).at_midnight - 1.second)
        expect(@sc.test?(@product)).to be_truthy
      end

      it "does not accept product created on first of the next month" do
        @product.created_at = (Time.zone.now.beginning_of_month + 1.month).at_midnight
        expect(@sc.test?(@product)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created before 1 month from now" do
        @product.update_column :created_at, ((Time.zone.now.beginning_of_month + 1.month).at_midnight - 1.second)
        expect(@sc.apply(Product.where("1=1")).all).to include @product
      end

      it "does not find product created before 1 month from now" do
        @product.update_column :created_at,  (Time.zone.now.beginning_of_month + 1.month).at_midnight
        expect(@sc.apply(Product.where("1=1")).all).to_not include @product
      end
    end
  end

  context "string field IN list" do
    it "should find something using a string field from a list of values using unix newlines" do
      sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"in", :value=>"val\n#{@product.unique_identifier}\nval2")
      expect(sc.apply(Product.where("1=1")).all).to include @product
    end

    it "should find something using a string field from a list of values using windows newlines" do
      sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"in", :value=>"val\r\n#{@product.unique_identifier}\r\nval2")
      expect(sc.apply(Product.where("1=1")).all).to include @product
    end
    it "should not add blank strings in the IN list when using windows newlines" do
      sc = SearchCriterion.new(:model_field_uid=>:prod_uid, :operator=>"in", :value=>"val\r\n#{@product.unique_identifier}\r\nval2")
      expect(sc.apply(Product.where("1=1")).to_sql).to match /\('val',\s?'#{@product.unique_identifier}',\s?'val2'\)/
    end
    it "should find something using a numeric field from a list of values" do
      sc = SearchCriterion.new(:model_field_uid=>:prod_class_count, :operator=>"in", :value=>"1\n0\r\n3")
      expect(sc.apply(Product.where("1=1")).all).to include @product
    end
    it "should find something with a blank value provided a blank IN list value" do
      # Without the added code backing what's in this test, the query produced for a blank IN list value would be IN (null),
      # but after the change it's IN (''), which is more in line with what the user is requesting if they left the value blank.
      @product.update_attributes :name => ""
      sc = SearchCriterion.new(:model_field_uid=>:prod_name, :operator=>"in", :value=>"")
      expect(sc.apply(Product.where("1=1")).all).to include @product
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
      expect(h.collect {|r| r[:row_key]}).to eq([@product.id])
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
      expect(h.collect {|r| r[:row_key]}.sort).to eq([p2.id,p3.id])
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
      expect(sc.apply(Product.where("1=1")).to_sql).to match(/#{expected_value}/)
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
      expect(sql).to match(/#{expected_value}/)
    end

    it "should translate datetime values to UTC for eq operator" do
      # Make sure that if the timezone is not in the value, that we add eastern timezone to it
      value = "2012-01-01"
      sc = SearchCriterion.new(:model_field_uid=>:prod_created_at, :operator=>"eq", :value=>value)
      expected_value = Time.use_zone("Eastern Time (US & Canada)") do
        Time.zone.parse(value + " 00:00:00").utc.to_formatted_s(:db)
      end

      expect(sc.apply(Product.where("1=1")).to_sql).to match(/#{expected_value}/)

      #verify the nq operator is translated too
      sc.operator = "nq"
      expect(sc.apply(Product.where("1=1")).to_sql).to match(/#{expected_value}/)
    end

    it "should not translate date values to UTC for lt, gt, or eq operators" do
      value = "2012-01-01"
      # There's no actual date field in product, we'll use Entry.duty_due_date instead
      sc = SearchCriterion.new(:model_field_uid=>:ent_duty_due_date, :operator=>"eq", :value=>value)
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/#{value}/)

      sc.operator = "lt"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/#{value}/)

      sc.operator = "gt"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/#{value}/)
    end

    it "should not translate datetime values to UTC for any operator other than lt, gt, eq, or nq" do
      sc = SearchCriterion.new(:model_field_uid=>:prod_created_at, :operator=>"bda", :value=>10)
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/10/)

      sc.operator = "ada"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/10/)

      sc.operator = "bdf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/10/)

      sc.operator = "adf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/10/)

      sc.operator = "pm"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/10/)

      sc.operator = "null"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/NULL/)

      sc.operator = "notnull"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/NOT NULL/)
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
        expect(sc.test?(p)).to be_truthy
        p.created_at = ActiveSupport::TimeZone["UTC"].parse "2013-01-01 09:59"
        expect(sc.test?(p)).to be_falsey
      end
    end

    it "utilize's users current time in UTC when doing days/months comparison against date time fields" do
      sc = SearchCriterion.new(:model_field_uid=>:prod_created_at, :operator=>"bda", :value=>1)
      now = Time.zone.now.in_time_zone 'Hawaii'
      allow(Time.zone).to receive(:now).and_return now

      current_time = "'#{now.at_midnight.in_time_zone("UTC").strftime("%Y-%m-%d %H:%M:%S")}'"

      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time

      sc.operator = "ada"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "adf"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "bdf"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "bma"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "ama"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "amf"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "bmf"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "pm"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
    end

    it "utilize's users current date when doing days/months comparison against date fields" do
      sc = SearchCriterion.new(:model_field_uid=>:ent_export_date, :operator=>"bda", :value=>1)
      now = Time.zone.now.in_time_zone 'Hawaii'
      allow(Time.zone).to receive(:now).and_return now

      current_date = "'#{now.at_midnight.strftime("%Y-%m-%d %H:%M:%S")}'"

      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date

      sc.operator = "ada"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "adf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "bdf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "bma"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "ama"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "amf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "bmf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "pm"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
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
        expect(@search_criterion.apply(Product)).to include @product
        expect(@search_criterion.test?(@product)).to eq(true)
      end
      it 'should return for Is Empty and nil' do
        @custom_value.value = nil
        @custom_value.save!
        expect(@search_criterion.apply(Product)).to include @product
        expect(@search_criterion.test?(@product)).to eq(true)
      end

      it 'should not return for Is Empty and true' do
        @custom_value.value = true
        @custom_value.save!
        expect(@search_criterion.apply(Product)).not_to include @product
        expect(@search_criterion.test?(@product)).to eq(false)
      end

      context :string_handling do
        before :each do
          @ent = Factory(:entry,broker_reference:' ')
          @sc = SearchCriterion.new(model_field_uid:'ent_brok_ref',operator:'null')
        end
        it "should return on empty string" do
          expect(@sc.apply(Entry).to_a).to eq [@ent]
          @ent.update_attributes(broker_reference:'x')
          expect(@sc.apply(Entry)).to be_empty
        end
        it "should test on empty string" do
          expect(@sc.test?(@ent)).to be_truthy
          @ent.update_attributes(broker_reference:'x')
          expect(@sc.test?(@ent)).to be_falsey
        end
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
        expect(@search_criterion.apply(Product)).to include @product
        expect(@search_criterion.test?(@product)).to eq(true)
      end

      it 'should not return for Is Not Empty and false' do
        @custom_value.value = false
        @custom_value.save!
        expect(@search_criterion.apply(Product)).not_to include @product
        expect(@search_criterion.test?(@product)).to eq(false)
      end

      it 'should not return for Is Not Empty and nil' do
        @custom_value.value = nil
        @custom_value.save!
        expect(@search_criterion.apply(Product)).not_to include @product
        expect(@search_criterion.test?(@product)).to eq(false)
      end

      it 'should return for Is Not Empty, include_empty and nil' do
        @custom_value.value = nil
        @custom_value.save!
        @search_criterion.include_empty = true
        expect(@search_criterion.apply(Product)).to include @product
        expect(@search_criterion.test?(@product)).to eq(true)
      end
      context :string_handling do
        before :each do
          @ent = Factory(:entry,broker_reference:'x')
          @sc = SearchCriterion.new(model_field_uid:'ent_brok_ref',operator:'notnull')
        end
        it "should return on empty string" do
          expect(@sc.apply(Entry).to_a).to eq [@ent]
          @ent.update_attributes(broker_reference:' ')
          expect(@sc.apply(Entry)).to be_empty
        end
        it "should test on empty string" do
          expect(@sc.test?(@ent)).to be_truthy
          @ent.update_attributes(broker_reference:' ')
          expect(@sc.test?(@ent)).to be_falsey
        end
      end
    end
  end

  context "not starts with" do
    it "tests for strings not starting with" do
      sc = SearchCriterion.new(model_field_uid:'prod_uid',operator:'nsw', value: "ZZZZZZZZZ")
      expect(sc.test? @product).to be_truthy
      expect(sc.apply(Product).all).to eq [@product]

      sc.value = @product.unique_identifier
      expect(sc.test? @product).to be_falsey
      expect(sc.apply(Product).all).to eq []
    end

    it "tests for numbers not starting with" do
      ent = Factory(:entry, total_packages: 10)
      sc = SearchCriterion.new(model_field_uid:'ent_total_packages',operator:'nsw', value: "9")

      expect(sc.test? ent).to be_truthy
      expect(sc.apply(Entry).all).to eq [ent]

      sc.value = 1
      expect(sc.test? ent).to be_falsey
      expect(sc.apply(Entry).all).to eq []
    end
  end

  context "not ends with" do
    it "tests for strings not ending with" do
      sc = SearchCriterion.new(model_field_uid:'prod_uid',operator:'new', value: "ZZZZZZZZZ")
      expect(sc.test? @product).to be_truthy
      expect(sc.apply(Product).all).to eq [@product]

      sc.value = @product.unique_identifier[-2..-1]
      expect(sc.test? @product).to be_falsey
      expect(sc.apply(Product).all).to eq []
    end

    it "tests for numbers not ending with" do
      ent = Factory(:entry, total_packages: 10)
      sc = SearchCriterion.new(model_field_uid:'ent_total_packages',operator:'new', value: "9")

      expect(sc.test? ent).to be_truthy
      expect(sc.apply(Entry).all).to eq [ent]

      sc.value = 0
      expect(sc.test? ent).to be_falsey
      expect(sc.apply(Entry).all).to eq []
    end
  end
end
