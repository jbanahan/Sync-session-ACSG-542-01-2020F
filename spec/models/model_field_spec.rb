require 'spec_helper'

describe ModelField do
  describe :process_query_result do
    before :each do
      @u = User.new
    end
    it "should pass vlue through for default object" do
      ModelField.new(10000,:test,CoreModule::PRODUCT,:name).process_query_result("x",@u).should=="x"
    end
    it "should override with given lambda" do
      ModelField.new(10000,:test,CoreModule::PRODUCT,:name,:process_query_result_lambda=>lambda {|v| v.upcase}).process_query_result("x",@u).should=="X"
    end
    it "should write HIDDEN if user cannot view column" do
      ModelField.new(10000,:test,CoreModule::PRODUCT,:name,:can_view_lambda=>lambda {|u| false}).process_query_result("x",@u).should=="HIDDEN"
    end
    it "utilizes the user's timezone to translate date time values" do
      @u.time_zone = "Hawaii"
      time = Time.now.in_time_zone 'GMT'
      result = ModelField.new(10000,:test,CoreModule::PRODUCT,:name,:process_query_result_lambda=>lambda {|v| time}).process_query_result("x",@u)
      #Without the to_s the times compare by clockticks since epoch, which isn't what we want here
      expect(result.to_s).to eq time.in_time_zone('Hawaii').to_s
    end
    it "defaults timezone translation to Eastern" do
      @u.time_zone = nil
      time = Time.now.in_time_zone 'GMT'
      result = ModelField.new(10000,:test,CoreModule::PRODUCT,:name,:process_query_result_lambda=>lambda {|v| time}).process_query_result("x",@u)
      #Without the to_s the times compare by clockticks since epoch, which isn't what we want here
      expect(result.to_s).to eq time.in_time_zone('Eastern Time (US & Canada)').to_s
    end
  end
  context :read_only do
    before :each do
      FieldLabel::LABEL_CACHE.clear
    end
    after :each do
      FieldLabel.set_default_value :x, nil
      FieldLabel::LABEL_CACHE.clear
    end
    it "should default to not being read only" do
      mf = ModelField.new(1,:x,CoreModule::PRODUCT,:name,{:data_type=>:string})
      mf.should_not be_read_only
      p = Product.new
      mf.process_import p, "n"
      p.name.should == 'n'
    end
    it "should not write if read only" do
      FieldLabel.set_label :x, "PLBL"
      mf = ModelField.new(1,:x,CoreModule::PRODUCT,:name,{:data_type=>:string,:read_only=>true})
      mf.should be_read_only
      p = Product.new(:name=>'x')
      r = mf.process_import p, 'n'
      p.name.should == 'x'
      r.should == "Value ignored. PLBL is read only."
    end
    it "should set read_only for custom_defintion that is read only" do
      cd = Factory :custom_definition
      ModelField.reload
      fvr = FieldValidatorRule.new
      fvr.read_only = true
      fvr.model_field_uid = "*cf_#{cd.id}"
      fvr.save!
      ModelField.find_by_uid("*cf_#{cd.id}").should be_read_only
    end
    it "should not set read_only for custom_definition that isn't read only" do
      cd = Factory(:custom_definition)
      ModelField.reload
      ModelField.find_by_uid("*cf_#{cd.id}").should_not be_read_only
    end

    it "should set read_only for normal read_only field" do
      mf = ModelField.find_by_uid :prod_uid
      mf.should_not be_read_only
      fvr = FieldValidatorRule.create!(model_field_uid: :prod_uid, read_only: true)
      mf = ModelField.find_by_uid :prod_uid
      mf.should be_read_only
    end

  end
  describe "can_view?" do
    it "should default to true" do
      ModelField.new(1,:x,CoreModule::SHIPMENT,:z).can_view?(Factory(:user)).should be_true
    end
    it "should be false when lambda returns false" do
      ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:can_view_lambda=>lambda {|user| false}}).can_view?(Factory(:user)).should be_false
    end
    context "process_export" do
      it "should return HIDDEN for process_export if can_view? is false" do
        ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:export_lambda=>lambda {|obj| "a"},:can_view_lambda=>lambda {|u| false}}).process_export("x",Factory(:user)).should == "HIDDEN"
      end
      it "should return appropriate value for process_export if can_view? is true" do
        ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:export_lambda=>lambda {|obj| "a"},:can_view_lambda=>lambda {|u| true}}).process_export("x",Factory(:user)).should == "a"
      end
      it "should skip check if always_view is true" do
        ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:export_lambda=>lambda {|obj| "a"},:can_view_lambda=>lambda {|u| false}}).process_export("x",Factory(:user),true).should == "a"
      end
    end
  end
  it "should get uid for region" do
    r = Factory(:region)
    ModelField.uid_for_region(r,"x").should == "*r_#{r.id}_x"
  end
  context "special cases" do
    context "first hts by country" do
      before :each do
        @c = Factory(:country,:iso_code=>'ZY',:import_location=>true)
        ModelField.reload true
      end
      it "should create fields for each import country" do
        c2 = Factory(:country,:iso_code=>'ZZ',:import_location=>true)
        c3 = Factory(:country,:iso_code=>'NO',:import_location=>false)
        ModelField.reload true
        (1..3).each do |i|
          c_mf = ModelField.find_by_uid "*fhts_#{i}_#{@c.id}"
          c_mf.label.should == "First HTS #{i} (ZY)"
          c2_mf = ModelField.find_by_uid "*fhts_#{i}_#{c2.id}"
          c2_mf.label.should == "First HTS #{i} (ZZ)"
          ModelField.find_by_uid("*fhts_#{i}_#{c3.id}").should be_nil #don't create because not an import location
        end
      end
      it "should allow import" do
        ModelField.reload true
        p = Factory(:product)
        (1..3).each do |i|
          Factory(:official_tariff,:country=>@c,:hts_code=>"123456789#{i}")
          mf = ModelField.find_by_uid "*fhts_#{i}_#{@c.id}"
          r = mf.process_import(p, "123456789#{i}")
          r.should == "ZY HTS #{i} set to 1234.56.789#{i}"
        end
        p.save!
        p.should have(1).classifications
        cls = p.classifications.find_by_country_id(@c.id)
        cls.should have(1).tariff_records
        tr = cls.tariff_records.find_by_line_number 1
        tr.hts_1.should == "1234567891"
        tr.hts_2.should == "1234567892"
        tr.hts_3.should == "1234567893"
      end
      it "should update existing hts" do
        Factory(:official_tariff,:country=>@c,:hts_code=>"1234567899")
        tr = Factory(:tariff_record,classification:Factory(:classification,country:@c),hts_1:'0000000000')
        mf = ModelField.find_by_uid "*fhts_1_#{@c.id}"
        mf.process_import tr.product, '1234567899'
        tr.product.save!
        tr.reload
        tr.hts_1.should == '1234567899'
      end
      it "should strip non numerics from hts" do
        Factory(:official_tariff,:country=>@c,:hts_code=>"1234567899")
        p = Factory(:product)
        mf = ModelField.find_by_uid "*fhts_1_#{@c.id}"
        mf.process_import p, '1234.567-899 '
        p.classifications.first.tariff_records.first.hts_1.should == '1234567899'
      end
      it "should not allow import of invalid HTS" do
        Factory(:official_tariff,:country=>@c,:hts_code=>"1234567899")
        p = Factory(:product)
        mf = ModelField.find_by_uid "*fhts_1_#{@c.id}"
        r = mf.process_import p, '0000000000'
        r.should == "0000000000 is not valid for ZY HTS 1"
      end
      it "should allow any HTS for country withouth official tariffs" do
        p = Factory(:product)
        mf = ModelField.find_by_uid "*fhts_1_#{@c.id}"
        r = mf.process_import p, '0000000000'
        p.classifications.first.tariff_records.first.hts_1.should == '0000000000'
      end
      it "should format export" do
        tr = Factory(:tariff_record,classification:Factory(:classification,country:@c),hts_1:'0000000000')
        mf = ModelField.find_by_uid "*fhts_1_#{@c.id}"
        mf.process_export(tr.product,nil,true).should == '0000000000'.hts_format
      end
      it "should work with query" do
        u = Factory(:master_user)
        tr = Factory(:tariff_record,classification:Factory(:classification,country:@c),hts_1:'0000000000')
        ss = SearchSetup.new(module_type:'Product')
        ss.search_columns.build(model_field_uid:"*fhts_1_#{@c.id}",rank:1)
        ss.search_criterions.build(model_field_uid:"*fhts_1_#{@c.id}",operator:'eq',value:'0000000000')
        h = SearchQuery.new(ss,u).execute
        h.should have(1).record
        h.first[:row_key].should == tr.product.id
        h.first[:result].first.should == '0000000000'.hts_format
      end
    end
    context "bill of materials" do
      before :each do
        @parent_mf = ModelField.find_by_uid :prod_bom_parents
        @child_mf = ModelField.find_by_uid :prod_bom_children
      end
      it "should not allow imports for parents" do
        p = Factory(:product)
        r = @parent_mf.process_import p, 'abc'
        p.should_not be_on_bill_of_materials
        r.should == "Bill of Materials ignored, cannot be changed by upload."
      end
      it "process_export should return csv of BOM parents" do
        parent1 = Factory(:product,:unique_identifier=>'bomc1')
        parent2 = Factory(:product,:unique_identifier=>'bomc2')
        child = Factory(:product)
        child.bill_of_materials_parents.create!(:parent_product_id=>parent1.id,:quantity=>1)
        child.bill_of_materials_parents.create!(:parent_product_id=>parent2.id,:quantity=>1)
        output = @parent_mf.process_export child, nil, true
        output.should == "#{parent1.unique_identifier},#{parent2.unique_identifier}"
      end
      it "qualified_field_name should return csv of BOM parents" do
        parent1 = Factory(:product,:unique_identifier=>'bomc1')
        parent2 = Factory(:product,:unique_identifier=>'bomc2')
        child = Factory(:product)
        child.bill_of_materials_parents.create!(:parent_product_id=>parent1.id,:quantity=>1)
        child.bill_of_materials_parents.create!(:parent_product_id=>parent2.id,:quantity=>1)
        r = ActiveRecord::Base.connection.execute "SELECT #{@parent_mf.qualified_field_name} FROM products where id = #{child.id}"
        r.first.first.should == "#{parent1.unique_identifier},#{parent2.unique_identifier}"
      end
      it "should not allow imports for children" do
        p = Factory(:product)
        r = @child_mf.process_import p, 'abc'
        p.should_not be_on_bill_of_materials
        r.should == "Bill of Materials ignored, cannot be changed by upload."
      end
      it "should return csv of BOM children" do
        child1 = Factory(:product,:unique_identifier=>'bomc1')
        child2 = Factory(:product,:unique_identifier=>'bomc2')
        parent = Factory(:product)
        parent.bill_of_materials_children.create!(:child_product_id=>child1.id,:quantity=>1)
        parent.bill_of_materials_children.create!(:child_product_id=>child2.id,:quantity=>1)
        output = @child_mf.process_export parent, nil, true
        output.should == "#{child1.unique_identifier},#{child2.unique_identifier}"
      end
      it "qualified_field_name should return csv of BOM children" do
        child1 = Factory(:product,:unique_identifier=>'bomc1')
        child2 = Factory(:product,:unique_identifier=>'bomc2')
        parent = Factory(:product)
        parent.bill_of_materials_children.create!(:child_product_id=>child1.id,:quantity=>1)
        parent.bill_of_materials_children.create!(:child_product_id=>child2.id,:quantity=>1)
        r = ActiveRecord::Base.connection.execute "SELECT #{@child_mf.qualified_field_name} FROM products where id = #{parent.id}"
        r.first.first.should == "#{child1.unique_identifier},#{child2.unique_identifier}"
      end
    end
    context "classification count" do
      before :each do
        @user = Factory(:master_user)
        @p = Factory(:product)
        @country = Factory(:country)
        @ss = SearchSetup.new(:module_type=>'Product')
      end
      it "should reflect 0 if no classifications" do
        @ss.search_criterions.build(:model_field_uid=>'prod_class_count',:operator=>'eq',:value=>'0')
        sq = SearchQuery.new(@ss,@user)
        r = sq.execute
        r.size.should == 1
        r.first[:row_key].should == @p.id
      end
      it "should reflect 0 with classificaton and no tariff record" do
        @p.classifications.create!(:country_id=>@country.id)
        @ss.search_criterions.build(:model_field_uid=>'prod_class_count',:operator=>'eq',:value=>'0')
        sq = SearchQuery.new(@ss,@user)
        r = sq.execute
        r.size.should == 1
        r.first[:row_key].should == @p.id
      end
      it "should reflect 0 with no hts_1" do
        @p.classifications.create!(:country_id=>@country.id).tariff_records.create!
        @ss.search_criterions.build(:model_field_uid=>'prod_class_count',:operator=>'eq',:value=>'0')
        sq = SearchQuery.new(@ss,@user)
        r = sq.execute
        r.size.should == 1
        r.first[:row_key].should == @p.id
      end
      it "should reflect proper count with mixed bag" do
        @p.classifications.create!(:country_id=>@country.id).tariff_records.create! # = 0
        country_2 = Factory(:country)
        @p.classifications.create!(:country_id=>country_2.id).tariff_records.create!(:hts_1=>'123') # = 1
        @p.classifications.find_by_country_id(country_2.id).tariff_records.create!(:hts_1=>'123') # = 0 don't add for second component of same classification
        @p.classifications.create!(:country_id=>Factory(:country).id).tariff_records.create!(:hts_1=>'123') # = 1
        @ss.search_criterions.build(:model_field_uid=>'prod_class_count',:operator=>'eq',:value=>'2')
        sq = SearchQuery.new(@ss,@user)
        r = sq.execute
        r.size.should == 1
        r.first[:row_key].should == @p.id
      end
    end
    context "class_comp_cnt" do
      it "should get count of tariff rows" do
        tr = Factory(:tariff_record,line_number:1)
        Factory(:tariff_record,line_number:2,classification:tr.classification)
        cl = Classification.first
        mf = ModelField.find_by_uid :class_comp_cnt
        expect(mf.process_export(cl,nil,true)).to eq 2
        sc = SearchCriterion.new(model_field_uid: :class_comp_cnt, operator:'eq',value:'2')
        expect(sc.apply(Classification.scoped).first).to eq tr.classification
      end
    end
    context "regions" do
      it "should create classification count model fields for existing regions" do
        r = Factory(:region)
        r2 = Factory(:region)
        ModelField.reload
        ModelField.find_by_region(r).should have(1).model_field
        ModelField.find_by_region(r2).should have(1).model_field
      end
      context "classification count field methods" do
        before :each do
          @reg = Region.create!(:name=>"EMEA")
          @mf = ModelField.find_by_uid "*r_#{@reg.id}_class_count"
          @p = Factory(:product)
          @c1 = Factory(:country)
          @c2 = Factory(:country)
          @reg.countries << @c1
          tr1 = Factory(:tariff_record,:hts_1=>'12345678',:classification=>Factory(:classification,:country=>@c1,:product=>@p))
          tr2 = Factory(:tariff_record,:hts_1=>'12345678',:classification=>Factory(:classification,:country=>@c2,:product=>@p))
          @sc = SearchCriterion.new(:model_field_uid=>@mf.uid,:operator=>'eq',:value=>"1")
          
          #don't find this product because it's classified for a different country
          Factory(:tariff_record,:hts_1=>'12345678',:classification=>Factory(:classification,:country=>@c2))
        end
        it "should have proper label" do
          @mf.label.should == "Classification Count - EMEA"
        end
        it "should only count countries in region" do
          @mf.process_export(@p,User.new,true).should == 1
          x = @sc.apply(Product.where("1"))
          x = x.uniq
          x.should have(1).product
          x.first.should == @p
        end
        it "should return products without classification for eq 0" do
          @p.classifications.destroy_all
          @sc.value = "0"
          x = @sc.apply(Product.where("1"))
          x.first.should == @p
        end
        it "should not import" do
          @mf.process_import(@p,1).should == "Classification count ignored."
        end
        it "should not count tariff records without hts_1 values" do
          @p.classifications.find_by_country_id(@c1.id).tariff_records.first.update_attributes(:hts_1=>'')
          @sc.apply(Product.where("1")).first.should be_nil
        end
        it "should not double count multiple tariff records for country" do
          @p.classifications.find_by_country_id(@c1.id).tariff_records.create!(:hts_1=>'987654321')
          x = @sc.apply(Product.where("1")).uniq
          x.should have(1).product
          x.first.should == @p
        end
      end
    end
    context "PMS Month" do
      before :each do 
        @ent = Factory(:entry,:monthly_statement_due_date=>Date.new(2012,9,1))
        @mf = ModelField.find_by_uid :ent_statement_month
      end
      it "should export month" do
        @mf.process_export(@ent,nil,true).should == 9
      end
      it "should work as search criterion" do
        sc = SearchCriterion.new(:model_field_uid=>'ent_statement_month',:operator=>'eq',:value=>'9')
        Factory(:entry,:monthly_statement_due_date=>Date.new(2012,10,1))
        r = sc.apply(Entry.where('1=1'))
        r.should have(1).entry
        r.first.should == @ent
      end
    end
    context "Sync Records" do
      before :each do
        @ent = Factory(:entry)
      end
      it "should show problem" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Date.new(2014,1,1),confirmed_at:Date.new(2014,1,2),failure_message:'PROBLEM')
        expect(ModelField.find_by_uid(:ent_sync_problems).process_export(@ent,nil,true)).to be_true
        sc = SearchCriterion.new(:model_field_uid=>'ent_sync_problems',operator:'eq',value:'true')
        expect(sc.apply(Entry).to_a).to eq [@ent]
      end
      it "should show no problem" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Date.new(2014,1,1),confirmed_at:Date.new(2014,1,2))
        expect(ModelField.find_by_uid(:ent_sync_problems).process_export(@ent,nil,true)).to be_false
        sc = SearchCriterion.new(:model_field_uid=>'ent_sync_problems',operator:'eq',value:'false')
        expect(sc.apply(Entry).to_a).to eq [@ent]
      end
      it "should show sync record count" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Date.new(2014,1,1),confirmed_at:Date.new(2014,1,2))
        @ent.sync_records.create!(trading_partner:'DEF',sent_at:Date.new(2014,1,1),confirmed_at:Date.new(2014,1,2))
        expect(ModelField.find_by_uid(:ent_sync_record_count).process_export(@ent,nil,true)).to eq 2
        sc = SearchCriterion.new(:model_field_uid=>'ent_sync_record_count',operator:'eq',value:'2')
        expect(sc.apply(Entry).to_a).to eq [@ent]
      end
      it "should show latest sent date" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Date.new(2014,1,3),confirmed_at:Date.new(2014,1,4))
        @ent.sync_records.create!(trading_partner:'DEF',sent_at:Date.new(2014,1,1),confirmed_at:Date.new(2014,1,2))
        expect(ModelField.find_by_uid(:ent_sync_last_sent).process_export(@ent,nil,true).strftime('%Y%m%d')).to eq '20140103'
        sc = SearchCriterion.new(:model_field_uid=>'ent_sync_last_sent',operator:'gt',value:'2014-01-02')
        expect(sc.apply(Entry).to_a).to eq [@ent]
      end
      it "should show latest confirmed date" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Date.new(2014,1,3),confirmed_at:Date.new(2014,1,4))
        @ent.sync_records.create!(trading_partner:'DEF',sent_at:Date.new(2014,1,1),confirmed_at:Date.new(2014,1,2))
        expect(ModelField.find_by_uid(:ent_sync_last_confirmed).process_export(@ent,nil,true).strftime('%Y%m%d')).to eq '20140104'
        sc = SearchCriterion.new(:model_field_uid=>'ent_sync_last_confirmed',operator:'gt',value:'2014-01-03')
        expect(sc.apply(Entry).to_a).to eq [@ent]
      end
      it "should pass with nil comparison" do
        @ent.sync_records.create!(trading_partner:'ABC',sent_at:Date.new(2014,1,3),confirmed_at:Date.new(2014,1,4))
        @ent.sync_records.create!(trading_partner:'DEF',sent_at:Date.new(2014,1,1),confirmed_at:nil)
        expect(ModelField.find_by_uid(:ent_sync_last_confirmed).process_export(@ent,nil,true).strftime('%Y%m%d')).to eq '20140104'
      end

    end
    context "duty billed" do
      before :each do
        @line1 = Factory(:broker_invoice_line,:charge_amount=>10,:charge_code=>'0001')
        @line2 = Factory(:broker_invoice_line,:charge_amount=>5,:charge_code=>'0001',:broker_invoice=>@line1.broker_invoice)
        @mf = ModelField.find_by_uid :ent_duty_billed
      end
      it "should total D records at broker invoice line" do
        @mf.process_export(@line1.broker_invoice.entry,nil,true).should == 15
      end
      it "should not include records without an 0001 charge code" do
        line3 = Factory(:broker_invoice_line,:charge_amount=>7,:charge_code=>'0099',:broker_invoice=>@line1.broker_invoice)
        @mf.process_export(@line1.broker_invoice.entry,nil,true).should == 15
      end
      it "should work as search criterion" do
        sc = SearchCriterion.new(:model_field_uid=>'ent_duty_billed',:operator=>'eq',:value=>'15')
        sc.apply(Entry.where('1=1')).first.should == @line1.broker_invoice.entry
      end
      it "should total across multiple broker invoices for same entry" do
        ent = @line1.broker_invoice.entry
        line3 = Factory(:broker_invoice_line,:charge_amount=>20,:charge_code=>'0001',:broker_invoice=>Factory(:broker_invoice,:entry=>ent,:suffix=>'B'))
        @mf.process_export(@line1.broker_invoice.entry,nil,true).should == 35
        sc = SearchCriterion.new(:model_field_uid=>'ent_duty_billed',:operator=>'eq',:value=>'35')
        sc.apply(Entry.where('1=1')).first.should == @line1.broker_invoice.entry
      end
      it "should only include broker invoices on the entry in question" do
        line3 = Factory(:broker_invoice_line,:charge_amount=>3,:charge_code=>'0001') #will be on different entry
        @mf.process_export(@line1.broker_invoice.entry,nil,true).should == 15
        sc = SearchCriterion.new(:model_field_uid=>'ent_duty_billed',:operator=>'eq',:value=>'15')
        sc.apply(Entry.where('1=1')).first.should == @line1.broker_invoice.entry
      end
      it "should view if broker and can view broker invoices" do
        u = Factory(:broker_user)
        u.stub(:view_broker_invoices?).and_return(true)
        @mf.can_view?(u).should be_true
      end
      it "should not view if not broker" do
        u = Factory(:importer_user)
        u.stub(:view_broker_invoices?).and_return(true)
        @mf.can_view?(u).should be_false
      end
      it "should not view user cannot view broker invoicees" do
        u = Factory(:broker_user)
        u.stub(:view_broker_invoices?).and_return(false)
        @mf.can_view?(u).should be_false
      end
    end
    context "employee" do
      before(:each) do
        @mf = ModelField.find_by_uid(:ent_employee_name)
      end
      it "should not view if not broker" do
        u = Factory(:importer_user)
        expect(@mf.can_view?(u)).to be_false
      end
      it "should view if broker" do
        u = Factory(:broker_user)
        expect(@mf.can_view?(u)).to be_true
      end
    end
    context "first HTS code" do
      before :each do
        country_1 = Factory(:country,:classification_rank=>1)
        country_2 = Factory(:country,:classification_rank=>2)
        @p = Factory(:product)
        class_1 = @p.classifications.create!(:country_id=>country_1.id)
        class_2 = @p.classifications.create!(:country_id=>country_2.id)
        t_1 = class_1.tariff_records.create!(:hts_1=>'1234567890')
        t_2 = class_2.tariff_records.create!(:hts_2=>'9999999999')
        @mf = ModelField.find_by_uid :prod_first_hts
      end
      it "process_export should match first hts code for first country" do
        @mf.process_export(@p, nil, true).should == '1234.56.7890'
      end
      it "should match on search criterion" do
        sc = SearchCriterion.new(:model_field_uid=>'prod_first_hts',:operator=>'sw',:value=>'123456')
        r = sc.apply Product.where('1=1')
        r.first.should == @p
      end
    end
    context "hts formatting" do
      it "should handle query parameters for hts formatting" do
        tr = TariffRecord.new(:hts_1=>"1234567890",:hts_2=>"0987654321",:hts_3=>"123456")
        [:hts_hts_1,:hts_hts_2,:hts_hts_3].each do |mfuid|
          mf = ModelField.find_by_uid mfuid
          export = mf.process_export tr, nil, true
          exp_for_qry = mf.process_query_parameter tr
          case mfuid
            when :hts_hts_1
              export.should == "1234.56.7890"
              exp_for_qry.should == "1234567890"
            when :hts_hts_2
              export.should == "0987.65.4321"
              exp_for_qry.should == "0987654321"
            when :hts_hts_3
              export.should == "1234.56"
              exp_for_qry.should == "123456"
            else
              fail "Should have hit one of the tests"
          end
        end
      end
    end
    describe :process_query_parameter do
      p = Product.new(:unique_identifier=>"abc")
      ModelField.find_by_uid(:prod_uid).process_query_parameter(p).should == "abc"
    end

    context "shipment_lines" do
      it "should show container number" do
        con = Factory(:container,entry:nil,container_number:'CN123')
        sl = Factory(:shipment_line,container:con)
        mf = ModelField.find_by_uid(:shpln_container_number)
        expect(mf.process_export(sl,nil,true)).to eq 'CN123'

        sc = SearchCriterion.new(operator:'eq',model_field_uid:'shpln_container_number',value:'CN123')
        expect(sc.apply(Shipment).to_a).to eq [sl.shipment]
      end
      it "should show container size" do
        con = Factory(:container,entry:nil,container_size:'40HC')
        sl = Factory(:shipment_line,container:con)
        mf = ModelField.find_by_uid(:shpln_container_size)
        expect(mf.process_export(sl,nil,true)).to eq '40HC'

        sc = SearchCriterion.new(operator:'eq',model_field_uid:'shpln_container_size',value:'40HC')
        expect(sc.apply(Shipment).to_a).to eq [sl.shipment]
      end
      context :container_uid do
        before :each do
          @mf = ModelField.find_by_uid(:shpln_container_uid)
        end
        it "should show container uid" do
          con = Factory(:container,entry:nil)
          sl = Factory(:shipment_line,container:con)
          expect(@mf.process_export(sl,nil,true)).to eq con.id

          sc = SearchCriterion.new(operator:'eq',model_field_uid:'shpln_container_uid',value:con.id.to_s)
          expect(sc.apply(Shipment).to_a).to eq [sl.shipment]
        end
        it "should not allow you to set a container that is already on a different shipment" do
          con = Factory(:container,shipment:Factory(:shipment))
          sl = Factory(:shipment_line)
          expect(@mf.process_import(sl,con.id)).to eq "#{@mf.label} is not part of this shipment and was ignored."
          sl.reload
          expect(sl.container).to be_nil
        end
        it "should allow you to set a container that is already on the shipment" do
          sl = Factory(:shipment_line)
          con = Factory(:container,entry:nil,shipment:sl.shipment)
          expect(@mf.process_import(sl,con.id)).to eq "#{@mf.label} set to #{con.id}."
        end
      end
      end

    context "broker_invoice_total" do
      before :each do
        MasterSetup.get.update_attributes(:broker_invoice_enabled=>true)
      end
      it "should allow you to see broker_invoice_total if you can view broker_invoices" do
        u = Factory(:user,:broker_invoice_view=>true,:company=>Factory(:company,:master=>true))
        ModelField.find_by_uid(:ent_broker_invoice_total).can_view?(u).should be_true
      end
      it "should not allow you to see broker_invoice_total if you can't view broker_invoices" do
        u = Factory(:user,:broker_invoice_view=>false)
        ModelField.find_by_uid(:ent_broker_invoice_total).can_view?(u).should be_false
      end
    end
    context "broker security" do
      before :each do
        @broker_user = Factory(:user,:company=>Factory(:company,:broker=>true))
        @non_broker_user = Factory(:user)
      end
      it "should allow duty due date if user is broker company" do
        u = @broker_user
        ModelField.find_by_uid(:ent_duty_due_date).can_view?(u).should be_true
        ModelField.find_by_uid(:bi_duty_due_date).can_view?(u).should be_true
      end
      it "should not allow duty due date if user is not a broker" do
        u = @non_broker_user
        ModelField.find_by_uid(:ent_duty_due_date).can_view?(u).should be_false
        ModelField.find_by_uid(:bi_duty_due_date).can_view?(u).should be_false
      end
      it "should secure error_free_release" do
        mf = ModelField.find_by_uid(:ent_error_free_release) 
        mf.can_view?(@broker_user).should be_true
        mf.can_view?(@non_broker_user).should be_false
      end
      it "should secure census warning" do
        mf = ModelField.find_by_uid(:ent_census_warning) 
        mf.can_view?(@broker_user).should be_true
        mf.can_view?(@non_broker_user).should be_false
      end
      it "should secure pdf count" do
        mf = ModelField.find_by_uid(:ent_pdf_count)
        mf.can_view?(@broker_user).should be_true
        mf.can_view?(@non_broker_user).should be_false
      end
      it "should secure first/last 7501 print" do
        [:ent_first_7501_print,:ent_last_7501_print].each do |id|
          mf = ModelField.find_by_uid(id)
          mf.can_view?(@broker_user).should be_true
          mf.can_view?(@non_broker_user).should be_false
        end
      end
    end
    context "product last_changed_by" do
      it "should apply search criterion properly" do
        c = Factory(:company,:master=>true)
        p = Factory(:product)
        p2 = Factory(:product)
        u1 = Factory(:user,:username=>'abcdef',:company=>c)
        u2 = Factory(:user,:username=>'ghijkl',:company=>c)
        p.create_snapshot u1
        p.create_snapshot u2
        p2.create_snapshot u1
        ss = Factory(:search_setup,:module_type=>'Product',:user=>u1)
        ss.search_criterions.create!(:model_field_uid=>'prod_last_changed_by',
          :operator=>'sw',:value=>'ghi')
        found = ss.search.to_a
        found.should have(1).product
        found.first.should == p
      end
    end
    context :ent_rule_state do
      before :each do
        @mf = ModelField.find_by_uid(:ent_rule_state)
      end
      it "should show worst state if multiple business_validation_results" do
        ent = Factory(:entry)
        ent.business_validation_results.create!(state:'Pass')
        ent.business_validation_results.create!(state:'Fail')
        expect(@mf.process_export(ent,nil,true)).to eq 'Fail'
        pass_sc = SearchCriterion.new(model_field_uid:'ent_rule_state',operator:'eq',value:'Pass')
        expect(pass_sc.apply(Entry).count).to eq 0
        fail_sc = SearchCriterion.new(model_field_uid:'ent_rule_state',operator:'eq',value:'Fail')
        expect(fail_sc.apply(Entry).count).to eq 1
      end
    end
    context :ent_pdf_count do
      before :each do
        @with_pdf = Factory(:entry)
        @with_pdf.attachments.create!(:attached_content_type=>"application/pdf")
        @without_attachments = Factory(:entry)
        @with_tif = Factory(:entry)
        @with_tif.attachments.create!(:attached_content_type=>"image/tiff")
        @with_tif_and_2_pdf = Factory(:entry)
        @with_tif_and_2_pdf.attachments.create!(:attached_content_type=>"application/pdf")
        @with_tif_and_2_pdf.attachments.create!(:attached_content_type=>"application/pdf")
        @with_tif_and_2_pdf.attachments.create!(:attached_content_type=>"image/tiff")
        @mf = ModelField.find_by_uid(:ent_pdf_count)
        @u = Factory(:user,:company=>Factory(:company,:broker=>true))
      end
      it "should process_export" do
        @mf.process_export(@with_pdf, @u).should == 1
        @mf.process_export(@without_attachments, @u).should == 0
        @mf.process_export(@with_tif, @u).should == 0
        @mf.process_export(@with_tif_and_2_pdf, @u).should == 2

        @with_pdf.attachments.create!(:attached_content_type=>"application/notapdf", :attached_file_name=>"test.PDF")
        @mf.process_export(@with_pdf, @u).should == 2
      end
      it "should search with greater than" do
        sc = SearchCriterion.new(:model_field_uid=>:ent_pdf_count,:operator=>'gt',:value=>0)
        r = sc.apply(Entry.where("1=1")).to_a
        r.should have(2).entries
        r.should include(@with_pdf)
        r.should include(@with_tif_and_2_pdf)
      end
      it "should search with equals" do
        sc = SearchCriterion.new(:model_field_uid=>:ent_pdf_count,:operator=>'eq',:value=>0)
        r = sc.apply(Entry.where("1=1")).to_a
        r.should have(2).entries
        r.should include(@with_tif)
        r.should include(@without_attachments)
      end
      it "should search with pdf counts based on file extension or mime type" do
        @with_pdf.attachments.create!(:attached_content_type=>"application/notapdf", :attached_file_name=>"test.PDF")

        sc = SearchCriterion.new(:model_field_uid=>:ent_pdf_count,:operator=>'eq',:value=>2)
        r = sc.apply(Entry.where("1=1")).to_a
        r.should have(2).entries
        r.should include(@with_pdf)
        r.should include(@with_tif_and_2_pdf)
      end
    end
  end
end
